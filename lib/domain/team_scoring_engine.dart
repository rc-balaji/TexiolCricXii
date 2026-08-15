import 'enums.dart';
import 'team_match.dart';

class TeamScoringEngine {
  const TeamScoringEngine._();

  static int total(TeamInnings innings) => innings.events.fold<int>(
    0,
    (sum, event) => sum + event.totalRuns,
  );

  static int extras(TeamInnings innings) => innings.events.fold<int>(
    0,
    (sum, event) => sum + event.extraRuns,
  );

  static int legalBalls(TeamInnings innings) =>
      innings.events.where((event) => event.legalBall).length;

  static int wickets(TeamInnings innings) => innings.dismissedPlayerIds.length;

  static int wicketsBefore(TeamInnings innings, int sequence) => innings.events
      .where((event) => event.sequence < sequence && event.isWicket)
      .length;

  static int currentOver(TeamMatch match, TeamInnings innings) =>
      legalBalls(innings) ~/ match.rules.ballsPerOver;

  static int ballInOver(TeamMatch match, TeamInnings innings) =>
      legalBalls(innings) % match.rules.ballsPerOver;

  static String overLabel(TeamMatch match, TeamInnings innings) =>
      '${currentOver(match, innings)}.${ballInOver(match, innings)}';

  static int bowlerBalls(TeamInnings innings, String playerId) => innings.events
      .where((event) => event.bowlerId == playerId && event.legalBall)
      .length;

  static String? currentBowlerId(TeamMatch match, TeamInnings innings) =>
      innings.bowlerByOver[currentOver(match, innings)];

  static bool isFreeHitDelivery(TeamMatch match, TeamInnings innings) {
    if (!match.rules.freeHitEnabled) return false;
    for (final event in innings.events.reversed) {
      if (event.extraType == ExtraType.noBall) return true;
      if (event.legalBall) return false;
    }
    return false;
  }

  static void validateSetup(TeamMatch match) {
    if (match.teamA.playerIds.length < 2 || match.teamB.playerIds.length < 2) {
      throw StateError('Each team needs at least two players.');
    }
    if (match.teamA.battingOrder.length != match.teamA.playerIds.length ||
        match.teamB.battingOrder.length != match.teamB.playerIds.length) {
      throw StateError('Each batting order must contain every team player.');
    }
    for (final side in [match.teamA, match.teamB]) {
      if (side.playerIds.toSet().length != side.playerIds.length ||
          side.battingOrder.toSet().length != side.battingOrder.length ||
          side.battingOrder.toSet().difference(side.playerIds.toSet()).isNotEmpty ||
          side.playerIds.toSet().difference(side.battingOrder.toSet()).isNotEmpty) {
        throw StateError('${side.name} must contain each player exactly once.');
      }
      if (side.bowlingQuotaBalls.entries.any(
        (entry) => !side.playerIds.contains(entry.key) || entry.value < 0,
      )) {
        throw StateError('${side.name} has an invalid bowling limit.');
      }
    }
    final shared = match.teamA.playerIds.toSet().intersection(
      match.teamB.playerIds.toSet(),
    );
    if (shared.length > 1 ||
        (shared.isNotEmpty && shared.single != match.commonJokerPlayerId)) {
      throw StateError('Only the selected Joker can play for both teams.');
    }
    if (match.commonJokerPlayerId != null &&
        (shared.length != 1 || shared.single != match.commonJokerPlayerId)) {
      throw StateError('The selected Joker must be present in both teams.');
    }
    if (match.rules.ballLimit < 1 || match.rules.ballsPerOver < 1) {
      throw StateError('Enter a valid innings length.');
    }
    for (final side in [match.teamA, match.teamB]) {
      final coverage = side.bowlingQuotaBalls.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      if (coverage < match.rules.ballLimit) {
        throw StateError(
          '${side.name} bowling limits cover only $coverage legal balls. '
          'They must cover ${match.rules.ballLimit}.',
        );
      }
    }
    final openingBalls = match.rules.ballLimit < match.rules.ballsPerOver
        ? match.rules.ballLimit
        : match.rules.ballsPerOver;
    for (final batting in [match.teamA, match.teamB]) {
      final bowling = match.otherSide(batting.id);
      final openingBatters = batting.battingOrder.take(2).toSet();
      final hasEligibleOpener = bowling.playerIds.any(
        (id) =>
            !openingBatters.contains(id) &&
            (bowling.bowlingQuotaBalls[id] ?? 0) >= openingBalls,
      );
      if (!hasEligibleOpener) {
        throw StateError(
          '${bowling.name} needs an opening bowler who is not currently batting as the Joker.',
        );
      }
    }
  }

