import 'cricket_match.dart';
import 'enums.dart';

class ScoringEngine {
  const ScoringEngine._();

  static Map<String, TurnState> rebuildTurns(CricketMatch match) {
    final states = <String, TurnState>{
      for (final id in match.battingOrder) id: TurnState(playerId: id),
    };

    for (final event in match.events) {
      final state = states[event.batterId];
      if (state == null) continue;
      state.runs += event.batRuns;
      state.extras += event.extraRuns;
      if (event.type == ScoreEventType.quickSummary) {
        state.quickEntry = true;
      } else if (event.legalBall) {
        state.legalBalls += 1;
      }
      if (event.isOut) {
        state.isOut = true;
        state.dismissalType = event.dismissalType;
      }
    }
    return states;
  }

  static String? currentBatterId(CricketMatch match) {
    final states = rebuildTurns(match);
    for (final playerId in match.battingOrder) {
      if (!(states[playerId]?.isComplete(match.ballLimit) ?? false)) {
        return playerId;
      }
    }
    return null;
  }

  static void refreshStatus(CricketMatch match) {
    if (match.status == MatchStatus.draft ||
        match.status == MatchStatus.drawing) {
      return;
    }
    match.status = currentBatterId(match) == null
        ? MatchStatus.completed
        : MatchStatus.live;
  }

