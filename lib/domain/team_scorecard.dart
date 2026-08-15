import 'enums.dart';
import 'team_match.dart';
import 'team_scoring_engine.dart';

class TeamScorecardBatterRow {
  const TeamScorecardBatterRow({
    required this.playerId,
    required this.dismissal,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
  });

  final String playerId;
  final TeamScorecardDismissal dismissal;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;
}

class TeamScorecardDismissal {
  const TeamScorecardDismissal({
    required this.type,
    this.bowlerId,
    this.fielderIds = const <String>[],
    this.isOut = false,
  });

  final DismissalType type;
  final String? bowlerId;
  final List<String> fielderIds;
  final bool isOut;

  String text(String Function(String id) playerName) {
    if (!isOut || type == DismissalType.none) return 'not out';
    final bowler = bowlerId == null ? null : playerName(bowlerId!);
    final fielders = fielderIds.map(playerName).toList(growable: false);
    final fielderText = fielders.join('/');
    return switch (type) {
      DismissalType.bowled => bowler == null ? 'bowled' : 'b $bowler',
      DismissalType.caught => fielders.isEmpty
          ? (bowler == null ? 'caught' : 'c ? b $bowler')
          : (bowler == null ? 'c ${fielders.first}' : 'c ${fielders.first} b $bowler'),
      DismissalType.caughtAndBowled =>
        bowler == null ? 'caught & bowled' : 'c & b $bowler',
      DismissalType.lbw => bowler == null ? 'lbw' : 'lbw b $bowler',
      DismissalType.runOutDirect || DismissalType.runOutAssisted =>
        fielders.isEmpty ? 'run out' : 'run out ($fielderText)',
      DismissalType.stumped => fielders.isEmpty
          ? (bowler == null ? 'stumped' : 'st ? b $bowler')
          : (bowler == null ? 'st ${fielders.first}' : 'st ${fielders.first} b $bowler'),
      DismissalType.hitWicket =>
        bowler == null ? 'hit wicket' : 'hit wicket b $bowler',
      DismissalType.retiredOut => 'retired out',
      DismissalType.none => 'not out',
    };
  }
}

class TeamScorecardBowlerRow {
  const TeamScorecardBowlerRow({
    required this.playerId,
    required this.legalBalls,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.noBalls,
    required this.wides,
    required this.ballsPerOver,
  });

  final String playerId;
  final int legalBalls;
  final int maidens;
  final int runs;
  final int wickets;
  final int noBalls;
  final int wides;
  final int ballsPerOver;

  String get overs => '${legalBalls ~/ ballsPerOver}.${legalBalls % ballsPerOver}';
  double get economy =>
      legalBalls == 0 ? 0 : runs * ballsPerOver / legalBalls;
}

class TeamScorecardFall {
  const TeamScorecardFall({
    required this.playerId,
    required this.score,
    required this.wicketNumber,
    required this.legalBalls,
    required this.ballsPerOver,
  });

  final String playerId;
  final int score;
  final int wicketNumber;
  final int legalBalls;
  final int ballsPerOver;

  String get scoreLabel => '$score-$wicketNumber';
  String get overLabel => '${legalBalls ~/ ballsPerOver}.${legalBalls % ballsPerOver}';
}

class TeamScorecardPartnership {
  const TeamScorecardPartnership({
    required this.playerIds,
    required this.runs,
    required this.balls,
    required this.runsByPlayer,
    required this.ballsByPlayer,
  });

  final List<String> playerIds;
  final int runs;
  final int balls;
  final Map<String, int> runsByPlayer;
  final Map<String, int> ballsByPlayer;
}

class TeamScorecardData {
  const TeamScorecardData({
    required this.batters,
    required this.yetToBat,
    required this.bowlers,
    required this.falls,
    required this.partnerships,
    required this.total,
    required this.wickets,
    required this.legalBalls,
    required this.extras,
    required this.byes,
    required this.legByes,
    required this.wides,
    required this.noBalls,
    required this.penalties,
    required this.ballsPerOver,
  });

