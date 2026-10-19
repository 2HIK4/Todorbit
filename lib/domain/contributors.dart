import 'dart:convert';

enum ContributionType {
  themes,
  iconSets,
  features,
  bugFixes,
  uiImprovements,
  accessibility,
  documentation,
  translations,
}

class CommunityContribution {
  const CommunityContribution({
    required this.name,
    required this.title,
    required this.type,
    required this.description,
    this.profile,
    this.related,
  });
  final String name;
  final String title;
  final ContributionType type;
  final String description;
  final Uri? profile;
  final String? related;
}

class ContributorRegistry {
  const ContributorRegistry(this.community);
  final List<CommunityContribution> community;

  factory ContributorRegistry.parse(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['community'] is! List) {
      throw const FormatException('Unsupported contributor registry');
    }
    final community = <CommunityContribution>[];
    for (final raw in data['community'] as List) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid contributor');
      }
      String required(String key) {
        final value = raw[key];
        if (value is! String || value.trim().isEmpty || value.length > 500) {
          throw FormatException('Invalid contributor $key');
        }
        return value.trim();
      }

      final typeName = required('type');
      final type = ContributionType.values
          .where((value) => value.name == typeName)
          .firstOrNull;
      if (type == null) {
        throw const FormatException('Unknown contribution type');
      }
      final profileText = raw['profile'];
      final profile = profileText is String ? Uri.tryParse(profileText) : null;
      if (profileText != null &&
          (profile == null ||
              profile.scheme != 'https' ||
              profile.host.isEmpty)) {
        throw const FormatException('Invalid profile link');
      }
      community.add(
        CommunityContribution(
          name: required('name'),
          title: required('title'),
          type: type,
          description: required('description'),
          profile: profile,
          related: raw['related'] is String ? raw['related'] as String : null,
        ),
      );
    }
    return ContributorRegistry(community);
  }
}
