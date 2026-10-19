import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/contributors.dart';
import '../workspace/windows_resource_dialog.dart';

class ContributorsView extends StatelessWidget {
  const ContributorsView({super.key});

  static const _links = <(String, String)>[
    ('Email', 'mailto:hussamalkhatib24@gmail.com'),
    ('Portfolio', 'https://2hik4.github.io/'),
    ('LinkedIn', 'https://www.linkedin.com/in/hussam-alkhatib-dev'),
  ];

  Future<void> _open(BuildContext context, String target) async {
    try {
      await const WindowsResourceDialog().open(target);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open link: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/contributors.json'),
      builder: (context, snapshot) {
        ContributorRegistry? registry;
        String? error;
        if (snapshot.hasData) {
          try {
            registry = ContributorRegistry.parse(snapshot.data!);
          } catch (failure) {
            error = '$failure';
          }
        } else if (snapshot.hasError) {
          error = '${snapshot.error}';
        }
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              'Contributors',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 22),
            Text('Creator', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hussam Alkhatib',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Creator & Project Founder',
                      style: TextStyle(color: scheme.primary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Original concept, product direction, and development of TodoPilot.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (label, target) in _links)
                          TextButton(
                            onPressed: () => _open(context, target),
                            child: Text(label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Community Contributors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (error != null) Text('Contributor list unavailable: $error'),
            if (registry == null && error == null)
              const LinearProgressIndicator(),
            if (registry != null && registry.community.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Community contributions will appear here after review.',
                  ),
                ),
              ),
            if (registry != null)
              for (final contribution in registry.community)
                Card(
                  child: ListTile(
                    title: Text(contribution.title),
                    subtitle: Text(
                      '${contribution.name} · ${contribution.type.name}\n${contribution.description}',
                    ),
                    isThreeLine: true,
                    onTap: contribution.profile == null
                        ? null
                        : () => _open(context, contribution.profile.toString()),
                  ),
                ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to contribute'),
                  content: const Text(
                    'See CONTRIBUTING.md in the TodoPilot source repository for pull request and contributor registry instructions.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.info_outline),
              label: const Text('How to contribute'),
            ),
          ],
        );
      },
    );
  }
}
