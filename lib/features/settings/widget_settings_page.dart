import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/widget_configuration_store.dart';
import '../../domain/widget_configuration.dart';
import '../widget/native_widget_service.dart';

class WidgetSettingsController extends ChangeNotifier {
  DesktopWidgetKind? kind;
  int revision = 0;
  void open(DesktopWidgetKind value) {
    kind = value;
    revision++;
    notifyListeners();
  }
}

class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({
    super.key,
    required this.service,
    this.initialKind,
    this.store,
    this.requestRevision = 0,
  });
  final NativeWidgetService service;
  final DesktopWidgetKind? initialKind;
  final WidgetConfigurationStore? store;
  final int requestRevision;
  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  WidgetConfigurationStore? store;
  final configs = <DesktopWidgetKind, WidgetConfiguration>{};
  String? error;
  bool busy = false;
  DialogRoute<WidgetEditorResult>? editorRoute;
  GlobalKey<_WidgetConfigurationEditorState>? editorKey;
  DesktopWidgetKind? editingKind;

  @override
  void didUpdateWidget(covariant WidgetSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestRevision != widget.requestRevision &&
        widget.initialKind != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && configs[widget.initialKind] != null) {
          _edit(widget.initialKind!);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      store =
          widget.store ??
          WidgetConfigurationStore((await AppDatabase.defaultFile()).parent);
      for (final kind in DesktopWidgetKind.values) {
        configs[kind] = await store!.load(kind);
      }
      if (!mounted) return;
      setState(() {});
      if (widget.initialKind != null) await _edit(widget.initialKind!);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _edit(DesktopWidgetKind kind) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final previousRoute = editorRoute;
    if (previousRoute != null && previousRoute.isActive) {
      if (editingKind == kind) return;
      if (editorKey?.currentState?.hasChanges == true) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unapplied widget changes?'),
            content: Text(
              'Open the ${kind.name} widget editor and discard the current draft?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard and switch'),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      navigator.popUntil((route) => route == previousRoute || route.isFirst);
      if (previousRoute.isActive) navigator.removeRoute(previousRoute);
    }
    if (!mounted) return;
    final key = GlobalKey<_WidgetConfigurationEditorState>();
    final route = DialogRoute<WidgetEditorResult>(
      context: context,
      builder: (_) => WidgetConfigurationEditor(
        key: key,
        kind: kind,
        initial: configs[kind]!,
      ),
    );
    editorRoute = route;
    editorKey = key;
    editingKind = kind;
    final result = await navigator.push(route);
    if (identical(editorRoute, route)) {
      editorRoute = null;
      editorKey = null;
      editingKind = null;
    }
    if (result == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final other = kind == DesktopWidgetKind.tasks
        ? DesktopWidgetKind.calendar
        : DesktopWidgetKind.tasks;
    var saved = false;
    try {
      final previous = await store!.load(kind);
      final otherCurrent = await store!.load(other);
      // Visibility can change through the native menu while this editor is open.
      final next = result.configuration.copyWith(enabled: previous.enabled);
      await store!.save(kind, next);
      if (result.allWidgets) {
        try {
          await store!.save(other, otherCurrent.withSharedAppearance(next));
        } catch (_) {
          await store!.save(kind, previous);
          rethrow;
        }
      }
      saved = true;
      configs[kind] = next;
      configs[other] = result.allWidgets
          ? otherCurrent.withSharedAppearance(next)
          : otherCurrent;
      if (widget.service.isAvailable) {
        await widget.service.reloadConfiguration();
      }
    } catch (e) {
      error = saved
          ? 'Settings saved. Could not refresh the companion: $e'
          : 'Could not save widget settings: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _visibility(DesktopWidgetKind kind, bool value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = configs[kind]!.copyWith(enabled: value);
      await store!.save(kind, next);
      configs[kind] = next;
      if (widget.service.isAvailable) {
        await widget.service.setWidgetVisible(kind, value);
      }
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.service.isAvailable)
        const Text(
          'The Windows widget companion is unavailable in this build. Settings can still be edited.',
        ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      for (final kind in DesktopWidgetKind.values) ...[
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            kind == DesktopWidgetKind.tasks
                ? Icons.checklist
                : Icons.calendar_month_outlined,
          ),
          title: Text(
            kind == DesktopWidgetKind.tasks
                ? 'Tasks Widget'
                : 'Calendar Widget',
          ),
          subtitle: Text(
            configs[kind]?.enabled == true
                ? 'Enabled · restored with the companion'
                : 'Disabled',
          ),
          trailing: Switch(
            value: configs[kind]?.enabled ?? false,
            onChanged:
                busy || configs[kind] == null || !widget.service.isAvailable
                ? null
                : (v) => _visibility(kind, v),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: busy || configs[kind] == null ? null : () => _edit(kind),
            child: Text('Configure ${kind.name} widget'),
          ),
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Both widgets share one companion process and Windows startup entry. Each keeps its own size, position and visibility. Right-click either widget to edit it or recover hidden controls.',
      ),
      FutureBuilder<WidgetControlState>(
        future: widget.service.readSettings(),
        builder: (context, snapshot) => SwitchListTile(
          title: const Text('Launch widgets at Windows startup'),
          value: snapshot.data?.launchAtSignIn ?? true,
          onChanged: widget.service.isAvailable
              ? (v) async {
                  try {
                    await widget.service.setLaunchAtSignIn(v);
                    if (mounted) setState(() {});
                  } catch (e) {
                    if (mounted) setState(() => error = '$e');
                  }
                }
              : null,
        ),
      ),
    ],
  );
}