  static void recordDelivery(
    CricketMatch match, {
    required String eventId,
    required int batRuns,
    int extraRuns = 0,
    ExtraType extraType = ExtraType.none,
    bool legalBall = true,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
    DateTime? at,
  }) {
    if (match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    if (match.scoringMode != ScoringMode.ballByBall) {
      throw StateError('This match uses direct-runs scoring.');
    }
    final batterId = currentBatterId(match);
    if (batterId == null) {
      throw StateError('Every player has completed a turn.');
    }
    if (batRuns < 0 || extraRuns < 0) {
      throw ArgumentError('Runs cannot be negative.');
    }
    if (isOut && dismissalType == DismissalType.none) {
      throw ArgumentError('An out event requires a dismissal type.');
    }

    match.events.add(
      ScoreEvent(
        id: eventId,
        type: ScoreEventType.delivery,
        batterId: batterId,
        createdAt: at ?? DateTime.now(),
        batRuns: batRuns,
        extraRuns: extraRuns,
        extraType: extraType,
        legalBall: legalBall,
        isOut: isOut,
        dismissalType: dismissalType,
        bowlerId: bowlerId,
        fielderIds: fielderIds,
      ),
    );
    refreshStatus(match);
  }

  static void recordQuickTotal(
    CricketMatch match, {
    required String eventId,
    required int runs,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
    DateTime? at,
  }) {
    if (match.status != MatchStatus.live) {
      throw StateError('The match is not live.');
    }
    if (match.scoringMode != ScoringMode.quickTotal) {
      throw StateError('This match uses ball tracking.');
    }
    final batterId = currentBatterId(match);
    if (batterId == null) {
      throw StateError('Every player has completed a turn.');
    }
    if (runs < 0) throw ArgumentError('Runs cannot be negative.');
    if (isOut && dismissalType == DismissalType.none) {
      throw ArgumentError('An out entry requires a dismissal type.');
    }

    match.events.add(
      ScoreEvent(
        id: eventId,
        type: ScoreEventType.quickSummary,
        batterId: batterId,
        createdAt: at ?? DateTime.now(),
        batRuns: runs,
        isOut: isOut,
        dismissalType: dismissalType,
        bowlerId: bowlerId,
        fielderIds: fielderIds,
      ),
    );
    refreshStatus(match);
  }

  static bool undoLast(CricketMatch match) {
    if (match.events.isEmpty) return false;
    match.events.removeLast();
    if (match.status == MatchStatus.completed) match.status = MatchStatus.live;
    refreshStatus(match);
    return true;
  }

  static int resetCurrentTurn(CricketMatch match) {
    final current = currentBatterId(match);
    if (current == null) return 0;
    final before = match.events.length;
    match.events.removeWhere((event) => event.batterId == current);
    refreshStatus(match);
    return before - match.events.length;
  }

  static Map<String, PlayerMatchStats> calculateStats(CricketMatch match) {
    final turnStates = rebuildTurns(match);
    final result = <String, PlayerMatchStats>{
      for (final id in match.participantIds) id: PlayerMatchStats(playerId: id),
    };

    for (final state in turnStates.values) {
      final stats = result[state.playerId]!;
      stats.runs = state.runs;
      stats.balls = state.legalBalls;
      stats.isOut = state.isOut;
      stats.points += state.runs * match.pointRules.run;
      if (!state.isOut && state.isComplete(match.ballLimit)) {
        stats.points += match.pointRules.notOutBonus;
      }
    }

    for (final event in match.events.where((value) => value.isOut)) {
      if (event.dismissalType.creditsBowler && event.bowlerId != null) {
        final bowler = result[event.bowlerId!];
        if (bowler != null) {
          bowler.wickets += 1;
          bowler.points += match.pointRules.wicket;
          if (event.dismissalType == DismissalType.bowled) {
            bowler.points += match.pointRules.bowledBonus;
          }
        }
      }
      switch (event.dismissalType) {
        case DismissalType.caught:
          if (event.fielderIds.isNotEmpty) {
            final fielder = result[event.fielderIds.first];
            if (fielder != null) {
              fielder.catches += 1;
              fielder.points += match.pointRules.catchPoint;
            }
          }
          break;
        case DismissalType.caughtAndBowled:
          final fielder = event.bowlerId == null
              ? null
              : result[event.bowlerId!];
          if (fielder != null) {
            fielder.catches += 1;
            fielder.points += match.pointRules.catchPoint;
          }
          break;
        case DismissalType.runOutDirect:
          if (event.fielderIds.isNotEmpty) {
            final fielder = result[event.fielderIds.first];
            if (fielder != null) {
              fielder.directRunOuts += 1;
              fielder.points += match.pointRules.directRunOut;
            }
          }
          break;
        case DismissalType.runOutAssisted:
          for (final id in event.fielderIds.take(2)) {
            final fielder = result[id];
            if (fielder != null) {
              fielder.assistedRunOuts += 1;
              fielder.points += match.pointRules.assistedRunOut;
            }
          }
          break;
        case DismissalType.stumped:
          if (event.fielderIds.isNotEmpty) {
            final keeper = result[event.fielderIds.first];
            if (keeper != null) {
              keeper.stumpings += 1;
              keeper.points += match.pointRules.stumping;
            }
          }
          break;
        case DismissalType.none:
        case DismissalType.bowled:
        case DismissalType.lbw:
        case DismissalType.hitWicket:
        case DismissalType.retiredOut:
          break;
      }
    }
    return result;
  }

  static List<PlayerMatchStats> rankings(CricketMatch match) {
    final result = calculateStats(match).values.toList();
    final tieOrder = <String, int>{
      for (var index = 0; index < match.tieBreakOrder.length; index++)
        match.tieBreakOrder[index]: index,
    };
    final currentOrder = <String, int>{
      for (var index = 0; index < match.battingOrder.length; index++)
        match.battingOrder[index]: index,
    };
    final participantOrder = <String, int>{
      for (var index = 0; index < match.participantIds.length; index++)
        match.participantIds[index]: index,
    };

    result.sort((a, b) {
      final primary = match.winnerMetric == MatchWinnerMetric.runs
          ? b.runs.compareTo(a.runs)
          : b.points.compareTo(a.points);
      if (primary != 0) return primary;

      // CricXii tie-break: previous completed match rank/order wins the tie.
      // If a player was not in that previous match, keep today's current
      // batting order, then the stable participant creation order.
      final previous = (tieOrder[a.playerId] ?? 1 << 20).compareTo(
        tieOrder[b.playerId] ?? 1 << 20,
      );
      if (previous != 0) return previous;

      final current = (currentOrder[a.playerId] ?? 1 << 20).compareTo(
        currentOrder[b.playerId] ?? 1 << 20,
      );
      if (current != 0) return current;

      final participant = (participantOrder[a.playerId] ?? 1 << 20).compareTo(
        participantOrder[b.playerId] ?? 1 << 20,
      );
      if (participant != 0) return participant;

      return a.playerId.compareTo(b.playerId);
    });
    return result;
  }
}
