import 'dart:convert';

/// Versioned activation payload shared with the native widget, using stable IDs.
class NavigationRequest {
  const NavigationRequest({
    required this.kind,
    required this.id,
    this.day,
    this.nominalDate,
  });
  final String kind, id;
  final String? day, nominalDate;
  String encode() => jsonEncode({
    'version': 1,
    'kind': kind,
    'id': id,
    'day': day,
    'nominalDate': nominalDate,
    'action': 'edit',
  });
  factory NavigationRequest.decode(String source) {
    if (source.length > 4096) {
      throw const FormatException('Navigation request too large');
    }
    final json = jsonDecode(source);
    if (json is! Map ||
        json['version'] != 1 ||
        json['action'] != 'edit' ||
        !['task', 'event', 'session'].contains(json['kind']) ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        (json['id'] as String).length > 100) {
      throw const FormatException('Invalid navigation request');
    }
    for (final key in ['day', 'nominalDate']) {
      final value = json[key];
      if (value != null &&
          (value is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
              DateTime.tryParse(value) == null)) {
        throw const FormatException('Invalid navigation date');
      }
    }
    return NavigationRequest(
      kind: json['kind'] as String,
      id: json['id'] as String,
      day: json['day'] as String?,
      nominalDate: json['nominalDate'] as String?,
    );
  }
}
