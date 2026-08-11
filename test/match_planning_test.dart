import 'dart:math';

import 'package:crixx/domain/match_planning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OversFormat', () {
    test('CricXii setup notation converts 1.5 overs to 9 legal balls', () {
      expect(OversFormat.setupOversToBalls('1.5'), 9);
      expect(OversFormat.setupOversLabel(9), '1.5 overs');
      expect(OversFormat.progressLabel(9), '1 over + 3 balls');
    });

    test('9 legal balls creates a full over and a 3-ball final block', () {
      expect(OversFormat.bowlingBlocks(9), [6, 3]);
    });
  });

  group('Balanced bowling scheduler', () {
    test('never assigns the batter as their own bowler', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1', 'p2', 'p3', 'p4', 'p5'],
        participantIds: const ['p1', 'p2', 'p3', 'p4', 'p5'],
        ballLimit: 12,
        random: Random(7),
      );
      expect(plan, isNotEmpty);
      for (final block in plan) {
        expect(block.bowlerId, isNot(block.batterId));
      }
    });

    test('two players use the only available bowler for all overs', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1', 'p2'],
        participantIds: const ['p1', 'p2'],
        ballLimit: 24,
        random: Random(1),
      );
      final p1Blocks = plan.where((block) => block.batterId == 'p1').toList();
      expect(p1Blocks.length, 4);
      expect(p1Blocks.every((block) => block.bowlerId == 'p2'), isTrue);
    });

    test('two overs use different bowlers when alternatives exist', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1'],
        participantIds: const ['p1', 'p2', 'p3'],
        ballLimit: 12,
        random: Random(2),
      );
      expect(plan.length, 2);
      expect(plan[0].bowlerId, isNot(plan[1].bowlerId));
    });

    test('one-and-a-half overs uses a full over then a separate three-ball block when possible', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1'],
        participantIds: const ['p1', 'p2', 'p3'],
        ballLimit: 9,
        random: Random(22),
      );
      expect(plan.length, 2);
      expect(plan.map((block) => block.legalBalls).toList(), [6, 3]);
      expect(plan[0].bowlerId, isNot(plan[1].bowlerId));
    });

    test('avoids last-over to next-batter first-over repeat when possible', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1', 'p2', 'p3'],
        participantIds: const ['p1', 'p2', 'p3', 'p4'],
        ballLimit: 6,
        random: Random(3),
      );
      expect(plan.length, 3);
      expect(plan[0].bowlerId, isNot(plan[1].bowlerId));
      expect(plan[1].bowlerId, isNot(plan[2].bowlerId));
    });

    test('keeps total scheduled bowling reasonably balanced', () {
      final plan = BowlingScheduler.generate(
        battingOrder: const ['p1', 'p2', 'p3', 'p4', 'p5'],
        participantIds: const ['p1', 'p2', 'p3', 'p4', 'p5'],
        ballLimit: 12,
        random: Random(4),
      );
      final loads = <String, int>{
        'p1': 0,
        'p2': 0,
        'p3': 0,
        'p4': 0,
        'p5': 0,
      };
      for (final block in plan) {
        loads[block.bowlerId] = loads[block.bowlerId]! + block.legalBalls;
      }
      final values = loads.values.toList()..sort();
      expect(values.last - values.first, lessThanOrEqualTo(6));
    });
  });
}
