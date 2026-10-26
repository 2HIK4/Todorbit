import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_database.dart';
import '../../data/widget_configuration_store.dart';
import '../../domain/widget_configuration.dart';
import '../widget/native_widget_service.dart';
import '../widget/widget_edit_session.dart';
import '../shared/settings_section.dart';
import '../shared/color_picker_dialog.dart';

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
  int openingRevision = 0;

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
    if (editorRoute?.isActive == true) {
      if (editingKind == kind) return;
      if (await editorKey?.currentState?.requestClose() != true) return;
    }
    if (!mounted) return;
    final request = ++openingRevision;
    try {
      final initial = await store!.load(kind);
      if (!mounted || request != openingRevision) return;
      final key = GlobalKey<_WidgetConfigurationEditorState>();
      final route = DialogRoute<WidgetEditorResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WidgetConfigurationEditor(
          key: key,
          kind: kind,
          initial: initial,
          service: widget.service,
          store: store,
          onApply: (draft, baseline, all) => _save(kind, draft, baseline, all),
        ),
      );
      editorRoute = route;
      editorKey = key;
      editingKind = kind;
      await navigator.push(route);
      if (identical(editorRoute, route)) {
        editorRoute = null;
        editorKey = null;
        editingKind = null;
      }
      if (mounted) {
        for (final k in DesktopWidgetKind.values) {
          configs[k] = await store!.load(k);
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not open widget settings: $e');
    }
  }

  Future<WidgetConfiguration> _save(
    DesktopWidgetKind kind,
    WidgetConfiguration draft,
    WidgetConfiguration baseline,
    bool all,
  ) async {
    final other = kind == DesktopWidgetKind.tasks
        ? DesktopWidgetKind.calendar
        : DesktopWidgetKind.tasks;
    final previous = await store!.load(kind);
    final otherCurrent = await store!.load(other);
    final next = WidgetEditSession.merge(baseline, draft, previous);
    await store!.save(kind, next);
    if (all) {
      try {
        await store!.save(other, otherCurrent.withSharedAppearance(next));
      } catch (_) {
        await store!.save(kind, previous);
        rethrow;
      }
    }
    configs[kind] = next;
    configs[other] = all
        ? otherCurrent.withSharedAppearance(next)
        : otherCurrent;
    if (mounted) setState(() => error = null);
    if (widget.service.isAvailable) {
      try {
        await widget.service.reloadConfiguration();
      } catch (e) {
        if (mounted) {
          setState(
            () => error = 'Settings saved. Companion refresh failed: $e',
          );
        }
      }
    }
    return next;
  }

  Future<void> _visibility(DesktopWidgetKind kind, bool value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = (await store!.load(kind)).copyWith(enabled: value);
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
      const SettingsHelperText(
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
    this.service,
    this.store,
    this.onApply,
  });
  final DesktopWidgetKind kind;
  final WidgetConfiguration initial;
  final NativeWidgetService? service;
  final WidgetConfigurationStore? store;
  final Future<WidgetConfiguration> Function(
    WidgetConfiguration draft,
    WidgetConfiguration baseline,
    bool all,
  )?
  onApply;
  @override
  State<WidgetConfigurationEditor> createState() =>
      _WidgetConfigurationEditorState();
}

class _WidgetConfigurationEditorState extends State<WidgetConfigurationEditor> {
  late final session = WidgetEditSession(widget.initial);
  WidgetConfiguration get draft => session.draft;
  final formKey = GlobalKey<FormState>();
  final previewSession = const Uuid().v4();
  int sequence = 0;
  Timer? previewDebounce, heartbeat, externalDebounce;
  StreamSubscription<FileSystemEvent>? changes;
  Future<void> previewQueue = Future.value();
  bool saving = false, closing = false, allowClose = false, prompting = false;
  String? feedback;
  bool get tasks => widget.kind == DesktopWidgetKind.tasks;
  bool get hasChanges => session.dirty;

  @override
  void initState() {
    super.initState();
    if (widget.service?.isAvailable == true) {
      heartbeat = Timer.periodic(const Duration(seconds: 2), (_) => _preview());
    }
    final directory = widget.store?.directory;
    if (directory != null && directory.existsSync()) {
      changes = directory.watch().listen((event) {
        final destination = event is FileSystemMoveEvent
            ? event.destination
            : null;
        if (!event.path.endsWith('configuration.json') &&
            destination?.endsWith('configuration.json') != true) {
          return;
        }
        externalDebounce?.cancel();
        externalDebounce = Timer(const Duration(milliseconds: 160), _reconcile);
      });
    }
  }

  Future<void> _reconcile() async {
    if (saving || closing || widget.store == null) return;
    try {
      final current = await widget.store!.load(widget.kind);
      if (!mounted || saving || closing) return;
      if (!WidgetEditSession.equivalent(
        current.toJson(),
        session.committed.toJson(),
      )) {
        setState(() {
          session.reconcile(current);
          feedback = 'Updated from the widget. Your other changes are kept.';
        });
        _preview();
      }
    } catch (e) {
      if (mounted) {
        setState(() => feedback = 'Could not reload widget settings: $e');
      }
    }
  }

