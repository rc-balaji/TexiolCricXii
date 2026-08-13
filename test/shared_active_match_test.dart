import 'package:crixx/data/app_store.dart';
import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('participant sees a foreign unfinished match as active but cannot control it', () {
    final store = AppStore();
    store.activePlayerId = '22222222';
    final match = CricketMatch(
      id: 'TXM-LIVE',
      title: 'Evening Match 1',
      creatorPlayerId: '11111111',
      scoringMode: ScoringMode.ballByBall,
      ballLimit: 9,
      participantIds: ['11111111', '22222222', '33333333'],
      battingOrder: ['11111111', '22222222', '33333333'],
      createdAt: DateTime.utc(2026, 8, 13),
      status: MatchStatus.live,
    );
    store.matches.add(match);

    expect(store.activeMatches.map((value) => value.id), contains('TXM-LIVE'));
    expect(store.canControlMatch(match), isFalse);

    store.activePlayerId = '11111111';
    expect(store.canControlMatch(match), isTrue);
  });

  test('shared live match round trip preserves score and current order', () {
    final match = CricketMatch(
      id: 'TXM-ROUNDTRIP',
      title: 'Night Match 2',
      creatorPlayerId: '11111111',
      scoringMode: ScoringMode.ballByBall,
      ballLimit: 9,
      participantIds: ['11111111', '22222222'],
      battingOrder: ['11111111', '22222222'],
      createdAt: DateTime.utc(2026, 8, 13),
      status: MatchStatus.live,
    );
    ScoringEngine.recordDelivery(
      match,
      eventId: 'evt-1',
      batRuns: 4,
      bowlerId: '22222222',
    );

    final restored = CricketMatch.fromJson(match.toJson());
    final states = ScoringEngine.rebuildTurns(restored);

    expect(restored.status, MatchStatus.live);
    expect(restored.creatorPlayerId, '11111111');
    expect(restored.participantIds, ['11111111', '22222222']);
    expect(restored.events.length, 1);
    expect(states['11111111']?.runs, 4);
    expect(ScoringEngine.currentBatterId(restored), '11111111');
  });

  test('completed shared match is no longer returned as active', () {
    final store = AppStore();
    store.activePlayerId = '22222222';
    final match = CricketMatch(
      id: 'TXM-FINAL',
      title: 'Final',
      creatorPlayerId: '11111111',
      scoringMode: ScoringMode.quickTotal,
      ballLimit: 6,
      participantIds: ['11111111', '22222222'],
      battingOrder: ['11111111', '22222222'],
      createdAt: DateTime.utc(2026, 8, 13),
      status: MatchStatus.completed,
      completedAt: DateTime.utc(2026, 8, 13, 20),
    );
    store.matches.add(match);

    expect(store.activeMatches, isEmpty);
  });
}