  final List<TeamScorecardBatterRow> batters;
  final List<String> yetToBat;
  final List<TeamScorecardBowlerRow> bowlers;
  final List<TeamScorecardFall> falls;
  final List<TeamScorecardPartnership> partnerships;
  final int total;
  final int wickets;
  final int legalBalls;
  final int extras;
  final int byes;
  final int legByes;
  final int wides;
  final int noBalls;
  final int penalties;
  final int ballsPerOver;

  String get overs => '${legalBalls ~/ ballsPerOver}.${legalBalls % ballsPerOver}';
  double get runRate =>
      legalBalls == 0 ? 0 : total * ballsPerOver / legalBalls;

  String get extrasBreakdown =>
      'b $byes, lb $legByes, w $wides, nb $noBalls, p $penalties';
}

class TeamScorecardBuilder {
  const TeamScorecardBuilder._();

  static TeamScorecardData build(TeamMatch match, TeamInnings innings) {
    final batting = match.side(innings.battingTeamId);
    final bowling = match.side(innings.bowlingTeamId);
    final stats = TeamScoringEngine.inningsAppearanceStats(match, innings);
    TeamPlayerMatchStats stat(String teamId, String playerId) =>
        stats['$teamId:$playerId'] ??
        TeamPlayerMatchStats(playerId: playerId, teamId: teamId);

    final appeared = <String>{};
    for (final event in innings.events) {
      appeared.add(event.strikerId);
      if (event.nonStrikerId != null) appeared.add(event.nonStrikerId!);
      if (event.dismissedPlayerId != null) appeared.add(event.dismissedPlayerId!);
    }
    if (innings.events.isNotEmpty) {
      appeared.add(innings.strikerId);
      if (innings.nonStrikerId != null) appeared.add(innings.nonStrikerId!);
    }
    appeared.addAll(innings.nextBatterByWicketSequence.values);

    final batters = <TeamScorecardBatterRow>[];
    for (final id in TeamScoringEngine.battingDisplayOrder(match, innings)) {
      if (!appeared.contains(id)) continue;
      final value = stat(batting.id, id);
      final wicket = _dismissalFor(innings, id);
      batters.add(
        TeamScorecardBatterRow(
          playerId: id,
          dismissal: wicket,
          runs: value.runs,
          balls: value.balls,
          fours: value.fours,
          sixes: value.sixes,
        ),
      );
    }

    final yetToBat = batting.playerIds
        .where((id) => !appeared.contains(id))
        .toList(growable: false);

    final bowlers = <TeamScorecardBowlerRow>[];
    final bowlerIds = <String>[];
    for (final event in innings.events) {
      if (!bowlerIds.contains(event.bowlerId)) bowlerIds.add(event.bowlerId);
    }
    for (final id in bowlerIds) {
      final events = innings.events.where((event) => event.bowlerId == id).toList();
      if (events.isEmpty || !bowling.playerIds.contains(id)) continue;
      final value = stat(bowling.id, id);
      bowlers.add(
        TeamScorecardBowlerRow(
          playerId: id,
          legalBalls: value.ballsBowled,
          maidens: _maidens(match, innings, id),
          runs: value.runsConceded,
          wickets: value.wickets,
          noBalls: value.noBalls,
          wides: value.wides,
          ballsPerOver: match.rules.ballsPerOver,
        ),
      );
    }

    var byes = 0;
    var legByes = 0;
    var wides = 0;
    var noBalls = 0;
    var penalties = 0;
    for (final event in innings.events) {
      switch (event.extraType) {
        case ExtraType.bye:
          byes += event.extraRuns;
          break;
        case ExtraType.legBye:
          legByes += event.extraRuns;
          break;
        case ExtraType.wide:
          wides += event.extraRuns;
          break;
        case ExtraType.noBall:
          noBalls += event.extraRuns;
          break;
        case ExtraType.penalty:
          penalties += event.extraRuns;
          break;
        case ExtraType.none:
          break;
      }
    }

    return TeamScorecardData(
      batters: batters,
      yetToBat: yetToBat,
      bowlers: bowlers,
      falls: _falls(match, innings),
      partnerships: _partnerships(match, innings),
      total: TeamScoringEngine.total(innings),
      wickets: TeamScoringEngine.wickets(innings),
      legalBalls: TeamScoringEngine.legalBalls(innings),
      extras: TeamScoringEngine.extras(innings),
      byes: byes,
      legByes: legByes,
      wides: wides,
      noBalls: noBalls,
      penalties: penalties,
      ballsPerOver: match.rules.ballsPerOver,
    );
  }

