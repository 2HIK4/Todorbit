import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Manages pointer and hover state cleanup across window focus changes and app deactivation.
///
/// Prevents stuck hover, pressed, or highlight states when window focus is lost
/// (e.g. Windows Snipping Tool Win+Shift+S, Alt-Tab, or OS gestures).
class PointerCancellationScope extends StatefulWidget {
  const PointerCancellationScope({super.key, required this.child});

  final Widget child;

  @override
  State<PointerCancellationScope> createState() =>
      _PointerCancellationScopeState();
}

class _PointerCancellationScopeState extends State<PointerCancellationScope>
    with WidgetsBindingObserver {
  final Set<int> _activePointers = {};
  final Map<int, Offset> _lastPositions = {};
  final Set<int> _activeDevices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _cancelAllActivePointers();
      _clearHoverStates();
    } else if (state == AppLifecycleState.resumed) {
      _cancelAllActivePointers();
      try {
        RendererBinding.instance.mouseTracker.updateAllDevices();
      } catch (_) {
        // Safe fallback in test harnesses without mouse tracker
      }
    }
  }

  void _cancelAllActivePointers() {
    if (_activePointers.isEmpty) return;
    for (final pointer in List.of(_activePointers)) {
      final position = _lastPositions[pointer] ?? Offset.zero;
      try {
        GestureBinding.instance.cancelPointer(pointer);
      } catch (_) {}
      try {
        GestureBinding.instance.handlePointerEvent(
          PointerCancelEvent(pointer: pointer, position: position),
        );
      } catch (_) {}
    }
    _activePointers.clear();
    _lastPositions.clear();
  }

  void _clearHoverStates() {
    if (_activeDevices.isEmpty) return;
    for (final device in List.of(_activeDevices)) {
      try {
        GestureBinding.instance.handlePointerEvent(
          PointerRemovedEvent(device: device),
        );
      } catch (_) {}
    }
    _activeDevices.clear();
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _lastPositions[event.pointer] = event.position;
    _activeDevices.add(event.device);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointers.contains(event.pointer)) {
      _lastPositions[event.pointer] = event.position;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _lastPositions.remove(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _lastPositions.remove(event.pointer);
  }

  void _onPointerHover(PointerHoverEvent event) {
    _activeDevices.add(event.device);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerHover: _onPointerHover,
      child: widget.child,
    );
  }
}
