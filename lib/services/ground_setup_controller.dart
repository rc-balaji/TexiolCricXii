import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ground_layout.dart';

class GroundSetupController extends ChangeNotifier {
  GroundSetupController([GroundSetup initial = const GroundSetup()])
    : _value = initial;

  GroundSetup _value;
  GroundSetup? _gestureStart;
  int _viewResetRevision = 0;
  final _undo = <GroundSetup>[];
  final _redo = <GroundSetup>[];
  GroundSetup get value => _value;
  int get viewResetRevision => _viewResetRevision;
  bool get canUndo => _undo.isNotEmpty && !_value.locked;
  bool get canRedo => _redo.isNotEmpty && !_value.locked;

  void restore(GroundSetup setup) {
    _value = setup;
    _viewResetRevision++;
    _undo.clear();
    _redo.clear();
    _gestureStart = null;
    notifyListeners();
  }

  void change(GroundSetup next, {bool recenterView = false}) {
    if (_value.locked) return;
    final changed = !_same(_value, next);
    final resetView = recenterView || _value.placed != next.placed;
    if (!changed && !resetView) return;
    if (changed && _gestureStart == null) {
      _remember(_value);
      _redo.clear();
    }
    if (resetView) _viewResetRevision++;
    _value = next;
    notifyListeners();
  }

  void setLocked(bool locked) {
    endGesture();
    _value = _value.copyWith(locked: locked);
    notifyListeners();
  }

  void beginGesture() {
    if (!_value.locked) _gestureStart ??= _value;
  }

  void moveBy(double dx, double dy) {
    if (_value.locked || !_value.placed || !dx.isFinite || !dy.isFinite) return;
    _value = _value.copyWith(
      x: (_value.x + dx).clamp(-50, 50),
      y: (_value.y + dy).clamp(-50, 50),
    );
    notifyListeners();
  }

  void endGesture() {
    final start = _gestureStart;
    _gestureStart = null;
    if (start != null && !_same(start, _value)) {
      _remember(start);
      _redo.clear();
      notifyListeners();
    }
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_value);
    _value = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _remember(_value);
    _value = _redo.removeLast();
    notifyListeners();
  }

  void reset() {
    if (_value.locked) return;
    endGesture();
    change(const GroundSetup(), recenterView: true);
  }

  void _remember(GroundSetup setup) {
    _undo.add(setup);
    if (_undo.length > 50) _undo.removeAt(0);
  }

  bool _same(GroundSetup a, GroundSetup b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}

class GroundSetupRepository {
  static const storageKey = 'cricxii_ground_setup_v1';
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<GroundSetup?> load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) return null;
      return GroundSetup.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(GroundSetup setup) =>
      _preferences.setString(storageKey, jsonEncode(setup.toJson()));
}