  static TeamInnings startFirstInnings(
    TeamMatch match, {
    required String openingBowlerId,
    DateTime? at,
  }) {
    final toss = match.toss;
    if (toss == null) throw StateError('Complete the toss first.');
    final tossWinner = match.side(toss.winnerTeamId);
    final batting = toss.decision == TeamTossDecision.bat
        ? tossWinner
        : match.otherSide(tossWinner.id);
    final bowling = match.otherSide(batting.id);
    final innings = _newInnings(
      match,
      index: 0,
      batting: batting,
      bowling: bowling,
      openingBowlerId: openingBowlerId,
      at: at,
    );
    match.innings.add(innings);
    match
      ..status = TeamMatchStatus.live
      ..startedAt = at ?? DateTime.now();
    return innings;
  }

  static TeamInnings startSecondInnings(
    TeamMatch match, {
    required String openingBowlerId,
    DateTime? at,
  }) {
    if (match.status != TeamMatchStatus.inningsBreak || match.innings.length != 1) {
      throw StateError('Complete the first innings before starting the chase.');
    }
    final first = match.innings.first;
    final batting = match.side(first.bowlingTeamId);
    final bowling = match.side(first.battingTeamId);
    final innings = _newInnings(
      match,
      index: 1,
      batting: batting,
      bowling: bowling,
      openingBowlerId: openingBowlerId,
      target: total(first) + 1,
      at: at,
    );
    match.innings.add(innings);
    match.status = TeamMatchStatus.live;
    return innings;
  }

  static TeamInnings _newInnings(
    TeamMatch match, {
    required int index,
    required TeamSide batting,
    required TeamSide bowling,
    required String openingBowlerId,
    int? target,
    DateTime? at,
  }) {
    if (batting.battingOrder.length < 2) {
      throw StateError('A team innings needs at least two batters.');
    }
    final innings = TeamInnings(
      index: index,
      battingTeamId: batting.id,
      bowlingTeamId: bowling.id,
      strikerId: batting.battingOrder[0],
      nonStrikerId: batting.battingOrder[1],
      target: target,
      startedAt: at ?? DateTime.now(),
    );
    selectBowler(match, innings, openingBowlerId);
    return innings;
  }

  static void selectBowler(
    TeamMatch match,
    TeamInnings innings,
    String bowlerId,
  ) {
    if (innings.completed) throw StateError('This innings is complete.');
    final bowling = match.side(innings.bowlingTeamId);
    if (!bowling.playerIds.contains(bowlerId)) {
      throw StateError('Choose a player from the bowling team.');
    }
    if (bowlerId == innings.strikerId || bowlerId == innings.nonStrikerId) {
      throw StateError('The Joker cannot bowl to themselves.');
    }
    final over = currentOver(match, innings);
    final previousBowler = innings.bowlerByOver[over - 1];
    if (!match.rules.allowConsecutiveOvers &&
        over > 0 &&
        previousBowler == bowlerId) {
      throw StateError('The same bowler cannot bowl consecutive overs.');
    }
    final used = bowlerBalls(innings, bowlerId);
    final quota = bowling.bowlingQuotaBalls[bowlerId] ?? 0;
    final remainingInInnings = match.rules.ballLimit - legalBalls(innings);
    final remainingInOver = match.rules.ballsPerOver - ballInOver(match, innings);
    final ballsRequired = remainingInInnings < remainingInOver
        ? remainingInInnings
        : remainingInOver;
    if (quota - used < ballsRequired) {
      throw StateError('That bowler does not have enough quota for this over.');
    }
    innings.bowlerByOver[over] = bowlerId;
  }

