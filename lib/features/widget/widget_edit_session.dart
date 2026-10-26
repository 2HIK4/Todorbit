import '../../domain/widget_configuration.dart';

/// Three-way reconciliation keeps independent native-menu edits in the draft.
class WidgetEditSession {
  WidgetEditSession(WidgetConfiguration initial)
    : committed = initial,
      draft = initial;

  WidgetConfiguration committed;
  WidgetConfiguration draft;
  bool get dirty => !equivalent(draft.toJson(), committed.toJson());

  void acceptSaved(WidgetConfiguration value) {
    committed = value;
    draft = value;
  }

  void reconcile(WidgetConfiguration external) {
    draft = merge(committed, draft, external);
    committed = external;
  }

  static WidgetConfiguration merge(
    WidgetConfiguration baseline,
    WidgetConfiguration draft,
    WidgetConfiguration current,
  ) => WidgetConfiguration.fromJson(
    _merge(baseline.toJson(), draft.toJson(), current.toJson())
        as Map<String, dynamic>,
  ).copyWith(enabled: current.enabled);

  static Object? _merge(Object? baseline, Object? draft, Object? current) {
    if (baseline is Map && draft is Map && current is Map) {
      return <String, dynamic>{
        for (final key in current.keys)
          key as String: _merge(baseline[key], draft[key], current[key]),
      };
    }
    // A concurrent change to the same property wins over the older draft.
    return equivalent(current, baseline) ? draft : current;
  }

  static bool equivalent(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && equivalent(a[key], b[key]),
          );
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(
            a.length,
            (i) => i,
          ).every((i) => equivalent(a[i], b[i]));
    }
    return a == b;
  }
}
