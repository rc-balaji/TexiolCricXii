import 'package:crixx/domain/ground_layout.dart';
import 'package:crixx/screens/ground_setup_page.dart';
import 'package:crixx/services/ground_ar_service.dart';
import 'package:crixx/services/ground_setup_controller.dart';
import 'package:crixx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository extends GroundSetupRepository {
  GroundSetup? saved;
  bool failSave = false;
  @override
  Future<GroundSetup?> load() async => saved;
  @override
  Future<void> save(GroundSetup setup) async {
    if (failSave) throw StateError('Storage unavailable');
    saved = setup;
  }
}

class FakeAr extends GroundArGateway {
  FakeAr(this.support);
  final GroundArSupport support;
  bool failOpen = false;
  int opens = 0;
  @override
  Future<GroundArSupport> availability() async => support;
  @override
  Future<GroundLayout?> open(GroundLayout layout) async {
    opens++;
    if (failOpen)
      throw PlatformException(
        code: 'camera_denied',
        message: 'Camera access was denied.',
      );
    return layout.copyWith(lengthMetres: 15);
  }
}

Future<void> showPage(
  WidgetTester tester,
  MemoryRepository repository,
  FakeAr ar, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: GroundSetupPage(repository: repository, arGateway: ar),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unsupported device keeps full manual editor and never opens AR',
    (tester) async {
      final ar = FakeAr(GroundArSupport.unsupported);
      await showPage(tester, MemoryRepository(), ar, width: 320);
      expect(
        find.textContaining('AR unavailable on this device.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('open-ground-ar')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('custom-length')));
      await tester.tap(find.byKey(const ValueKey('custom-length')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-pitch-length')),
        '18',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('18.00 yd · Edit'), findsOneWidget);
      expect(ar.opens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid custom length stays editable, does not mutate saved layout',
    (tester) async {
      final repo = MemoryRepository();
      await showPage(tester, repo, FakeAr(GroundArSupport.unsupported));
      await tester.ensureVisible(find.byKey(const ValueKey('custom-length')));
      await tester.tap(find.byKey(const ValueKey('custom-length')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-pitch-length')),
        'NaN',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(
        find.text('Enter a distance between 4 and 40 metres in yards.'),
        findsOneWidget,
      );
      expect(repo.saved, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native returned dimensions save and restore without world placement',
    (tester) async {
      final repo = MemoryRepository();
      final ar = FakeAr(GroundArSupport.supported);
      await showPage(tester, repo, ar);
      await tester.tap(find.byKey(const ValueKey('open-ground-ar')));
      await tester.pumpAndSettle();
      expect(ar.opens, 1);
      expect(repo.saved!.layout.lengthMetres, 15);
      expect(find.text('15.00 m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera denial recovers button and reports useful failure', (
    tester,
  ) async {
    final ar = FakeAr(GroundArSupport.supported)..failOpen = true;
    await showPage(tester, MemoryRepository(), ar);
    await tester.tap(find.byKey(const ValueKey('open-ground-ar')));
    await tester.pumpAndSettle();
    expect(find.text('Camera access was denied.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('open-ground-ar')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text and narrow phone keep all controls usable', (
    tester,
  ) async {
    await showPage(
      tester,
      MemoryRepository(),
      FakeAr(GroundArSupport.unsupported),
      width: 320,
      textScale: 1.6,
    );
    await tester.ensureVisible(find.text('Save setup'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save leaves layout available for retry', (tester) async {
    final repo = MemoryRepository()..failSave = true;
    await showPage(tester, repo, FakeAr(GroundArSupport.unsupported));
    await tester.tap(find.byTooltip('Save ground setup'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the layout. Please try again.'),
      findsOneWidget,
    );
    expect(repo.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ground help remains scrollable on a narrow phone with large text',
    (tester) async {
      await showPage(
        tester,
        MemoryRepository(),
        FakeAr(GroundArSupport.supported),
        width: 320,
        textScale: 1.6,
      );
      await tester.tap(find.byTooltip('Ground setup help'));
      await tester.pumpAndSettle();
      expect(find.text('Set up the pitch, step by step'), findsOneWidget);
      await tester.ensureVisible(find.text('Google Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Google Privacy Policy').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