  static TeamScorecardDismissal _dismissalFor(
    TeamInnings innings,
    String playerId,
  ) {
    for (final event in innings.events.reversed) {
      if (event.isWicket && event.dismissedPlayerId == playerId) {
        return TeamScorecardDismissal(
          type: event.dismissalType,
          bowlerId: event.bowlerId,
          fielderIds: List<String>.from(event.fielderIds),
          isOut: true,
        );
      }
    }
    return const TeamScorecardDismissal(type: DismissalType.none);
  }

  static int _maidens(
    TeamMatch match,
    TeamInnings innings,
    String bowlerId,
  ) {
    final overRuns = <int, int>{};
    final overBalls = <int, int>{};
    var legalSeen = 0;
    for (final event in innings.events) {
      final over = legalSeen ~/ match.rules.ballsPerOver;
      if (event.bowlerId == bowlerId) {
        final excluded = event.extraType == ExtraType.bye ||
            event.extraType == ExtraType.legBye ||
            event.extraType == ExtraType.penalty;
        final conceded = excluded ? event.batRuns : event.totalRuns;
        overRuns[over] = (overRuns[over] ?? 0) + conceded;
        if (event.legalBall) overBalls[over] = (overBalls[over] ?? 0) + 1;
      }
      if (event.legalBall) legalSeen++;
    }
    var maidens = 0;
    for (final entry in overBalls.entries) {
      if (entry.value == match.rules.ballsPerOver &&
          (overRuns[entry.key] ?? 0) == 0) {
        maidens++;
      }
    }
    return maidens;
  }

  static List<TeamScorecardFall> _falls(
    TeamMatch match,
    TeamInnings innings,
  ) {
    final result = <TeamScorecardFall>[];
    var score = 0;
    var legalBalls = 0;
    var wickets = 0;
    for (final event in innings.events) {
      score += event.totalRuns;
      if (event.legalBall) legalBalls++;
      if (!event.isWicket || event.dismissedPlayerId == null) continue;
      wickets++;
      result.add(
        TeamScorecardFall(
          playerId: event.dismissedPlayerId!,
          score: score,
          wicketNumber: wickets,
          legalBalls: legalBalls,
          ballsPerOver: match.rules.ballsPerOver,
        ),
      );
    }
    return result;
  }

  static List<TeamScorecardPartnership> _partnerships(
    TeamMatch match,
    TeamInnings innings,
  ) {
    final result = <TeamScorecardPartnership>[];
    List<String>? currentPlayers;
    var runs = 0;
    var balls = 0;
    var runsByPlayer = <String, int>{};
    var ballsByPlayer = <String, int>{};

    void flush() {
      if (currentPlayers == null || currentPlayers!.isEmpty) return;
      if (runs == 0 && balls == 0 && runsByPlayer.isEmpty) return;
      result.add(
        TeamScorecardPartnership(
          playerIds: List<String>.from(currentPlayers!),
          runs: runs,
          balls: balls,
          runsByPlayer: Map<String, int>.from(runsByPlayer),
          ballsByPlayer: Map<String, int>.from(ballsByPlayer),
        ),
      );
      runs = 0;
      balls = 0;
      runsByPlayer = <String, int>{};
      ballsByPlayer = <String, int>{};
    }

    for (final event in innings.events) {
      final eventPlayers = <String>[
        event.strikerId,
        if (event.nonStrikerId != null) event.nonStrikerId!,
      ];
      final changed = currentPlayers == null ||
          currentPlayers!.length != eventPlayers.length ||
          !currentPlayers!.every(eventPlayers.contains);
      if (changed) {
        flush();
        currentPlayers = eventPlayers;
      }

      runs += event.totalRuns;
      if (event.legalBall) {
        balls++;
        ballsByPlayer[event.strikerId] =
            (ballsByPlayer[event.strikerId] ?? 0) + 1;
      }
      runsByPlayer[event.strikerId] =
          (runsByPlayer[event.strikerId] ?? 0) + event.batRuns;

      if (event.isWicket) {
        flush();
        currentPlayers = null;
      }
    }
    flush();
    return result;
  }
}
