/// Bounded history of immutable settings snapshots. A gesture is one step.
class SettingsHistory<T> {
  SettingsHistory({this.limit = 60, required this.equal});
  final int limit;
  final bool Function(T, T) equal;
  final List<T> _undo = [], _redo = [];
  T? _gesture;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void begin(T current) => _gesture ??= current;
  void record(T before, T after) {
    if (_gesture != null || equal(before, after)) return;
    _undo.add(before);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  void end(T current) {
    final before = _gesture;
    _gesture = null;
    if (before != null) record(before, current);
  }

  T undo(T current) {
    end(current);
    if (!canUndo) return current;
    _redo.add(current);
    return _undo.removeLast();
  }

  T redo(T current) {
    if (!canRedo) return current;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _gesture = null;
  }
}
