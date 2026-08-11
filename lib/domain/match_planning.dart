import 'dart:math';

import 'cricket_match.dart';

class OversFormat {
  const OversFormat._();

  /// CricXii match setup accepts half-over increments. 1.5 means 9 legal balls.
  static int? setupOversToBalls(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    final doubled = value * 2;
    if ((doubled - doubled.round()).abs() > 0.000001) return null;
    return (value * 6).round();
  }

  static String setupOversLabel(int legalBalls) {
    if (legalBalls <= 0) return '0 overs';
    final whole = legalBalls ~/ 6;
    final remainder = legalBalls % 6;
    if (remainder == 0) {
      return '$whole ${whole == 1 ? 'over' : 'overs'}';
    }
    if (remainder == 3) {
      final value = whole == 0 ? '0.5' : '$whole.5';
      return '$value overs';
    }
    if (whole == 0) return '$remainder balls';
    return '$whole over${whole == 1 ? '' : 's'} + $remainder balls';
  }

  /// Ball-by-ball progress without confusing the setup convention where 1.5 = 9 balls.
  static String liveOvers(int legalBalls) {
    final overs = legalBalls ~/ 6;
    final balls = legalBalls % 6;
    if (balls == 0) return '$overs.0';
    return '$overs.$balls';
  }

  static String progressLabel(int legalBalls) {
    final overs = legalBalls ~/ 6;
    final balls = legalBalls % 6;
    if (overs == 0) return '$balls ${balls == 1 ? 'ball' : 'balls'}';
    if (balls == 0) return '$overs ${overs == 1 ? 'over' : 'overs'}';
    return '$overs ${overs == 1 ? 'over' : 'overs'} + $balls ${balls == 1 ? 'ball' : 'balls'}';
  }

  static List<int> bowlingBlocks(int legalBallLimit) {
    if (legalBallLimit <= 0) return const [];
    final result = <int>[];
    var remaining = legalBallLimit;
    while (remaining > 0) {
      final block = min(6, remaining);
      result.add(block);
      remaining -= block;
    }
    return result;
  }
}

class BowlingScheduler {
  const BowlingScheduler._();

  static List<BowlingBlock> generate({
    required List<String> battingOrder,
    required List<String> participantIds,
    required int ballLimit,
    Random? random,
    Map<String, int>? initialLoads,
    String? previousBowlerId,
  }) {
    if (participantIds.length < 2 || battingOrder.isEmpty || ballLimit <= 0) {
      return const <BowlingBlock>[];
    }
    final rng = random ?? Random.secure();
    List<BowlingBlock>? best;
    var bestScore = 1 << 62;

    // Try several valid random schedules, then keep the fairest one. This keeps
    // the result unpredictable without sacrificing workload balance.
    for (var attempt = 0; attempt < 48; attempt++) {
      final candidate = _generateOnce(
        battingOrder: battingOrder,
        participantIds: participantIds,
        ballLimit: ballLimit,
        random: rng,
        initialLoads: initialLoads,
        previousBowlerId: previousBowlerId,
      );
      final score = _fairnessScore(
        candidate,
        participantIds,
        initialLoads: initialLoads,
      );
      if (best == null || score < bestScore) {
        best = candidate;
        bestScore = score;
        if (score == 0) break;
      }
    }
    return best ?? const <BowlingBlock>[];
  }

  static List<BowlingBlock> _generateOnce({
    required List<String> battingOrder,
    required List<String> participantIds,
    required int ballLimit,
    required Random random,
    Map<String, int>? initialLoads,
    String? previousBowlerId,
  }) {
    final loads = <String, int>{
      for (final playerId in participantIds) playerId: 0,
      ...?initialLoads,
    };
    final result = <BowlingBlock>[];
    var previousGlobal = previousBowlerId;

    for (final batterId in battingOrder) {
      final candidates = participantIds
          .where((playerId) => playerId != batterId)
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      String? previousInTurn;
      var startBall = 0;
      final lengths = OversFormat.bowlingBlocks(ballLimit);
      for (var index = 0; index < lengths.length; index++) {
        final blockBalls = lengths[index];
        final selected = _chooseBowler(
          candidates: candidates,
          loads: loads,
          previousInTurn: previousInTurn,
          previousGlobal: previousGlobal,
          random: random,
        );
        result.add(
          BowlingBlock(
            batterId: batterId,
            blockIndex: index,
            startLegalBall: startBall,
            legalBalls: blockBalls,
            bowlerId: selected,
          ),
        );
        loads[selected] = (loads[selected] ?? 0) + blockBalls;
        previousInTurn = selected;
        previousGlobal = selected;
        startBall += blockBalls;
      }
    }
    return result;
  }

  static int _fairnessScore(
    List<BowlingBlock> plan,
    List<String> participantIds, {
    Map<String, int>? initialLoads,
  }) {
    final loads = <String, int>{
      for (final id in participantIds) id: initialLoads?[id] ?? 0,
    };
    for (final block in plan) {
      loads[block.bowlerId] = (loads[block.bowlerId] ?? 0) + block.legalBalls;
    }
    if (loads.isEmpty) return 0;
    final values = loads.values.toList()..sort();
    final spread = values.last - values.first;
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final scaledVariance = values.fold<int>(0, (sum, value) {
      final delta = (value * values.length) - total;
      return sum + (delta * delta);
    });
    return spread * 100000 + scaledVariance;
  }

  static String _chooseBowler({
    required List<String> candidates,
    required Map<String, int> loads,
    required String? previousInTurn,
    required String? previousGlobal,
    required Random random,
  }) {
    if (candidates.length == 1) return candidates.single;

    var pool = List<String>.from(candidates);
    final withoutTurnRepeat = pool
        .where((id) => id != previousInTurn)
        .toList(growable: false);
    if (withoutTurnRepeat.isNotEmpty) pool = withoutTurnRepeat;

    final withoutCrossTurnRepeat = pool
        .where((id) => id != previousGlobal)
        .toList(growable: false);
    if (withoutCrossTurnRepeat.isNotEmpty) pool = withoutCrossTurnRepeat;

    var minLoad = 1 << 30;
    for (final id in pool) {
      minLoad = min(minLoad, loads[id] ?? 0);
    }
    final fairest = pool
        .where((id) => (loads[id] ?? 0) == minLoad)
        .toList(growable: false);
    return fairest[random.nextInt(fairest.length)];
  }

  static BowlingBlock? blockFor(
    CricketMatch match,
    String batterId,
    int legalBallsAlreadyBowled,
  ) {
    final blocks = match.bowlingPlan
        .where((block) => block.batterId == batterId)
        .toList()
      ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
    for (final block in blocks) {
      final end = block.startLegalBall + block.legalBalls;
      if (legalBallsAlreadyBowled >= block.startLegalBall &&
          legalBallsAlreadyBowled < end) {
        return block;
      }
    }
    return null;
  }

  static String? plannedBowlerId(
    CricketMatch match,
    String batterId,
    int legalBallsAlreadyBowled,
  ) => blockFor(match, batterId, legalBallsAlreadyBowled)?.bowlerId;

  static List<BowlingBlock> blocksForBatter(
    CricketMatch match,
    String batterId,
  ) => match.bowlingPlan
      .where((block) => block.batterId == batterId)
      .toList()
    ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
}
