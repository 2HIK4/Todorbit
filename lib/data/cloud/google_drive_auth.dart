import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'cloud_storage_provider.dart';

abstract interface class CloudTokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Each local profile has a different platform-secure credential record.
/// This key and its contents are never included in portable backups.
class SecureCloudTokenStore implements CloudTokenStore {
  SecureCloudTokenStore(String profilePath, {String purpose = 'tokens'})
    : key =
          'todorbit.drive.${sha256.convert(utf8.encode(profilePath))}.$purpose';
  final String key;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}

abstract interface class GoogleAuthorizationFlow {
  Future<Map<String, String>> authorize(Uri Function(String redirect) build);
  void cancel();
}

class LoopbackGoogleAuthorization implements GoogleAuthorizationFlow {
  LoopbackGoogleAuthorization({this.openBrowser = _open});
  final Future<bool> Function(Uri) openBrowser;
  Completer<Map<String, String>>? _result;
  static Future<bool> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  void cancel() {
    if (_result case final result? when !result.isCompleted) {
      result.completeError(const CloudFailure('Google sign-in canceled.'));
    }
  }

  @override
  Future<Map<String, String>> authorize(
    Uri Function(String redirect) build,
  ) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw const CloudFailure(
        'This build supports desktop Google sign-in only.',
      );
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final result = _result = Completer<Map<String, String>>();
    // Attach an error handler before opening the browser (including cancel).
    final response = result.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () =>
          throw const CloudFailure('Sign-in timed out. Try again.'),
    );
    response.ignore();
    final redirect = 'http://127.0.0.1:${server.port}/oauth2callback';
    final uri = build(redirect);
    final expectedState = uri.queryParameters['state'];
    final subscription = server.listen((request) async {
      request.response.headers
        ..contentType = ContentType.html
        ..set('Cache-Control', 'no-store')
        ..set('Content-Security-Policy', "default-src 'none'");
      if (request.method != 'GET' ||
          request.uri.path != '/oauth2callback' ||
          request.uri.queryParameters['state'] != expectedState) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Invalid sign-in response. Return to Todorbit.');
      } else {
        request.response.write(
          'You can close this tab and return to Todorbit.',
        );
        if (!result.isCompleted) result.complete(request.uri.queryParameters);
      }
      try {
        await request.response.close();
      } on SocketException {
        // Closing the browser tab must not produce an unhandled app error.
      } on HttpException {
        // The OAuth result is carried by the completer, not the page response.
      }
    });
    try {
      if (!await openBrowser(uri).timeout(const Duration(seconds: 15))) {
        cancel();
      }
      return await response;
    } finally {
      if (!result.isCompleted) {
        result.completeError(const CloudFailure('Google sign-in canceled.'));
      }
      _result = null;
      await subscription.cancel();
      await server.close(force: true);
    }
  }
}