  void change(WidgetConfiguration next) {
    if (saving || closing) return;
    setState(() {
      session.draft = next;
      feedback = null;
    });
    // Coalesce to the newest draft at a bounded cadence. Keeping an
    // already scheduled tick lets continuous slider movement preview mid-drag.
    if (previewDebounce?.isActive != true) {
      previewDebounce = Timer(const Duration(milliseconds: 70), () {
        previewDebounce = null;
        unawaited(_preview());
      });
    }
  }

  Future<void> _preview({bool end = false}) {
    if (widget.service?.isAvailable != true || (closing && !end)) {
      return Future.value();
    }
    final baseline = session.committed, configuration = draft;
    final revision = ++sequence;
    previewQueue = previewQueue.then((_) async {
      try {
        final delivered = await widget.service!.previewConfiguration(
          kind: widget.kind,
          session: previewSession,
          sequence: revision,
          baseline: baseline,
          configuration: configuration,
          end: end,
        );
        if (!delivered && mounted && !closing) {
          setState(
            () => feedback = 'Live preview unavailable. Saved settings are safe; enable the widget to preview.',
          );
        } else if (delivered &&
            mounted &&
            !closing &&
            feedback?.startsWith('Live preview unavailable') == true) {
          setState(() => feedback = null);
        }
      } catch (e) {
        if (mounted && !closing) {
          setState(() => feedback = 'Live preview unavailable: $e');
        }
      }
    });
    return previewQueue;
  }

