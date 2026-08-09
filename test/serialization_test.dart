import 'dart:convert';

import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('match JSON preserves draw, rules, events and 9-ball limit', () {
    final original = CricketMatch(
      id: 'TXM-ABC123',
      title: 'Sunday Ground',
      creatorPlayerId: '100001',
      scoringMode: ScoringMode.ballByBall,
      ballLimit: 9,
      participantIds: ['100001', '100002'],
      battingOrder: ['100002', '100001'],
      createdAt: DateTime.utc(2026, 8, 9),
      status: MatchStatus.live,
      pointRules: const PointRules(wicket: 25, catchPoint: 12),
      drawPool: const [
        DrawCard(id: 'card-a', order: 1, colorValue: 0xFF19C37D),
        DrawCard(id: 'card-b', order: 2, colorValue: 0xFFFFB020),
      ],
      events: [
        ScoreEvent(
          id: 'event-a',
          type: ScoreEventType.delivery,
          batterId: '100002',
          createdAt: DateTime.utc(2026, 8, 9, 10),
          batRuns: 6,
          bowlerId: '100001',
        ),
      ],
    );

    final encoded = jsonEncode(original.toJson());
    final restored = CricketMatch.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(restored.id, original.id);
    expect(restored.ballLimit, 9);
    expect(restored.battingOrder, ['100002', '100001']);
    expect(restored.pointRules.wicket, 25);
    expect(restored.drawPool.length, 2);
    expect(restored.events.single.batRuns, 6);
  });
}
