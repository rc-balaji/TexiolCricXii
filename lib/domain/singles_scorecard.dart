import 'cricket_match.dart';
import 'enums.dart';
import 'scoring_engine.dart';

class SinglesScorecardBatterRow {
  const SinglesScorecardBatterRow({
    required this.playerId,
    required this.dismissal,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.ballDataAvailable,
  });

  final String playerId;
  final SinglesScorecardDismissal dismissal;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool ballDataAvailable;

  double get strikeRate => balls == 0 ? 0 : runs * 100 / balls;
}

class SinglesScorecardDismissal {
  const SinglesScorecardDismissal({
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

class SinglesScorecardBowlerRow {
  const SinglesScorecardBowlerRow({
    required this.playerId,
    required this.legalBalls,
    required this.runs,
    required this.wickets,
    required this.noBalls,
    required this.wides,
    required this.ballsPerOver,
  });

  final String playerId;
  final int legalBalls;
  final int runs;
  final int wickets;
  final int noBalls;
  final int wides;
  final int ballsPerOver;

  String get overs => '${legalBalls ~/ ballsPerOver}.${legalBalls % ballsPerOver}';
  double get economy =>
      legalBalls == 0 ? 0 : runs * ballsPerOver / legalBalls;
}

class SinglesScorecardData {
  const SinglesScorecardData({
    required this.batters,
    required this.bowlers,
    required this.extras,
    required this.byes,
    required this.legByes,
    required this.wides,
    required this.noBalls,
    required this.penalties,
    required this.aggregateRuns,
  });

  final List<SinglesScorecardBatterRow> batters;
  final List<SinglesScorecardBowlerRow> bowlers;
  final int extras;
  final int byes;
  final int legByes;
  final int wides;
  final int noBalls;
  final int penalties;
  final int aggregateRuns;

  String get extrasBreakdown =>
      'b $byes, lb $legByes, w $wides, nb $noBalls, p $penalties';
}

class SinglesScorecardBuilder {
  const SinglesScorecardBuilder._();

  static SinglesScorecardData build(CricketMatch match) {
    final stats = ScoringEngine.calculateStats(match);
    final batters = <SinglesScorecardBatterRow>[];
    for (final id in match.battingOrder) {
      final playerStats = stats[id] ?? PlayerMatchStats(playerId: id);
      final events = match.events.where((event) => event.batterId == id).toList();
      var fours = 0;
      var sixes = 0;
      for (final event in events) {
        if (event.batRuns == 4) fours++;
        if (event.batRuns == 6) sixes++;
      }
      ScoreEvent? dismissalEvent;
      for (final event in events.reversed) {
        if (event.isOut) {
          dismissalEvent = event;
          break;
        }
      }
      batters.add(
        SinglesScorecardBatterRow(
          playerId: id,
          dismissal: dismissalEvent == null
              ? const SinglesScorecardDismissal(type: DismissalType.none)
              : SinglesScorecardDismissal(
                  type: dismissalEvent.dismissalType,
                  bowlerId: dismissalEvent.bowlerId,
                  fielderIds: List<String>.from(dismissalEvent.fielderIds),
                  isOut: true,
                ),
          runs: playerStats.runs,
          balls: playerStats.balls,
          fours: fours,
          sixes: sixes,
          ballDataAvailable: match.scoringMode == ScoringMode.ballByBall,
        ),
      );
    }

    final bowlerValues = <String, _SinglesBowlerAccumulator>{};
    var byes = 0;
    var legByes = 0;
    var wides = 0;
    var noBalls = 0;
    var penalties = 0;
    for (final event in match.events) {
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
      if (event.bowlerId == null) continue;
      final value = bowlerValues.putIfAbsent(
        event.bowlerId!,
        _SinglesBowlerAccumulator.new,
      );
      if (event.legalBall && event.type == ScoreEventType.delivery) {
        value.legalBalls++;
      }
      final excluded = event.extraType == ExtraType.bye ||
          event.extraType == ExtraType.legBye ||
          event.extraType == ExtraType.penalty;
      value.runs += excluded ? event.batRuns : event.batRuns + event.extraRuns;
      if (event.isOut && event.dismissalType.creditsBowler) value.wickets++;
      if (event.extraType == ExtraType.noBall) value.noBalls += event.extraRuns;
      if (event.extraType == ExtraType.wide) value.wides += event.extraRuns;
    }

    const ballsPerOver = 6;
    final bowlers = bowlerValues.entries
        .map(
          (entry) => SinglesScorecardBowlerRow(
            playerId: entry.key,
            legalBalls: entry.value.legalBalls,
            runs: entry.value.runs,
            wickets: entry.value.wickets,
            noBalls: entry.value.noBalls,
            wides: entry.value.wides,
            ballsPerOver: ballsPerOver,
          ),
        )
        .toList(growable: false);

    final extras = byes + legByes + wides + noBalls + penalties;
    final aggregateRuns = stats.values.fold<int>(0, (sum, value) => sum + value.runs);
    return SinglesScorecardData(
      batters: batters,
      bowlers: bowlers,
      extras: extras,
      byes: byes,
      legByes: legByes,
      wides: wides,
      noBalls: noBalls,
      penalties: penalties,
      aggregateRuns: aggregateRuns,
    );
  }
}

class _SinglesBowlerAccumulator {
  int legalBalls = 0;
  int runs = 0;
  int wickets = 0;
  int noBalls = 0;
  int wides = 0;
}
