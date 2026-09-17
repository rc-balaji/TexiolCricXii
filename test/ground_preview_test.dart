import 'package:crixx/domain/ground_layout.dart';
import 'package:crixx/services/ground_setup_controller.dart';
import 'package:crixx/widgets/ground_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroundPitchPainter currentPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GroundPitchPainter,
    )).painter! as GroundPitchPainter;

Future<void> showPreview(WidgetTester tester, GroundSetupController controller,
    {double textScale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(width: 284, child: GroundPreview(controller: controller)),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('reset clears a fitted viewport after moving the pitch', (tester) async {
    final controller = GroundSetupController(const GroundSetup(x: 30, y: 20));
    addTearDown(controller.dispose);
    await showPreview(tester, controller);
    await tester.tap(find.byTooltip('Fit pitch in view'));
    await tester.pump();
    expect(currentPainter(tester).pan, isNot(Offset.zero));

    controller.reset();
    await tester.pump();
    expect(currentPainter(tester).pan, Offset.zero);
    expect(currentPainter(tester).zoom, 1);
    expect(currentPainter(tester).setup.x, 0);
    expect(currentPainter(tester).setup.y, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove and place clear previous fit compensation', (tester) async {
    final controller = GroundSetupController(const GroundSetup(x: 30));
    addTearDown(controller.dispose);
    await showPreview(tester, controller);
    await tester.tap(find.byTooltip('Fit pitch in view'));
    await tester.pump();
    expect(currentPainter(tester).pan, isNot(Offset.zero));

    controller.change(controller.value.copyWith(placed: false));
    await tester.pump();
    await tester.tap(find.text('Place pitch'));
    await tester.pump();
    expect(currentPainter(tester).pan, Offset.zero);
    expect(currentPainter(tester).setup.placed, isTrue);
    expect(currentPainter(tester).setup.x, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset recentres a panned view even when the layout is already default', (tester) async {
    final controller = GroundSetupController();
    addTearDown(controller.dispose);
    await showPreview(tester, controller);
    await tester.tap(find.text('Move pitch'));
    await tester.pump();
    await tester.drag(find.byKey(const ValueKey('ground-preview')), const Offset(90, 40));
    await tester.pump();
    expect(currentPainter(tester).pan, isNot(Offset.zero));
    expect(controller.value.x, 0);

    controller.reset();
    await tester.pump();
    expect(currentPainter(tester).pan, Offset.zero);
    expect(controller.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview controls wrap on a narrow view with large text', (tester) async {
    final controller = GroundSetupController();
    addTearDown(controller.dispose);
    await showPreview(tester, controller, textScale: 1.6);
    expect(find.text('Move pitch'), findsOneWidget);
    expect(find.text('PINCH TO ZOOM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