  static void recordDelivery(
    TeamMatch match, {
    required String eventId,
    required int batRuns,
    int extraRuns = 0,
    int? runningRuns,
    ExtraType extraType = ExtraType.none,
    bool isWicket = false,
    DismissalType dismissalType = DismissalType.none,
    String? dismissedPlayerId,
    List<String> fielderIds = const [],
    DateTime? at,
  }) {
    if (match.status != TeamMatchStatus.live) {
      throw StateError('The team match is not live.');
    }
    final innings = match.currentInnings;
    if (innings == null || innings.completed) {
      throw StateError('There is no live innings.');
    }
    if (innings.awaitingSoloDecision) {
      throw StateError('Choose whether the final batter will continue first.');
    }
    if (batRuns < 0 || extraRuns < 0) {
      throw ArgumentError('Runs cannot be negative.');
    }
    _validateExtra(match.rules, extraType);
    final bowlerId = currentBowlerId(match, innings);
    if (bowlerId == null) throw StateError('Select the bowler for this over.');
    if (bowlerId == innings.strikerId) {
      throw StateError('The Joker cannot bowl to themselves.');
    }
    if (isWicket && dismissalType == DismissalType.none) {
      throw StateError('Select the dismissal type.');
    }
    final freeHit = isFreeHitDelivery(match, innings);
    if (freeHit && isWicket && dismissalType.creditsBowler) {
      throw StateError('Only a run-out or retired-out can dismiss a batter on a free hit.');
    }
    if (extraType == ExtraType.noBall &&
        isWicket &&
        dismissalType.creditsBowler) {
      throw StateError('That dismissal is not valid from a no-ball.');
    }
    final dismissed = dismissedPlayerId ?? (isWicket ? innings.strikerId : null);
    if (isWicket &&
        dismissed != innings.strikerId &&
        dismissed != innings.nonStrikerId) {
      throw StateError('Only a batter currently at the crease can be out.');
    }
    final legal = switch (extraType) {
      ExtraType.wide => match.rules.wideCountsAsLegal,
      ExtraType.noBall => match.rules.noBallCountsAsLegal,
      ExtraType.penalty => false,
      _ => true,
    };
    final event = TeamDeliveryEvent(
      id: eventId,
      sequence: innings.events.length + 1,
      strikerId: innings.strikerId,
      nonStrikerId: innings.nonStrikerId,
      bowlerId: bowlerId,
      createdAt: at ?? DateTime.now(),
      batRuns: batRuns,
      extraRuns: extraRuns,
      runningRuns: runningRuns ?? _defaultRunningRuns(
        batRuns: batRuns,
        extraRuns: extraRuns,
        extraType: extraType,
        rules: match.rules,
      ),
      extraType: extraType,
      legalBall: legal,
      isWicket: isWicket,
      dismissalType: dismissalType,
      dismissedPlayerId: dismissed,
      fielderIds: List<String>.from(fielderIds),
    );
    innings.events.add(event);
    _applyEventState(match, innings, event);
    _evaluateInningsEnd(match, innings, at: event.createdAt);
  }

  static int _defaultRunningRuns({
    required int batRuns,
    required int extraRuns,
    required ExtraType extraType,
    required TeamMatchRules rules,
  }) => switch (extraType) {
    ExtraType.wide =>
      (extraRuns - rules.wideValue).clamp(0, extraRuns).toInt(),
    ExtraType.noBall => batRuns +
        (extraRuns - rules.noBallValue).clamp(0, extraRuns).toInt(),
    ExtraType.bye || ExtraType.legBye => extraRuns,
    ExtraType.penalty => 0,
    _ => batRuns,
  };

  static void _validateExtra(TeamMatchRules rules, ExtraType type) {
    final enabled = switch (type) {
      ExtraType.none => true,
      ExtraType.wide => rules.wideEnabled,
      ExtraType.noBall => rules.noBallEnabled,
      ExtraType.bye => rules.byeEnabled,
      ExtraType.legBye => rules.legByeEnabled,
      ExtraType.penalty => rules.penaltyExtrasEnabled,
    };
    if (!enabled) throw StateError('${type.name} is disabled for this match.');
  }

