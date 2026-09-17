// Run with: flutter test tool/capture_ground_ui.dart
// Optional GROUND_PREVIEW_FONT points to a local TTF for readable screenshots.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crixx/domain/ground_layout.dart';
import 'package:crixx/screens/ground_setup_page.dart';
import 'package:crixx/services/ground_ar_service.dart';
import 'package:crixx/services/ground_setup_controller.dart';
import 'package:crixx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Memory extends GroundSetupRepository {
  @override
  Future<GroundSetup?> load() async => const GroundSetup();
  @override
  Future<void> save(GroundSetup setup) async {}
}

class _PreviewDevice extends GroundArGateway {
  @override
  Future<GroundArSupport> availability() async => GroundArSupport.unsupported;
  @override
  Future<GroundLayout?> open(GroundLayout layout) async => null;
}

void main() {
  testWidgets('capture actual Flutter Ground screens without simulating AR', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = Platform.environment['GROUND_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')..addFont(File(font).readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
      theme: buildAppTheme(), home: GroundSetupPage(repository: _Memory(), arGateway: _PreviewDevice()),
    )));
    await tester.pumpAndSettle();
    Future<void> capture(String path) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).parent.create(recursive: true);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await capture('build/ground-overview.png');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -540));
    await tester.pumpAndSettle();
    await capture('build/ground-editor.png');
    expect(tester.takeException(), isNull);
  });
}
