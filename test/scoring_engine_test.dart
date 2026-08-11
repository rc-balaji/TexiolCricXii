import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CricXii Singles scoring', () {
    test('1.5-over preset ends at exactly 9 legal balls', () {
      final match = _match(ballLimit: 9);

      for (var index = 0; index < 8; index++) {
        _delivery(match, 'b$index', runs: 1);
      }
      _delivery(
        match,
        'wide',
        extraRuns: 1,
        extraType: ExtraType.wide,
        legalBall: false,
      );

      expect(ScoringEngine.currentBatterId(match), 'p1');
      expect(ScoringEngine.rebuildTurns(match)['p1']!.legalBalls, 8);

      _delivery(match, 'b9', runs: 6);

      expect(ScoringEngine.currentBatterId(match), 'p2');
      expect(ScoringEngine.rebuildTurns(match)['p1']!.runs, 14);
    });

    test('a wicket ends the current turn before the ball limit', () {
      final match = _match(ballLimit: 12);

      _delivery(
        match,
        'w1',
        runs: 2,
        isOut: true,
        dismissal: DismissalType.bowled,
        bowlerId: 'p2',
      );

      final state = ScoringEngine.rebuildTurns(match)['p1']!;
      expect(state.legalBalls, 1);
      expect(state.isOut, isTrue);
      expect(ScoringEngine.currentBatterId(match), 'p2');
    });

    test('direct-runs mode advances after one final total per player', () {
      final match = _match(mode: ScoringMode.quickTotal);

      ScoringEngine.recordQuickTotal(match, eventId: 'q1', runs: 27);

      expect(ScoringEngine.currentBatterId(match), 'p2');
      expect(ScoringEngine.calculateStats(match)['p1']!.runs, 27);
      expect(ScoringEngine.calculateStats(match)['p1']!.balls, 0);
    });

    test('final turn completes match and undo reopens it', () {
      final match = _match(mode: ScoringMode.quickTotal);
      ScoringEngine.recordQuickTotal(match, eventId: 'q1', runs: 10);
      ScoringEngine.recordQuickTotal(match, eventId: 'q2', runs: 11);
      ScoringEngine.recordQuickTotal(match, eventId: 'q3', runs: 12);

      expect(match.status, MatchStatus.completed);
      expect(ScoringEngine.currentBatterId(match), isNull);

      expect(ScoringEngine.undoLast(match), isTrue);
      expect(match.status, MatchStatus.live);
      expect(ScoringEngine.currentBatterId(match), 'p3');
    });

    test('caught wicket credits bowler and catcher separately', () {
      final match = _match();
      _delivery(
        match,
        'caught',
        runs: 4,
        isOut: true,
        dismissal: DismissalType.caught,
        bowlerId: 'p2',
        fielders: const ['p3'],
      );

      final stats = ScoringEngine.calculateStats(match);
      expect(stats['p1']!.runs, 4);
      expect(stats['p2']!.wickets, 1);
      expect(stats['p2']!.points, 5);
      expect(stats['p3']!.catches, 1);
      expect(stats['p3']!.points, 2);
    });

    test('direct run-out gives no bowler wicket', () {
      final match = _match();
      _delivery(
        match,
        'direct',
        isOut: true,
        dismissal: DismissalType.runOutDirect,
        bowlerId: 'p2',
        fielders: const ['p3'],
      );

      final stats = ScoringEngine.calculateStats(match);
      expect(stats['p2']!.wickets, 0);
      expect(stats['p3']!.directRunOuts, 1);
      expect(stats['p3']!.points, 3);
    });

    test('assisted run-out credits both fielders', () {
      final match = _match(participants: const ['p1', 'p2', 'p3', 'p4']);
      _delivery(
        match,
        'assisted',
        isOut: true,
        dismissal: DismissalType.runOutAssisted,
        fielders: const ['p3', 'p4'],
      );

      final stats = ScoringEngine.calculateStats(match);
      expect(stats['p3']!.assistedRunOuts, 1);
      expect(stats['p4']!.assistedRunOuts, 1);
      expect(stats['p3']!.points, 1);
      expect(stats['p4']!.points, 1);
    });

    test('stumping credits the bowler and wicketkeeper', () {
      final match = _match();
      _delivery(
        match,
        'stumped',
        isOut: true,
        dismissal: DismissalType.stumped,
        bowlerId: 'p2',
        fielders: const ['p3'],
      );

      final stats = ScoringEngine.calculateStats(match);
      expect(stats['p2']!.wickets, 1);
      expect(stats['p2']!.points, 5);
      expect(stats['p3']!.stumpings, 1);
      expect(stats['p3']!.points, 2);
    });

    test('runs-only ranking ignores a higher fielding-points total', () {
      final match = _match(
        mode: ScoringMode.quickTotal,
        winnerMetric: MatchWinnerMetric.runs,
      );
      ScoringEngine.recordQuickTotal(match, eventId: 'q1', runs: 5);
      ScoringEngine.recordQuickTotal(match, eventId: 'q2', runs: 20);
      ScoringEngine.recordQuickTotal(
        match,
        eventId: 'q3',
        runs: 1,
        isOut: true,
        dismissalType: DismissalType.caughtAndBowled,
        bowlerId: 'p1',
      );

      expect(ScoringEngine.rankings(match).first.playerId, 'p2');
    });
  });
}

CricketMatch _match({
  int ballLimit = 9,
  ScoringMode mode = ScoringMode.ballByBall,
  MatchWinnerMetric winnerMetric = MatchWinnerMetric.overallPoints,
  List<String> participants = const ['p1', 'p2', 'p3'],
}) {
  return CricketMatch(
    id: 'TXM-TEST',
    title: 'Test Singles',
    creatorPlayerId: participants.first,
    scoringMode: mode,
    ballLimit: ballLimit,
    participantIds: List<String>.from(participants),
    battingOrder: List<String>.from(participants),
    createdAt: DateTime(2026, 8, 9),
    status: MatchStatus.live,
    winnerMetric: winnerMetric,
  );
}

void _delivery(
  CricketMatch match,
  String id, {
  int runs = 0,
  int extraRuns = 0,
  ExtraType extraType = ExtraType.none,
  bool legalBall = true,
  bool isOut = false,
  DismissalType dismissal = DismissalType.none,
  String? bowlerId,
  List<String> fielders = const [],
}) {
  ScoringEngine.recordDelivery(
    match,
    eventId: id,
    batRuns: runs,
    extraRuns: extraRuns,
    extraType: extraType,
    legalBall: legalBall,
    isOut: isOut,
    dismissalType: dismissal,
    bowlerId: bowlerId,
    fielderIds: fielders,
    at: DateTime(2026, 8, 9),
  );
}