  static void _applyEventState(
    TeamMatch match,
    TeamInnings innings,
    TeamDeliveryEvent event,
  ) {
    final batting = match.side(innings.battingTeamId);
    if (!innings.soloMode && event.runningRuns.isOdd) {
      _swapBatters(innings);
    }

    if (event.isWicket && event.dismissedPlayerId != null) {
      final dismissed = event.dismissedPlayerId!;
      if (!innings.dismissedPlayerIds.contains(dismissed)) {
        innings.dismissedPlayerIds.add(dismissed);
      }
      if (innings.strikerId == dismissed) {
        innings.strikerId = _nextBatter(batting, innings) ?? '';
      } else if (innings.nonStrikerId == dismissed) {
        innings.nonStrikerId = _nextBatter(batting, innings);
      }
    }

    final remaining = batting.battingOrder
        .where((id) => !innings.dismissedPlayerIds.contains(id))
        .toList(growable: false);
    if (remaining.isEmpty) {
      innings
        ..strikerId = ''
        ..nonStrikerId = null;
      return;
    }
    if (remaining.length == 1) {
      innings
        ..strikerId = remaining.single
        ..nonStrikerId = null;
      if (match.rules.askLastPlayerStanding && !innings.soloMode) {
        innings.awaitingSoloDecision = true;
      }
      return;
    }

    if (innings.strikerId.isEmpty ||
        innings.dismissedPlayerIds.contains(innings.strikerId)) {
      innings.strikerId = _nextBatter(batting, innings) ?? remaining.first;
    }
    if (innings.nonStrikerId == null ||
        innings.dismissedPlayerIds.contains(innings.nonStrikerId)) {
      innings.nonStrikerId = _nextBatter(batting, innings) ??
          remaining.firstWhere((id) => id != innings.strikerId);
    }

    final overCompleted = event.legalBall &&
        legalBalls(innings) % match.rules.ballsPerOver == 0;
    if (overCompleted && !innings.soloMode) _swapBatters(innings);
  }

  static String? _nextBatter(TeamSide batting, TeamInnings innings) {
    while (innings.nextBatterIndex < batting.battingOrder.length) {
      final next = batting.battingOrder[innings.nextBatterIndex++];
      if (!innings.dismissedPlayerIds.contains(next) &&
          next != innings.strikerId &&
          next != innings.nonStrikerId) {
        return next;
      }
    }
    return null;
  }

  static void _swapBatters(TeamInnings innings) {
    final nonStriker = innings.nonStrikerId;
    if (nonStriker == null || innings.soloMode) return;
    final striker = innings.strikerId;
    innings
      ..strikerId = nonStriker
      ..nonStrikerId = striker;
  }

  static void _evaluateInningsEnd(
    TeamMatch match,
    TeamInnings innings, {
    required DateTime at,
  }) {
    final targetReached = innings.target != null && total(innings) >= innings.target!;
    final oversFinished = legalBalls(innings) >= match.rules.ballLimit;
    final batting = match.side(innings.battingTeamId);
    final everyPlayerOut =
        innings.dismissedPlayerIds.length >= batting.playerIds.length;
    if (targetReached) {
      _finishInnings(match, innings, 'Target reached', at);
    } else if (oversFinished) {
      _finishInnings(match, innings, 'Overs completed', at);
    } else if (everyPlayerOut) {
      _finishInnings(match, innings, 'All out', at);
    } else if (!match.rules.askLastPlayerStanding &&
        innings.dismissedPlayerIds.length >= batting.playerIds.length - 1) {
      _finishInnings(match, innings, 'All out', at);
    }
  }

  static void decideLastPlayerStanding(
    TeamMatch match, {
    required bool continueSolo,
    DateTime? at,
  }) {
    final innings = match.currentInnings;
    if (innings == null || !innings.awaitingSoloDecision) {
      throw StateError('No Last Player Standing decision is pending.');
    }
    innings.awaitingSoloDecision = false;
    if (continueSolo) {
      innings
        ..soloMode = true
        ..soloDeclined = false
        ..nonStrikerId = null;
      return;
    }
    innings.soloDeclined = true;
    _finishInnings(match, innings, 'Host ended at the final batter', at ?? DateTime.now());
  }

