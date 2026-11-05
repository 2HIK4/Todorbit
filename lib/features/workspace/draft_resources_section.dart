import '../../platform/android/android_platform.dart';
import '../shared/app_motion.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../domain/task_resources.dart';
import '../shared/text_prompt_dialog.dart';
import 'windows_resource_dialog.dart';

class DraftResourcesSection extends StatefulWidget {
  const DraftResourcesSection({
    super.key,
    required this.resources,
    required this.onChanged,
  });
  final List<DraftTaskResource> resources;
  final ValueChanged<List<DraftTaskResource>> onChanged;

  @override
  State<DraftResourcesSection> createState() => _DraftResourcesSectionState();
}

class _DraftResourcesSectionState extends State<DraftResourcesSection> {
  bool picking = false;
  List<DraftTaskResource> get resources => widget.resources;
  void onChanged(List<DraftTaskResource> next) => widget.onChanged(next);
  @override
  Widget build(BuildContext context) {
    Future<void> file(TaskResourceKind kind) async {
      if (picking) return;
      setState(() => picking = true);
      try {
        const picker = WindowsResourceDialog();
        final target = kind == TaskResourceKind.externalFolder
            ? (await picker.chooseFolder())?.path
            : (await picker.chooseFile())?.path;
        if (target != null && !context.mounted && Platform.isAndroid) {
          await AndroidPlatform.releaseImportedDocument(File(target));
          return;
        }
        if (target != null && context.mounted) {
          onChanged([
            ...resources,
            DraftTaskResource(kind, target, path.basename(target)),
          ]);
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not select resource: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => picking = false);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Resources are added when you save. Linked originals stay on this device.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: picking ? null : () => file(TaskResourceKind.managed),
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach a copy'),
            ),
            TextButton.icon(
              onPressed: () async {
                final target = await showDialog<String>(
                  context: context,
                  animationStyle: AppMotion.style(context),
                  builder: (_) => TextPromptDialog(
                    title: 'Add URL',
                    label: 'Website or application link',
                    maxLength: null,
                    save: (value) async {
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null ||
                          !uri.hasScheme ||
                          uri.scheme.length < 2 ||
                          {
                            'file',
                            'javascript',
                            'data',
                            'vbscript',
                            'shell',
                          }.contains(uri.scheme.toLowerCase()) ||
                          ({'http', 'https'}.contains(uri.scheme) &&
                              uri.host.isEmpty)) {
                        throw ArgumentError(
                          'Enter a valid website or application link',
                        );
                      }
                    },
                  ),
                );
                if (target != null && context.mounted) {
                  onChanged([
                    ...resources,
                    DraftTaskResource(
                      TaskResourceKind.url,
                      target.trim(),
                      target.trim(),
                    ),
                  ]);
                }
              },
              icon: const Icon(Icons.link),
              label: const Text('Add URL'),
            ),
            if (Platform.isWindows) ...[
              TextButton(
                onPressed: picking
                    ? null
                    : () => file(TaskResourceKind.externalFile),
                child: const Text('Link a file'),
              ),
              TextButton(
                onPressed: picking
                    ? null
                    : () => file(TaskResourceKind.externalFolder),
                child: const Text('Link a folder'),
              ),
            ],
          ],
        ),
        for (var i = 0; i < resources.length; i++)
          ListTile(
            title: Text(resources[i].label),
            subtitle: Text(
              resources[i].kind == TaskResourceKind.managed
                  ? 'Attachment · saved with the task'
                  : resources[i].kind == TaskResourceKind.url
                  ? 'Link'
                  : 'Local reference',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Rename resource',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final item = resources[i];
                    final label = await showDialog<String>(
                      context: context,
                      animationStyle: AppMotion.style(context),
                      builder: (_) => TextPromptDialog(
                        title: 'Resource name',
                        initial: item.label,
                        save: (value) async {
                          if (value.trim().isEmpty) {
                            throw ArgumentError('Enter a name');
                          }
                        },
                      ),
                    );
                    if (label != null && context.mounted) {
                      final next = List.of(resources);
                      next[i] = DraftTaskResource(
                        item.kind,
                        item.target,
                        label.trim(),
                      );
                      onChanged(next);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Remove draft resource',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    final next = List.of(resources)..removeAt(i);
                    onChanged(next);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
