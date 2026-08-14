import 'package:crixx/data/app_store.dart';
import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/daily_performance.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player_history.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CricketMatch matchOf({
  required String id,
  required String creator,
  required List<String> players,
  MatchStatus status = MatchStatus.live,
  DateTime? createdAt,
  DateTime? completedAt,
  String? tracker,
  List<String>? tieBreakOrder,
  List<String>? battingOrder,
  PointRules pointRules = const PointRules(notOutBonus: 0),
}) => CricketMatch(
  id: id,
  title: 'Test match',
  creatorPlayerId: creator,
  scoringMode: ScoringMode.quickTotal,
  ballLimit: 6,
  participantIds: players,
  battingOrder: battingOrder ?? List<String>.from(players),
  createdAt: createdAt ?? DateTime.utc(2026, 8, 13, 18),
  completedAt: completedAt,
  status: status,
  trackerPlayerId: tracker,
  tieBreakOrder: tieBreakOrder,
  pointRules: pointRules,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('same-point players use previous match rank order as tie-break', () {
    final match = matchOf(
      id: 'TIE-1',
      creator: '00000001',
      players: const ['00000001', '00000002', '00000003', '00000004'],
      tieBreakOrder: const ['00000001', '00000002', '00000003', '00000004'],
    );

    for (final runs in const [10, 20, 10, 15]) {
      ScoringEngine.recordQuickTotal(
        match,
        eventId: 'e-${match.events.length}',
        runs: runs,
      );
    }

    expect(
      ScoringEngine.rankings(match).map((value) => value.playerId).toList(),
      const ['00000002', '00000004', '00000001', '00000003'],
    );
  });

  test('three-way tie preserves the complete previous rank order', () {
    final match = matchOf(
      id: 'TIE-3',
      creator: '00000001',
      players: const ['00000001', '00000002', '00000003', '00000004'],
      tieBreakOrder: const ['00000004', '00000002', '00000001', '00000003'],
    );
    for (final runs in const [12, 12, 5, 12]) {
      ScoringEngine.recordQuickTotal(
        match,
        eventId: 'e-${match.events.length}',
        runs: runs,
      );
    }
    expect(
      ScoringEngine.rankings(match).map((value) => value.playerId).toList(),
      const ['00000004', '00000002', '00000001', '00000003'],
    );
  });

  test('new player absent from previous match falls back to batting order', () {
    final match = matchOf(
      id: 'TIE-NEW',
      creator: '00000001',
      players: const ['00000001', '00000005', '00000003'],
      battingOrder: const ['00000005', '00000001', '00000003'],
      tieBreakOrder: const ['00000001', '00000003'],
    );
    for (final runs in const [10, 10, 2]) {
      ScoringEngine.recordQuickTotal(
        match,
        eventId: 'e-${match.events.length}',
        runs: runs,
      );
    }
    // Existing previous-rank player remains ahead of a new player on a tie.
    expect(ScoringEngine.rankings(match).first.playerId, '00000001');
  });

  test('daily performance belongs to completion day across midnight', () {
    final match = matchOf(
      id: 'MIDNIGHT',
      creator: '00000001',
      players: const ['00000001', '00000002'],
      status: MatchStatus.completed,
      createdAt: DateTime(2026, 8, 13, 23, 58),
      completedAt: DateTime(2026, 8, 14, 0, 20),
    );
    expect(
      DailyPerformanceSummary.build(DateTime(2026, 8, 13), [match]).matches,
      isEmpty,
    );
    expect(
      DailyPerformanceSummary.build(DateTime(2026, 8, 14), [match]).matches,
      hasLength(1),
    );
  });

  test('automatic match number counts only matches created by this host', () {
    final store = AppStore();
    store.activePlayerId = '00000001';
    final now = DateTime(2026, 8, 13, 18);
    store.matches.addAll([
      matchOf(
        id: 'OWN',
        creator: '00000001',
        players: const ['00000001', '00000002'],
        createdAt: DateTime(2026, 8, 13, 10),
      ),
      matchOf(
        id: 'FOREIGN',
        creator: '00000002',
        players: const ['00000001', '00000002'],
        createdAt: DateTime(2026, 8, 13, 11),
      ),
    ]);
    expect(store.suggestMatchTitle(now), 'Evening Match 2');
  });

  test('active controller lease makes a second host device watch-only', () {
    final store = AppStore();
    store.activePlayerId = '00000001';
    final match = matchOf(
      id: 'LEASE',
      creator: '00000001',
      players: const ['00000001', '00000002'],
    )
      ..controllerUid = 'another-device'
      ..controllerPlayerId = '00000001'
      ..controllerLeaseUntil = DateTime.now().add(const Duration(minutes: 1));
    expect(store.canControlMatch(match), isFalse);
    expect(store.canTakeMatchControl(match), isTrue);
  });

  test('expired controller lease makes host eligible again', () {
    final store = AppStore();
    store.activePlayerId = '00000001';
    final match = matchOf(
      id: 'LEASE-OLD',
      creator: '00000001',
      players: const ['00000001', '00000002'],
    )
      ..controllerUid = 'old-device'
      ..controllerLeaseUntil = DateTime.now().subtract(const Duration(seconds: 1));
    expect(store.canControlMatch(match), isTrue);
  });

  test('selected tracker can score live but is not the setup host', () {
    final store = AppStore();
    store.activePlayerId = '00000002';
    final match = matchOf(
      id: 'TRACKER',
      creator: '00000001',
      players: const ['00000001', '00000002', '00000003'],
      tracker: '00000002',
    );
    expect(store.isMatchTracker(match), isTrue);
    expect(store.canScoreMatch(match), isTrue);
    expect(store.canHostMatch(match), isFalse);
    expect(store.canControlMatch(match), isTrue);
  });

  test('ordinary participant stays read-only', () {
    final store = AppStore();
    store.activePlayerId = '00000003';
    final match = matchOf(
      id: 'WATCH',
      creator: '00000001',
      players: const ['00000001', '00000002', '00000003'],
      tracker: '00000002',
    );
    expect(store.canControlMatch(match), isFalse);
    expect(store.activeMatches.where((value) => value.id == match.id), isEmpty);
    store.matches.add(match);
    expect(store.activeMatches.map((value) => value.id), contains(match.id));
  });

  test('player added during live becomes eligible to see active match', () {
    final match = matchOf(
      id: 'ADD-LIVE',
      creator: '00000001',
      players: ['00000001', '00000002'],
    );
    match.participantIds.add('00000003');
    match.battingOrder.add('00000003');
    final store = AppStore();
    store.activePlayerId = '00000003';
    store.matches.add(match);
    expect(store.activeMatches.map((value) => value.id), contains(match.id));
  });

  test('completed transition removes participant live card but keeps history', () {
    final match = matchOf(
      id: 'FINAL-LIFE',
      creator: '00000001',
      players: const ['00000001', '00000002'],
      status: MatchStatus.completed,
      completedAt: DateTime.utc(2026, 8, 13, 20),
    );
    final store = AppStore();
    store.activePlayerId = '00000002';
    store.matches.add(match);
    expect(store.activeMatches, isEmpty);
    expect(PlayerHistory.completedMatchesFor('00000002', store.matches), hasLength(1));
  });

  test('undoing final event changes completed match back to live', () {
    final match = matchOf(
      id: 'UNDO-LIFE',
      creator: '00000001',
      players: const ['00000001', '00000002'],
    );
    ScoringEngine.recordQuickTotal(match, eventId: '1', runs: 1);
    ScoringEngine.recordQuickTotal(match, eventId: '2', runs: 2);
    expect(match.status, MatchStatus.completed);
    expect(ScoringEngine.undoLast(match), isTrue);
    expect(match.status, MatchStatus.live);
  });

  test('completed history is newest-first by completion time', () {
    final older = matchOf(
      id: 'OLD',
      creator: '00000001',
      players: const ['00000001', '00000002'],
      status: MatchStatus.completed,
      createdAt: DateTime(2026, 8, 13, 22),
      completedAt: DateTime(2026, 8, 14, 0, 5),
    );
    final newer = matchOf(
      id: 'NEW',
      creator: '00000002',
      players: const ['00000001', '00000002'],
      status: MatchStatus.completed,
      createdAt: DateTime(2026, 8, 13, 20),
      completedAt: DateTime(2026, 8, 14, 1, 0),
    );
    expect(
      PlayerHistory.completedMatchesFor('00000001', [older, newer])
          .map((value) => value.id)
          .toList(),
      const ['NEW', 'OLD'],
    );
  });

  test('no previous rank falls back to current batting order on a tie', () {
    final match = matchOf(
      id: 'TIE-FIRST',
      creator: '00000001',
      players: const ['00000001', '00000002', '00000003'],
      battingOrder: const ['00000003', '00000001', '00000002'],
      tieBreakOrder: const [],
    );
    for (final runs in const [7, 7, 7]) {
      ScoringEngine.recordQuickTotal(
        match,
        eventId: 'e-${match.events.length}',
        runs: runs,
      );
    }
    expect(
      ScoringEngine.rankings(match).map((value) => value.playerId).toList(),
      const ['00000003', '00000001', '00000002'],
    );
  });

  test('hardening metadata survives match JSON round trip', () {
    final original = matchOf(
      id: 'META',
      creator: '00000001',
      players: const ['00000001', '00000002'],
      tracker: '00000002',
      tieBreakOrder: const ['00000002', '00000001'],
    )
      ..controllerUid = 'firebase-device-uid'
      ..controllerPlayerId = '00000002'
      ..controllerLeaseUntil = DateTime.utc(2026, 8, 13, 20)
      ..revision = 17;
    final json = original.toJson();
    json['originToken'] = 'origin-test';
    final restored = CricketMatch.fromJson(json);
    expect(restored.controllerUid, 'firebase-device-uid');
    expect(restored.controllerPlayerId, '00000002');
    expect(restored.controllerLeaseUntil, DateTime.utc(2026, 8, 13, 20));
    expect(restored.revision, 17);
    expect(restored.tieBreakOrder, const ['00000002', '00000001']);
    expect(restored.originToken, 'origin-test');
  });

}