  static void endInnings(
    TeamMatch match, {
    String reason = 'Ended by host',
    DateTime? at,
  }) {
    final innings = match.currentInnings;
    if (innings == null || innings.completed) return;
    _finishInnings(match, innings, reason, at ?? DateTime.now());
  }

  static void _finishInnings(
    TeamMatch match,
    TeamInnings innings,
    String reason,
    DateTime at,
  ) {
    innings
      ..completed = true
      ..completionReason = reason
      ..completedAt = at
      ..awaitingSoloDecision = false;
    if (innings.index == 0) {
      match.status = TeamMatchStatus.inningsBreak;
    } else {
      match
        ..status = TeamMatchStatus.completed
        ..completedAt = at;
    }
  }

  static bool undoLast(TeamMatch match) {
    final innings = match.currentInnings;
    if (innings == null || innings.events.isEmpty) return false;
    innings.events.removeLast();
    if (match.status == TeamMatchStatus.completed) {
      match
        ..status = TeamMatchStatus.live
        ..completedAt = null
        ..statsApplied = false;
    }
    if (match.status == TeamMatchStatus.inningsBreak) {
      match.status = TeamMatchStatus.live;
    }
    _rebuildInningsState(match, innings);
    return true;
  }

  static void _rebuildInningsState(TeamMatch match, TeamInnings innings) {
    final batting = match.side(innings.battingTeamId);
    final events = List<TeamDeliveryEvent>.from(innings.events);
    final keepSolo = innings.soloMode;
    innings
      ..strikerId = batting.battingOrder.first
      ..nonStrikerId = batting.battingOrder.length > 1
          ? batting.battingOrder[1]
          : null
      ..nextBatterIndex = 2
      ..dismissedPlayerIds.clear()
      ..awaitingSoloDecision = false
      ..soloMode = keepSolo
      ..soloDeclined = false
      ..completed = false
      ..completionReason = null
      ..completedAt = null;
    for (final event in events) {
      _applyEventState(match, innings, event);
      if (innings.awaitingSoloDecision && keepSolo) {
        innings
          ..awaitingSoloDecision = false
          ..soloMode = true
          ..nonStrikerId = null;
      }
    }
    final remaining = batting.playerIds.length - innings.dismissedPlayerIds.length;
    if (remaining > 1) innings.soloMode = false;
    _evaluateInningsEnd(match, innings, at: DateTime.now());
  }

  static TeamMatchResult result(TeamMatch match) {
    if (match.innings.length < 2) {
      return const TeamMatchResult(summary: 'Match in progress');
    }
    final first = match.innings[0];
    final second = match.innings[1];
    final firstTotal = total(first);
    final secondTotal = total(second);
    if (secondTotal > firstTotal) {
      final batting = match.side(second.battingTeamId);
      final wicketsRemaining = (batting.playerIds.length - wickets(second))
          .clamp(0, batting.playerIds.length)
          .toInt();
      return TeamMatchResult(
        summary: '${batting.name} won by $wicketsRemaining wicket${wicketsRemaining == 1 ? '' : 's'}',
        winnerTeamId: batting.id,
        marginWickets: wicketsRemaining,
      );
    }
    if (firstTotal > secondTotal) {
      final batting = match.side(first.battingTeamId);
      final margin = firstTotal - secondTotal;
      return TeamMatchResult(
        summary: '${batting.name} won by $margin run${margin == 1 ? '' : 's'}',
        winnerTeamId: batting.id,
        marginRuns: margin,
      );
    }
    return const TeamMatchResult(summary: 'Match tied');
  }

