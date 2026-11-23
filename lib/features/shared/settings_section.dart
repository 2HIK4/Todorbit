import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// A settings group with one boundary around its heading and related controls.
class SettingsSection extends StatefulWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    this.initiallyExpanded = false,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.expansionKey,
    this.controller,
    this.divider = false,
    required this.children,
  });

  final String title;
  final String? description;
  final bool initiallyExpanded;
  final List<Widget> children;
  final EdgeInsetsGeometry contentPadding;
  final Key? expansionKey;
  final ExpansibleController? controller;
  final bool divider;

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
    final line = BorderSide(color: theme.colorScheme.outlineVariant);
    final ShapeBorder shape = widget.divider
        ? Border(bottom: line)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
            side: line,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.related),
      child: Material(
        color: widget.divider ? Colors.transparent : theme.colorScheme.surface,
        shape: shape,
        clipBehavior: widget.divider ? Clip.none : Clip.antiAlias,
        child: ExpansionTile(
          controller: widget.controller,
          key: widget.expansionKey ?? PageStorageKey(widget.title),
          initiallyExpanded: widget.initiallyExpanded,
          maintainState: true,
          tilePadding: EdgeInsets.symmetric(
            horizontal: widget.divider ? 0 : AppSpacing.content,
            vertical: AppSpacing.small,
          ),
          childrenPadding: widget.divider
              ? const EdgeInsets.only(bottom: AppSpacing.content)
              : widget.contentPadding,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Semantics(
            header: true,
            child: Text(widget.title, style: theme.textTheme.titleSmall),
          ),
          subtitle: widget.description == null
              ? null
              : SettingsHelperText(widget.description!),
          children: [
            const SizedBox(height: AppSpacing.gap),
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
