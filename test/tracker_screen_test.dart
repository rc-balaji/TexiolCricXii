import 'package:crixx/data/app_store.dart';
import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:crixx/screens/tracker_screen.dart';
import 'package:crixx/theme/app_theme.dart';
import 'package:crixx/widgets/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackerStore extends AppStore {
  @override
  Player? playerById(String? id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  @override
  Future<void> recordDelivery(
    String matchId, {
    required int batRuns,
    int extraRuns = 0,
    ExtraType extraType = ExtraType.none,
    bool legalBall = true,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
  }) async {
    ScoringEngine.recordDelivery(
      matchById(matchId)!,
      eventId: 'event',
      batRuns: batRuns,
      extraRuns: extraRuns,
      extraType: extraType,
      legalBall: legalBall,
      isOut: isOut,
      dismissalType: dismissalType,
      bowlerId: bowlerId,
      fielderIds: fielderIds,
    );
    notifyListeners();
  }
}

void main() {
  testWidgets('OUT credits the planned bowler, not the first fielder', (
    tester,
  ) async {
    final store = _TrackerStore()..activePlayerId = 'batter';
    addTearDown(store.dispose);
    for (final id in ['batter', 'first', 'planned']) {
      store.players.add(
        Player(
          id: id,
          name: id,
          avatarColor: 0xFF19C37D,
          createdAt: DateTime(2026),
        ),
      );
    }
    final match = CricketMatch(
      id: 'match',
      title: 'Bowler regression',
      creatorPlayerId: 'batter',
      scoringMode: ScoringMode.ballByBall,
      ballLimit: 12,
      participantIds: ['batter', 'first', 'planned'],
      battingOrder: ['batter', 'first', 'planned'],
      status: MatchStatus.live,
      createdAt: DateTime(2026),
      bowlingPlan: [
        BowlingBlock(
          batterId: 'batter',
          blockIndex: 0,
          startLegalBall: 0,
          legalBalls: 6,
          bowlerId: 'planned',
        ),
      ],
    );
    store.matches.add(match);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const TrackerScreen(matchId: 'match'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('OUT'));
    await tester.tap(find.text('OUT'));
    await tester.pumpAndSettle();
    final bowlerField = tester.widget<DropdownButtonFormField<String?>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String?> &&
            widget.decoration.labelText == 'Bowler on this ball',
      ),
    );
    expect(bowlerField.initialValue, 'planned');
    await tester.ensureVisible(find.text('Confirm wicket'));
    await tester.tap(find.text('Confirm wicket'));
    await tester.pumpAndSettle();
    expect(match.events.single.bowlerId, 'planned');
    expect(ScoringEngine.calculateStats(match)['planned']!.wickets, 1);
    expect(ScoringEngine.calculateStats(match)['first']!.wickets, 0);
    expect(tester.takeException(), isNull);
  });
}
