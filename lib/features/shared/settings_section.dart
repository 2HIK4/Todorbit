import 'package:flutter/material.dart';

/// A settings group with one boundary around its heading and related controls.
class SettingsSection extends StatefulWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    this.initiallyExpanded = false,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    required this.children,
  });

  final String title;
  final String? description;
  final bool initiallyExpanded;
  final List<Widget> children;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  // ExpansionTile stores a bool. Descendant scrollables store doubles; giving
  // them a separate bucket prevents a shared ancestor key from mixing types.
  final contentStorage = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey(widget.title),
          initiallyExpanded: widget.initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: widget.contentPadding,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(widget.title, style: theme.textTheme.titleSmall),
          subtitle: widget.description == null
              ? null
              : SettingsHelperText(widget.description!),
          children: [
            const Divider(height: 16),
            PageStorage(
              bucket: contentStorage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supplemental copy stays secondary to setting labels and values.
class SettingsHelperText extends StatelessWidget {
  const SettingsHelperText(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) => Text(
    data,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.4,
    ),
  );
}
