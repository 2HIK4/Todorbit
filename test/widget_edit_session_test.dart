import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/widget/widget_edit_session.dart';

void main() {
  test(
    'semantic dirty state returns clean when slider returns to saved value',
    () {
      final original = WidgetConfiguration();
      final session = WidgetEditSession(original);
      session.draft = original.copyWith(textScale: 1.3);
      expect(session.dirty, isTrue);
      session.draft = original.copyWith(textScale: 1);
      expect(session.dirty, isFalse);
    },
  );
  test('Apply advances baseline so Cancel cannot undo saved changes', () {
    final session = WidgetEditSession(WidgetConfiguration());
    final saved = session.draft.copyWith(showTitle: false);
    session.acceptSaved(saved);
    session.draft = saved.copyWith(showOpenButton: false);
    expect(session.committed.showTitle, isFalse);
    expect(session.committed.showOpenButton, isTrue);
    expect(session.dirty, isTrue);
  });
  test(
    'external edits preserve unrelated draft properties and widget identity',
    () {
      final initial = WidgetConfiguration(enabled: true);
      final session = WidgetEditSession(initial);
      session.draft = initial.copyWith(
        textScale: 1.4,
        showTitle: false,
        surfaces: {
          ...initial.surfaces,
          'shell': const WidgetSurface(opacity: 40),
        },
      );
      session.reconcile(
        initial.copyWith(
          enabled: false,
          layoutLocked: true,
          surfaces: {
            ...initial.surfaces,
            'agenda': const WidgetSurface(opacity: 72),
          },
        ),
      );
      expect(session.draft.enabled, isFalse);
      expect(session.draft.layoutLocked, isTrue);
      expect(session.draft.showTitle, isFalse);
      expect(session.draft.textScale, 1.4);
      expect(session.draft.surfaces['shell']!.opacity, 40);
      expect(session.draft.surfaces['agenda']!.opacity, 72);
    },
  );
  test('same-property external changes replace an older draft without a false dirty state', () {
    final initial = WidgetConfiguration();
    final session = WidgetEditSession(initial);
    session.draft = initial.copyWith(textScale: 1.5);
    session.reconcile(initial.copyWith(textScale: 1.2));
    expect(session.draft.textScale, 1.2);
    expect(session.dirty, isFalse);
  });
}