class WidgetEditorResult {
  const WidgetEditorResult(this.configuration, this.allWidgets);
  final WidgetConfiguration configuration;
  final bool allWidgets;
}

class WidgetConfigurationEditor extends StatefulWidget {
  const WidgetConfigurationEditor({
    super.key,
    required this.kind,
    required this.initial,
  });
  final DesktopWidgetKind kind;
  final WidgetConfiguration initial;
  @override
  State<WidgetConfigurationEditor> createState() =>
      _WidgetConfigurationEditorState();
}

class _WidgetConfigurationEditorState extends State<WidgetConfigurationEditor> {
  late WidgetConfiguration draft = widget.initial;
  final formKey = GlobalKey<FormState>();
  bool get tasks => widget.kind == DesktopWidgetKind.tasks;
  bool get hasChanges =>
      jsonEncode(draft.toJson()) != jsonEncode(widget.initial.toJson());
  void change(WidgetConfiguration next) => setState(() => draft = next);
  Widget slider(
    String label,
    double value,
    double max,
    ValueChanged<double> change, {
    double min = 0,
    int? divisions,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · ${value.toStringAsFixed(label.contains('Opacity') ? 0 : 1)}${label.contains('Opacity') ? '%' : ''}',
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions ?? (max - min).round(),
        label: value.toStringAsFixed(1),
        onChanged: change,
      ),
    ],
  );
  Widget surface(String key, String title) {
    final s = draft.surfaces[key] ?? WidgetConfiguration.defaults[key]!;
    void update(Map<String, dynamic> values) => change(
      draft.copyWith(
        surfaces: {
          ...draft.surfaces,
          key: WidgetSurface.fromJson({...s.toJson(), ...values}),
        },
      ),
    );
    return ExpansionTile(
      key: ValueKey('surface-$key'),
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColorField(
                label: 'Background color',
                value: s.color,
                onChanged: (v) => update({'color': v}),
              ),
              if (key == 'input') ...[
                _ColorField(
                  label: 'Text color',
                  value: s.textColor,
                  onChanged: (v) => update({'textColor': v}),
                ),
                _ColorField(
                  label: 'Placeholder color',
                  value: s.placeholderColor,
                  onChanged: (v) => update({'placeholderColor': v}),
                ),
              ],
              slider(
                'Opacity',
                s.opacity.toDouble(),
                100,
                (v) => update({'opacity': v.round()}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show border'),
                value: s.border,
                onChanged: (v) => update({'border': v}),
              ),
              if (s.border) ...[
                _ColorField(
                  label: 'Border color',
                  value: s.borderColor,
                  onChanged: (v) => update({'borderColor': v}),
                ),
                slider(
                  'Border Opacity',
                  s.borderOpacity.toDouble(),
                  100,
                  (v) => update({'borderOpacity': v.round()}),
                ),
                slider(
                  'Border thickness',
                  s.thickness,
                  8,
                  (v) => update({'thickness': v}),
                  divisions: 16,
                ),
              ],
              slider(
                'Corner radius',
                s.radius,
                32,
                (v) => update({'radius': v}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> applyAll() async {
    if (formKey.currentState?.validate() != true) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply shared appearance to both widgets?'),
        content: const Text(
          'Replace the other widget’s title and Open App visibility, text size, text readability, shell, content and header appearance. Its enabled state, position, size, layout lock, task navigation, input, calendar cells, date indicators and agenda stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply to All Widgets'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      Navigator.pop(context, WidgetEditorResult(draft, true));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tasks ? 'Customize Tasks Widget' : 'Customize Calendar Widget'),
    content: Form(
      key: formKey,
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Changes are saved only when you apply. Colors left empty follow the current light/dark theme.',
              ),
              const SizedBox(height: 12),
              _WidgetPreview(configuration: draft, calendar: !tasks),
              ExpansionTile(
                title: const Text('General & visibility'),
                initiallyExpanded: true,
                children: [
                  SwitchListTile(
                    title: const Text('Show widget title'),
                    value: draft.showTitle,
                    onChanged: (v) => change(draft.copyWith(showTitle: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Show Open App button'),
                    value: draft.showOpenButton,
                    onChanged: (v) => change(draft.copyWith(showOpenButton: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Lock layout'),
                    value: draft.layoutLocked,
                    onChanged: (v) => change(draft.copyWith(layoutLocked: v)),
                  ),
                  if (!draft.hasHeader)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Drag the outer margin to move. Right-click for Open Todorbit, views and Edit This Widget.',
                      ),
                    ),
                ],
              ),
              if (tasks)
                ExpansionTile(
                  title: const Text('Layout & navigation'),
                  children: [
                    for (final view in const [
                      'today',
                      'inbox',
                      'all',
                      'upcoming',
                    ])
                      CheckboxListTile(
                        title: Text(
                          {
                            'today': 'Today',
                            'inbox': 'Inbox',
                            'all': 'All Tasks',
                            'upcoming': 'Upcoming',
                          }[view]!,
                        ),
                        value: draft.views.contains(view),
                        onChanged: (v) => change(
                          draft.copyWith(
                            views: v == true
                                ? [...draft.views, view]
                                : draft.views.where((x) => x != view).toList(),
                          ),
                        ),
                      ),
                    if (draft.views.isEmpty)
                      const Text(
                        'The active view stays available. Use the right-click Task view menu to navigate.',
                      ),
                    DropdownButtonFormField<WidgetNavigationPosition>(
                      initialValue: draft.navigationPosition,
                      decoration: const InputDecoration(
                        labelText: 'Navigation position',
                      ),
                      items: [
                        for (final v in WidgetNavigationPosition.values)
                          DropdownMenuItem(value: v, child: Text(v.name)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          change(draft.copyWith(navigationPosition: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WidgetNavigationDisplay>(
                      initialValue: draft.navigationDisplay,
                      decoration: const InputDecoration(
                        labelText: 'Navigation display',
                      ),
                      items: [
                        for (final v in WidgetNavigationDisplay.values)
                          DropdownMenuItem(
                            value: v,
                            child: Text(switch (v) {
                              WidgetNavigationDisplay.text => 'Text only',
                              WidgetNavigationDisplay.icons => 'Icons only',
                              WidgetNavigationDisplay.both => 'Icon + text',
                            }),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          change(draft.copyWith(navigationDisplay: v));
                        }
                      },
                    ),
                  ],
                ),
              SwitchListTile(
                title: const Text('Protect text on transparent surfaces'),
                subtitle: const Text(
                  'Use small opaque text backplates when the combined background is very transparent.',
                ),
                value: draft.protectText,
                onChanged: (v) => change(draft.copyWith(protectText: v)),
              ),
              ExpansionTile(
                title: const Text('Typography'),
                children: [
                  slider(
                    'Text size',
                    draft.textScale,
                    1.6,
                    (v) => change(draft.copyWith(textScale: v)),
                    min: 1,
                    divisions: 6,
                  ),
                ],
              ),
              surface('shell', 'Main widget surface'),
              surface('header', 'Header surface'),
              surface('content', 'Main content panel'),
              if (tasks) ...[
                surface('navigation', 'Navigation container'),
                surface('navigationButton', 'Navigation buttons'),
                surface('input', 'Quick-add input'),
              ] else ...[
                surface('calendarCell', 'Calendar cells'),
                surface('agenda', 'Selected date agenda'),
                surface('selectedDate', 'Selected date indicator'),
                surface('today', 'Today indicator'),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Selection and today indicators use the theme accent. Text remains opaque. Text backplates protect readability on very transparent surfaces. Native text input stays opaque while focused. Check your desktop wallpaper if you turn text protection off.',
                ),
              ),
              TextButton(
                onPressed: () => change(
                  WidgetConfiguration().copyWith(
                    enabled: draft.enabled,
                    layoutLocked: draft.layoutLocked,
                  ),
                ),
                child: const Text('Reset customization to defaults'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      OutlinedButton(
        onPressed: applyAll,
        child: const Text('Apply to All Widgets'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState?.validate() == true) {
            Navigator.pop(context, WidgetEditorResult(draft, false));
          }
        },
        child: const Text('Apply'),
      ),
    ],
  );
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('$label-$value'),
    initialValue: value ?? '',
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Theme default or #RRGGBB',
    ),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (v) =>
        v == null || v.isEmpty || RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)
        ? null
        : 'Use #RRGGBB or leave empty',
    onChanged: (v) {
      if (v.isEmpty || RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) {
        onChanged(v.isEmpty ? null : v);
      }
    },
  );
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.configuration, required this.calendar});
  final WidgetConfiguration configuration;
  final bool calendar;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color(String? hex, Color fallback) => hex == null
        ? fallback
        : Color(int.parse(hex.substring(1), radix: 16) | 0xff000000);
    Widget layer(String name, Widget child, {Color? fallback}) {
      final s =
          configuration.surfaces[name] ?? WidgetConfiguration.defaults[name]!;
      final background = color(
        s.color,
        fallback ?? scheme.surfaceContainerHighest,
      );
      final ink = color(
        s.textColor,
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black,
      );
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: background.withValues(alpha: s.opacity / 100),
          borderRadius: BorderRadius.circular(s.radius),
          border: s.border && s.thickness > 0
              ? Border.all(
                  color: color(
                    s.borderColor,
                    scheme.outline,
                  ).withValues(alpha: s.borderOpacity / 100),
                  width: s.thickness,
                )
              : null,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink, fontSize: 12 * configuration.textScale),
          child: child,
        ),
      );
    }

    Widget content = layer(
      'content',
      Text(calendar ? 'Calendar grid preview' : 'Task content preview'),
    );
    Widget navigation = layer(
      'navigation',
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final view in configuration.views)
            layer(
              'navigationButton',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (configuration.navigationDisplay !=
                      WidgetNavigationDisplay.text)
                    Icon(switch (view) {
                      'today' => Icons.today_outlined,
                      'inbox' => Icons.inbox_outlined,
                      'all' => Icons.checklist,
                      _ => Icons.event_outlined,
                    }, size: 14),
                  if (configuration.navigationDisplay ==
                      WidgetNavigationDisplay.both)
                    const SizedBox(width: 4),
                  if (configuration.navigationDisplay !=
                      WidgetNavigationDisplay.icons)
                    Text(switch (view) {
                      'today' => 'Today',
                      'inbox' => 'Inbox',
                      'all' => 'All',
                      _ => 'Upcoming',
                    }),
                ],
              ),
            ),
        ],
      ),
    );
    return Semantics(
      label: 'Appearance preview only; no saved data',
      child: IgnorePointer(
        child: layer(
          'shell',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (configuration.hasHeader) ...[
                layer(
                  'header',
                  Row(
                    children: [
                      if (configuration.showTitle)
                        Expanded(
                          child: Text(calendar ? 'Calendar' : 'Todorbit'),
                        ),
                      if (configuration.showOpenButton)
                        const Icon(Icons.open_in_new, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (!calendar &&
                  configuration.views.isNotEmpty &&
                  configuration.navigationPosition !=
                      WidgetNavigationPosition.bottom) ...[
                navigation,
                const SizedBox(height: 6),
              ],
              content,
              if (calendar) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    layer(
                      'selectedDate',
                      const Text('Selected'),
                      fallback: scheme.primary,
                    ),
                    layer('today', const Text('Today')),
                  ],
                ),
                const SizedBox(height: 6),
                layer('agenda', const Text('Selected date agenda preview')),
              ] else ...[
                if (configuration.views.isNotEmpty &&
                    configuration.navigationPosition ==
                        WidgetNavigationPosition.bottom) ...[
                  const SizedBox(height: 6),
                  navigation,
                ],
                const SizedBox(height: 6),
                layer('input', const Text('Quick-add input preview')),
              ],
            ],
          ),
          fallback: scheme.surface,
        ),
      ),
    );
  }
}