class GoogleDriveAuth {
  GoogleDriveAuth({
    required this.client,
    required this.store,
    required this.flow,
    required String clientId,
    String clientSecret = '',
    this.enabled = true,
    this.configurationStore,
  }) : _buildClientId = clientId,
       _buildClientSecret = clientSecret;
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const configuredClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_CLIENT_ID',
  );
  // Desktop clients are public clients. This parameter is not a security
  // boundary; PKCE and the user's grant protect the session.
  static const configuredClientSecret = String.fromEnvironment(
    'GOOGLE_DRIVE_CLIENT_SECRET',
  );
  static const publicConnectionEnabled = bool.fromEnvironment(
    'GOOGLE_DRIVE_ENABLED',
    defaultValue: false,
  );
  final http.Client client;
  final CloudTokenStore store;
  final GoogleAuthorizationFlow flow;
  final String _buildClientId;
  final String _buildClientSecret;
  final bool enabled;
  final CloudTokenStore? configurationStore;
  String? _configuredClientId, _clientSecret;
  String get clientId => _configuredClientId ?? _buildClientId;
  bool get hasClientConfiguration => _configuredClientId != null;
  bool get canConnect => enabled && clientId.isNotEmpty;
  Map<String, dynamic>? _tokens;
  CloudAccount? account;
  bool needsReconnect = false;
  Future<String>? _refreshing;

  static String _random() => base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');

  Future<void> load() async {
    if (!enabled) return;
    final configuration = await configurationStore?.read();
    if (configuration != null) {
      final parsed = _parseConfiguration(configuration);
      _configuredClientId = parsed.id;
      _clientSecret = parsed.secret;
    }
    final value = await store.read();
    if (value == null) return;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['clientId'] != clientId) {
        needsReconnect = true;
        return;
      }
      if (data['accountId'] is! String ||
          data['refresh_token'] is! String ||
          data['label'] is! String ||
          data['access_token'] is! String ||
          data['expiresAt'] is! int) {
        throw const FormatException();
      }
      _tokens = data;
      account = CloudAccount(
        data['accountId'] as String,
        data['label'] as String,
      );
    } catch (_) {
      needsReconnect = true;
      throw const CloudFailure(
        'Saved Google session is invalid. Disconnect and reconnect.',
      );
    }
  }

  ({String id, String? secret}) _parseConfiguration(String source) {
    try {
      if (utf8.encode(source).length > 16 * 1024) throw const FormatException();
      final installed = (jsonDecode(source) as Map)['installed'] as Map;
      final id = installed['client_id'];
      final secret = installed['client_secret'];
      if (id is! String ||
          id.length > 256 ||
          !RegExp(r'^[A-Za-z0-9._-]+\.apps\.googleusercontent\.com$')
              .hasMatch(id) ||
          (secret != null &&
              (secret is! String || secret.isEmpty || secret.length > 1024))) {
        throw const FormatException();
      }
      if (_buildClientId.isNotEmpty && id != _buildClientId) {
        throw const CloudFailure(
          'This Desktop configuration belongs to a different OAuth client than this build.',
        );
      }
      return (id: id, secret: secret as String?);
    } on CloudFailure {
      rethrow;
    } catch (_) {
      throw const CloudFailure(
        'Choose a valid Google Desktop (installed) OAuth credentials JSON, at most 16 KiB.',
      );
    }
  }

  /// Import only client configuration, never arbitrary endpoints or tokens.
  /// Some Google Desktop clients require this parameter even with PKCE.
  Future<void> importClientConfiguration(String source) async {
    if (account != null) {
      throw const CloudFailure(
        'Disconnect before changing OAuth configuration.',
      );
    }
    final store = configurationStore;
    if (store == null) {
      throw const CloudFailure(
        'Secure client configuration storage is unavailable.',
      );
    }
    final parsed = _parseConfiguration(source);
    await store.write(
      jsonEncode({
        'installed': {'client_id': parsed.id, 'client_secret': ?parsed.secret},
      }),
    );
    _configuredClientId = parsed.id;
    _clientSecret = parsed.secret;
    needsReconnect = false;
  }

  Future<void> removeClientConfiguration() async {
    if (account != null) {
      throw const CloudFailure(
        'Disconnect before removing OAuth configuration.',
      );
    }
    await configurationStore?.delete();
    _configuredClientId = null;
    _clientSecret = null;
  }

  Future<Map<String, dynamic>> _token(Map<String, String> fields) async {
    final response = await client
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          body: {
            'client_id': clientId,
            if ((_clientSecret ?? _buildClientSecret).isNotEmpty)
              'client_secret': _clientSecret ?? _buildClientSecret,
            ...fields,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      if (response.statusCode == 400 || response.statusCode == 401) {
        needsReconnect = true;
      }
      var reason = 'HTTP ${response.statusCode}';
      try {
        final failure = jsonDecode(response.body) as Map;
        final code = failure['error'];
        if (const {
          'invalid_client',
          'invalid_grant',
          'unauthorized_client',
          'unsupported_grant_type',
          'invalid_scope',
          'invalid_request',
          'access_denied',
        }.contains(code)) {
          reason = code as String;
        }
        // Return only a fixed diagnostic, never Google's free-form response,
        // authorization codes, tokens or request fields.
        if ('${failure['error_description']}'.contains('client_secret')) {
          reason = '$reason; desktop client authentication required';
        }
      } catch (_) {
        /* Keep the fixed HTTP status diagnostic. */
      }
      throw CloudFailure(
        'Google authorization failed ($reason). Reconnect Google Drive. If this continues, contact the Todorbit publisher.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['access_token'] is! String ||
        data['expires_in'] is! int ||
        data['token_type']?.toString().toLowerCase() != 'bearer' ||
        (data['scope'] != null &&
            !(data['scope'] as String).split(' ').contains(scope))) {
      throw const CloudFailure(
        'Google did not grant the required backup permission.',
      );
    }
    return data;
  }

  Future<CloudAccount> identity(String token) async {
    final response = await client
        .get(
          Uri.https('www.googleapis.com', '/drive/v3/about', {
            'fields': 'user(permissionId,displayName,emailAddress)',
          }),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const CloudFailure(
        'Could not verify the connected Google account.',
      );
    }
    final user = (jsonDecode(response.body) as Map)['user'] as Map;
    final id = user['permissionId'];
    if (id is! String || id.isEmpty) {
      throw const CloudFailure('Google account identity was unavailable.');
    }
    return CloudAccount(
      id,
      (user['emailAddress'] ?? user['displayName'] ?? 'Google account')
          .toString(),
    );
  }

  Future<void> connect() async {
    if (!canConnect) {
      throw const CloudFailure(
        'Google Drive connection is unavailable in this build. Local backups remain available.',
      );
    }
    final verifier = _random();
    final state = _random();
    late String redirect;
    final result = await flow.authorize((value) {
      redirect = value;
      return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': value,
        'response_type': 'code',
        'scope': scope,
        'access_type': 'offline',
        'prompt': 'consent select_account',
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': base64UrlEncode(
          sha256.convert(utf8.encode(verifier)).bytes,
        ).replaceAll('=', ''),
      });
    });
    if (result['state'] != state) {
      throw const CloudFailure('Invalid Google sign-in state.');
    }
    if (result['error'] != null) {
      throw const CloudFailure('Google sign-in was declined or canceled.');
    }
    final code = result['code'];
    if (code == null || code.isEmpty) {
      throw const CloudFailure('Google sign-in did not return a code.');
    }
    final token = await _token({
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirect,
      'grant_type': 'authorization_code',
    });
    final verified = await identity(token['access_token'] as String);
    if (account != null && verified.id != account!.id) {
      throw const CloudFailure(
        'Different Google account selected. Disconnect the current account before switching.',
      );
    }
    final refresh = token['refresh_token'];
    if (refresh is! String || refresh.isEmpty) {
      throw const CloudFailure(
        'Google did not return offline access. Reconnect and grant backup access.',
      );
    }
    final saved = {
      ...token,
      'accountId': verified.id,
      'label': verified.label,
      'clientId': clientId,
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch +
          (token['expires_in'] as int) * 1000,
    };
    await store.write(jsonEncode(saved));
    _tokens = saved;
    account = verified;
    needsReconnect = false;
  }

  Future<String> accessToken({bool forceRefresh = false}) async {
    if (!enabled) {
      throw const CloudFailure(
        'Google Drive connection is unavailable in this build.',
      );
    }
    final data = _tokens;
    if (data == null || account == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    if (!forceRefresh &&
        !needsReconnect &&
        (data['expiresAt'] as int) >
            DateTime.now().millisecondsSinceEpoch + 60000) {
      return data['access_token'] as String;
    }
    if (_refreshing case final running?) return running;
    final future = _refresh(data);
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<String> _refresh(Map<String, dynamic> old) async {
    final updated = await _token({
      'refresh_token': old['refresh_token'] as String,
      'grant_type': 'refresh_token',
    });
    final verified = await identity(updated['access_token'] as String);
    if (verified.id != old['accountId']) {
      needsReconnect = true;
      throw const CloudFailure(
        'Google account changed. Disconnect and reconnect.',
      );
    }
    final saved = {
      ...old,
      ...updated,
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch +
          (updated['expires_in'] as int) * 1000,
    };
    await store.write(jsonEncode(saved));
    _tokens = saved;
    needsReconnect = false;
    return saved['access_token'] as String;
  }

  /// Local disconnect is available offline; cloud files and grants are retained.
  Future<void> disconnect() async {
    flow.cancel();
    await store.delete();
    _tokens = null;
    account = null;
    needsReconnect = false;
  }
}