  Future<bool> _apply(bool all) async {
    if (saving || formKey.currentState?.validate() != true) return false;
    previewDebounce?.cancel();
    setState(() {
      saving = true;
      feedback = null;
    });
    try {
      final saved = widget.onApply == null
          ? draft
          : await widget.onApply!(draft, session.committed, all);
      if (!mounted) return false;
      setState(() {
        session.acceptSaved(saved);
        feedback = 'Changes saved';
      });
      await _preview();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => feedback = 'Could not save widget settings: $e');
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> _close() async {
    if (closing || saving) return false;
    closing = true;
    previewDebounce?.cancel();
    heartbeat?.cancel();
    externalDebounce?.cancel();
    await _preview(end: true);
    if (!mounted) return true;
    setState(() => allowClose = true);
    // PopScope must rebuild before accepting a programmatic pop.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
    return true;
  }

  Future<bool> requestClose() async {
    if (closing || saving || prompting) return false;
    if (!hasChanges) return _close();
    prompting = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved widget changes'),
        scrollable: true,
        content: const Text(
          'You have unsaved widget changes. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Continue Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard Changes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
    prompting = false;
    if (!mounted || action == null || action == 'continue') return false;
    if (action == 'save' && !await _apply(false)) return false;
    return _close();
  }

  @override
  void dispose() {
    previewDebounce?.cancel();
    heartbeat?.cancel();
    externalDebounce?.cancel();
    changes?.cancel();
    if (!closing) {
      closing = true;
      unawaited(_preview(end: true));
    }
    super.dispose();
  }

  Widget slider(
    String label,
    double value,
    double max,
    ValueChanged<double> change, {
    double min = 0,
    int? divisions,
  }) {
    final valueText = label == 'Text size'
        ? '${(value * 100).round()}%'
        : label.contains('Opacity')
        ? '${value.round()}%'
        : '${value.toStringAsFixed(label == 'Border thickness' ? 1 : 0)} px';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · $valueText'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          label: valueText,
          semanticFormatterCallback: (_) => '$label $valueText',
          onChanged: change,
        ),
      ],
    );
  }

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
    return SettingsSection(
      key: ValueKey('surface-$key'),
      title: title,
      children: [
        Padding(
          padding: EdgeInsets.zero,
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
        scrollable: true,
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
    if (yes == true && mounted) await _apply(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowClose,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(requestClose());
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            unawaited(requestClose()),
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tasks ? 'Customize Tasks Widget' : 'Customize Calendar Widget',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Close editor',
              onPressed: saving ? null : requestClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: AbsorbPointer(
          absorbing: saving,
          child: ExcludeFocus(
            excluding: saving,
            child: Opacity(
              opacity: saving ? .6 : 1,
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SettingsHelperText(
                          'Preview changes on your desktop. Apply saves and keeps this editor open. Empty colors follow your theme.',
                        ),
                        const SizedBox(height: 12),
                        if (!draft.enabled)
                          const SettingsHelperText(
                            'Enable this widget in Settings to see its live desktop preview.',
                          ),
                        if (feedback != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                feedback!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        Text(
                          hasChanges ? 'Unsaved changes' : 'All changes saved',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 12),
                        if (!tasks)
                          SettingsSection(
                            title: 'Calendar presentation',
                            initiallyExpanded: true,
                            children: [
                              DropdownButtonFormField<
                                WidgetCalendarPresentation
                              >(
                                key: ValueKey(draft.calendarPresentation),
                                initialValue: draft.calendarPresentation,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Calendar presentation',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: WidgetCalendarPresentation
                                        .compactAgenda,
                                    child: Text('Compact Calendar + Agenda'),
                                  ),
                                  DropdownMenuItem(
                                    value: WidgetCalendarPresentation.fullMonth,
                                    child: Text('Full Month Grid'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    change(
                                      draft.copyWith(calendarPresentation: v),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        SettingsSection(
                          title: 'General & visibility',
                          initiallyExpanded: true,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Show widget title'),
                              value: draft.showTitle,
                              onChanged: (v) =>
                                  change(draft.copyWith(showTitle: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Show Open App button'),
                              value: draft.showOpenButton,
                              onChanged: (v) =>
                                  change(draft.copyWith(showOpenButton: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Lock layout'),
                              value: draft.layoutLocked,
                              onChanged: (v) =>
                                  change(draft.copyWith(layoutLocked: v)),
                            ),
                            if (!draft.hasHeader)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SettingsHelperText(
                                  'Use the top grip to move. Right-click for widget actions.',
                                ),
                              ),
                          ],
                        ),
                        if (tasks)
                          SettingsSection(
                            title: 'Layout & navigation',
                            children: [
                              for (final view in const [
                                'today',
                                'inbox',
                                'all',
                                'upcoming',
                              ])
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
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
                                          : draft.views
                                                .where((x) => x != view)
                                                .toList(),
                                    ),
                                  ),
                                ),
                              if (draft.views.isEmpty)
                                const Text(
                                  'The active view stays available. Use the right-click Task view menu to navigate.',
                                ),
                              DropdownButtonFormField<WidgetNavigationPosition>(
                                key: ValueKey(
                                  'navigation-position-${draft.navigationPosition.name}',
                                ),
                                initialValue: draft.navigationPosition,
                                decoration: const InputDecoration(
                                  labelText: 'Navigation position',
                                ),
                                items: [
                                  for (final v
                                      in WidgetNavigationPosition.values)
                                    DropdownMenuItem(
                                      value: v,
                                      child: Text(v.name),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    change(
                                      draft.copyWith(navigationPosition: v),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<WidgetNavigationDisplay>(
                                key: ValueKey(
                                  'navigation-display-${draft.navigationDisplay.name}',
                                ),
                                initialValue: draft.navigationDisplay,
                                decoration: const InputDecoration(
                                  labelText: 'Navigation display',
                                ),
                                items: [
                                  for (final v
                                      in WidgetNavigationDisplay.values)
                                    DropdownMenuItem(
                                      value: v,
                                      child: Text(switch (v) {
                                        WidgetNavigationDisplay.text =>
                                          'Text only',
                                        WidgetNavigationDisplay.icons =>
                                          'Icons only',
                                        WidgetNavigationDisplay.both =>
                                          'Icon + text',
                                      }),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    change(
                                      draft.copyWith(navigationDisplay: v),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Protect text on transparent surfaces',
                          ),
                          subtitle: const Text(
                            'Add a subtle text shadow on transparent surfaces. Surface opacity stays as configured.',
                          ),
                          value: draft.protectText,
                          onChanged: (v) =>
                              change(draft.copyWith(protectText: v)),
                        ),
                        SettingsSection(
                          title: 'Typography',
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
                          child: SettingsHelperText(
                            'Today and selection follow your accent. Focused text input stays opaque for clear typing.',
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
            ),
          ),
        ),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: saving ? null : applyAll,
                child: const Text('Apply to All Widgets'),
              ),
              TextButton(
                onPressed: saving ? null : _close,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : () => _apply(false),
                child: Text(saving ? 'Saving...' : 'Apply'),
              ),
            ],
          ),
        ],
      ),
    ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Theme default or #RRGGBB',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value == null
                  ? Theme.of(context).colorScheme.surface
                  : Color(
                      int.parse(value!.substring(1), radix: 16) | 0xff000000,
                    ),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        suffixIcon: IconButton(
          tooltip: 'Choose $label',
          icon: const Icon(Icons.palette_outlined),
          onPressed: () async {
            final selected = await showDialog<Color>(
              context: context,
              builder: (_) => ColorPickerDialog(
                title: label,
                initialColor: value == null
                    ? Theme.of(context).colorScheme.surface
                    : Color(
                        int.parse(value!.substring(1), radix: 16) | 0xff000000,
                      ),
              ),
            );
            if (selected != null) {
              onChanged(
                '#${(selected.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
              );
            }
          },
        ),
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
    ),
  );
}