  static Map<String, TeamPlayerMatchStats> appearanceStats(TeamMatch match) {
    final result = <String, TeamPlayerMatchStats>{};
    String key(String teamId, String playerId) => '$teamId:$playerId';
    for (final side in [match.teamA, match.teamB]) {
      for (final playerId in side.playerIds) {
        result[key(side.id, playerId)] = TeamPlayerMatchStats(
          playerId: playerId,
          teamId: side.id,
        );
      }
    }

    for (final innings in match.innings) {
      final battingTeam = innings.battingTeamId;
      final bowlingTeam = innings.bowlingTeamId;
      for (final event in innings.events) {
        final batter = result[key(battingTeam, event.strikerId)];
        if (batter != null) {
          batter
            ..runs += event.batRuns
            ..balls += event.legalBall ? 1 : 0
            ..fours += event.batRuns == 4 ? 1 : 0
            ..sixes += event.batRuns == 6 ? 1 : 0
            ..points += event.batRuns * match.rules.pointRules.run;
        }
        final bowler = result[key(bowlingTeam, event.bowlerId)];
        if (bowler != null) {
          final excludedFromBowler = event.extraType == ExtraType.bye ||
              event.extraType == ExtraType.legBye ||
              event.extraType == ExtraType.penalty;
          bowler
            ..ballsBowled += event.legalBall ? 1 : 0
            ..runsConceded += excludedFromBowler ? event.batRuns : event.totalRuns
            ..wides += event.extraType == ExtraType.wide ? event.extraRuns : 0
            ..noBalls += event.extraType == ExtraType.noBall ? event.extraRuns : 0;
        }
        if (!event.isWicket || event.dismissedPlayerId == null) continue;
        final dismissed = result[key(battingTeam, event.dismissedPlayerId!)];
        if (dismissed != null) dismissed.dismissed = true;
        if (event.dismissalType.creditsBowler && bowler != null) {
          bowler
            ..wickets += 1
            ..points += match.rules.pointRules.wicket;
          if (event.dismissalType == DismissalType.bowled) {
            bowler.points += match.rules.pointRules.bowledBonus;
          }
        }
        switch (event.dismissalType) {
          case DismissalType.caught:
            _creditCatch(result, bowlingTeam, event.fielderIds.firstOrNull, match);
            break;
          case DismissalType.caughtAndBowled:
            _creditCatch(result, bowlingTeam, event.bowlerId, match);
            break;
          case DismissalType.runOutDirect:
            final fielder = event.fielderIds.firstOrNull == null
                ? null
                : result[key(bowlingTeam, event.fielderIds.first)];
            if (fielder != null) {
              fielder
                ..directRunOuts += 1
                ..points += match.rules.pointRules.directRunOut;
            }
            break;
          case DismissalType.runOutAssisted:
            for (final id in event.fielderIds.take(2)) {
              final fielder = result[key(bowlingTeam, id)];
              if (fielder != null) {
                fielder
                  ..assistedRunOuts += 1
                  ..points += match.rules.pointRules.assistedRunOut;
              }
            }
            break;
          case DismissalType.stumped:
            final keeper = event.fielderIds.firstOrNull == null
                ? null
                : result[key(bowlingTeam, event.fielderIds.first)];
            if (keeper != null) {
              keeper
                ..stumpings += 1
                ..points += match.rules.pointRules.stumping;
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
      for (final playerId in match.side(battingTeam).playerIds) {
        final stats = result[key(battingTeam, playerId)];
        if (stats != null && stats.balls > 0 && !stats.dismissed) {
          stats.points += match.rules.pointRules.notOutBonus;
        }
      }
    }
    return result;
  }

  static void _creditCatch(
    Map<String, TeamPlayerMatchStats> result,
    String teamId,
    String? playerId,
    TeamMatch match,
  ) {
    if (playerId == null) return;
    final fielder = result['$teamId:$playerId'];
    if (fielder != null) {
      fielder
        ..catches += 1
        ..points += match.rules.pointRules.catchPoint;
    }
  }

  static String? playerOfMatchId(TeamMatch match) {
    final totals = <String, int>{};
    for (final stats in appearanceStats(match).values) {
      totals[stats.playerId] = (totals[stats.playerId] ?? 0) + stats.points;
    }
    if (totals.isEmpty) return null;
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final points = b.value.compareTo(a.value);
        return points != 0 ? points : a.key.compareTo(b.key);
      });
    return entries.first.key;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
