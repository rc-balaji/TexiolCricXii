import 'dart:convert';
import 'dart:math' as math;

import 'package:crixx/domain/ground_layout.dart';
import 'package:crixx/services/ground_setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('22-yard pitch retains exact conversion, not rounded display metres', () {
    const layout = GroundLayout();
    expect(layout.lengthMetres, closeTo(20.1168, .0000001));
    expect(layout.lengthYards, closeTo(22, .0000001));
    expect(GroundLayout.wicketWidth, closeTo(.2286, .0000001));
    expect(GroundLayout.stumpHeight, closeTo(.7112, .0000001));
  });

  test('custom pitch keeps crease dimensions and standard stump scale', () {
    final custom = const GroundLayout().copyWith(lengthMetres: 9);
    final popping = custom.endLines[1];
    expect(popping.y1, closeTo(1.2192, .0000001));
    expect(popping.x2 - popping.x1, closeTo(3.6576, .0000001));
    expect(custom.endLines[2].x1.abs(), closeTo(1.3208, .0000001));
    expect(custom.isStandard, isFalse);
  });

  test('guides are opt-in and independently adjustable', () {
    expect(const GroundLayout().endLines.where((line) => line.isGuide), isEmpty);
    final layout = const GroundLayout().copyWith(wideGuides: true, wideOffsetMetres: .75, showCreases: false);
    expect(layout.endLines.length, 2);
    expect(layout.endLines.map((line) => line.x1).toSet(), {-.75, .75});
  });

  test('invalid typed distance inputs do not reach a renderer', () {
    for (final length in [double.nan, double.infinity, -1.0, 0.0, 41.0]) {
      expect(() => const GroundLayout().copyWith(lengthMetres: length), throwsArgumentError);
    }
    expect(() => const GroundLayout().copyWith(runUpMetres: 21), throwsArgumentError);
    expect(() => const GroundLayout().copyWith(wideOffsetMetres: .1), throwsArgumentError);
  });

  test('corrupt or out-of-range persisted/bridge values are sanitized', () {
    final layout = GroundLayout.fromJson({
      'lengthMetres': double.nan, 'runUpMetres': 100, 'wideOffsetMetres': -.5,
      'showStumps': 'false', 'wideGuides': true,
    });
    expect(layout.isStandard, isTrue);
    expect(layout.runUpMetres, 20);
    expect(layout.wideOffsetMetres, .3);
    expect(layout.showStumps, isTrue);
    expect(layout.wideGuides, isTrue);
    final setup = GroundSetup.fromJson({'x': double.infinity, 'y': 900, 'rotation': double.nan});
    expect(setup.x, 0);
    expect(setup.y, 50);
    expect(setup.rotation, 0);
  });

  test('save format round-trips layout without camera anchors or physical coordinates', () {
    final setup = GroundSetup(layout: const GroundLayout().copyWith(lengthMetres: 15, wideGuides: true),
      rotation: .3, x: 2, locked: true, endsSwapped: true);
    final restored = GroundSetup.fromJson(jsonDecode(jsonEncode(setup.toJson())) as Map<String, dynamic>);
    expect(restored.toJson(), setup.toJson());
    expect(setup.layout.toJson().containsKey('x'), isFalse);
    expect(setup.layout.toJson().containsKey('anchor'), isFalse);
  });

  test('drag is one undo step and redo returns final position', () {
    final controller = GroundSetupController();
    controller.beginGesture();
    controller.moveBy(1, 2);
    controller.moveBy(2, 1);
    controller.endGesture();
    expect(controller.value.x, 3);
    controller.undo();
    expect(controller.value.x, 0);
    expect(controller.canUndo, isFalse);
    controller.redo();
    expect(controller.value.y, 3);
    controller.dispose();
  });

  test('continuous slider changes are one undo step and preserve earlier edits', () {
    final controller = GroundSetupController();
    controller.change(controller.value.copyWith(x: 2));
    controller.beginGesture();
    for (var index = 1; index <= 40; index++) {
      controller.change(controller.value.copyWith(
        layout: controller.value.layout.copyWith(runUpMetres: index / 2),
      ));
    }
    controller.endGesture();
    controller.undo();
    expect(controller.value.layout.runUpMetres, 0);
    expect(controller.value.x, 2);
    controller.redo();
    expect(controller.value.layout.runUpMetres, 20);
    controller.undo();
    controller.undo();
    expect(controller.value.x, 0);
    expect(controller.canUndo, isFalse);
    controller.dispose();
  });

  test('lock prevents geometry, gestures, undo and removal until unlocked', () {
    final controller = GroundSetupController();
    controller.change(controller.value.copyWith(x: 2));
    controller.setLocked(true);
    controller.change(controller.value.copyWith(placed: false));
    controller.beginGesture();
    controller.moveBy(50, 50);
    controller.endGesture();
    controller.undo();
    controller.reset();
    expect(controller.value.x, 2);
    expect(controller.value.placed, isTrue);
    controller.setLocked(false);
    controller.undo();
    expect(controller.value.x, 0);
    controller.dispose();
  });

  test('new edit discards redo and reset remains undoable', () {
    final controller = GroundSetupController();
    controller.change(controller.value.copyWith(rotation: math.pi / 2));
    controller.change(controller.value.copyWith(placed: false));
    controller.undo();
    controller.change(controller.value.copyWith(x: 3));
    expect(controller.canRedo, isFalse);
    controller.reset();
    expect(controller.value.x, 0);
    controller.undo();
    expect(controller.value.x, 3);
    expect(controller.value.rotation, closeTo(math.pi / 2, .00001));
    controller.dispose();
  });
}
