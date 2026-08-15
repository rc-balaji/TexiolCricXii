import 'cricket_match.dart';
import 'enums.dart';
import 'scoring_engine.dart';
import 'team_match.dart';
import 'team_scoring_engine.dart';

enum DailyMatchType { singles, team }

class DailyMatchStanding {
  const DailyMatchStanding({
    required this.playerId,
    required this.runs,
    required this.balls,
    required this.wickets,
    required this.catches,
    required this.directRunOuts,
    required this.assistedRunOuts,
    required this.stumpings,
    required this.points,
  });

  final String playerId;
  final int runs;
  final int balls;
  final int wickets;
  final int catches;
  final int directRunOuts;
  final int assistedRunOuts;
  final int stumpings;
  final int points;
}

class DailyMatchEntry {
  const DailyMatchEntry({
    required this.type,
    required this.id,
    required this.title,
    required this.startedAt,
    required this.completedAt,
    required this.playerCount,
    required this.rankings,
    required this.resultLabel,
    this.singlesMatch,
    this.teamMatch,
  });

  final DailyMatchType type;
  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime completedAt;
  final int playerCount;
  final List<DailyMatchStanding> rankings;
  final String resultLabel;
  final CricketMatch? singlesMatch;
  final TeamMatch? teamMatch;

  String get key => '${type.name}:$id';
  bool get isSingles => type == DailyMatchType.singles;
  bool get isTeam => type == DailyMatchType.team;
}

class DailyPlayerPerformance {
  DailyPlayerPerformance({required this.playerId});

  final String playerId;
  int matches = 0;
  int wins = 0;
  int runs = 0;
  int balls = 0;
  int wickets = 0;
  int catches = 0;
  int directRunOuts = 0;
  int assistedRunOuts = 0;
  int stumpings = 0;
  int points = 0;
  int bestPoints = 0;
  final List<DailyMatchPerformance> matchBreakdown = <DailyMatchPerformance>[];

  double get averagePoints => matches == 0 ? 0 : points / matches;
}

class DailyMatchPerformance {
  const DailyMatchPerformance({
    required this.matchKey,
    required this.matchId,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.runs,
    required this.points,
    required this.wickets,
  });

  final String matchKey;
  final String matchId;
  final DailyMatchType type;
  final String title;
  final DateTime createdAt;
  final int runs;
  final int points;
  final int wickets;
}

class DailyPerformanceSummary {
  DailyPerformanceSummary({required this.date, required this.matches}) {
    _aggregate();
  }

  final DateTime date;
  final List<DailyMatchEntry> matches;
  final Map<String, DailyPlayerPerformance> players =
      <String, DailyPlayerPerformance>{};
  int totalRuns = 0;
  int totalWickets = 0;
  int totalCatches = 0;
  int totalPoints = 0;

  int get singlesCount =>
      matches.where((match) => match.type == DailyMatchType.singles).length;
  int get teamCount =>
      matches.where((match) => match.type == DailyMatchType.team).length;

  String get reportTitle {
    if (matches.isEmpty) return 'Today Performance';
    if (singlesCount > 0 && teamCount > 0) return 'Today Overall Performance';
    if (teamCount > 0) return 'Today Team Match Performance';
    return 'Today Singles Performance';
  }

  List<DailyPlayerPerformance> get rankings {
    final result = players.values.toList();
    result.sort((a, b) {
      final points = b.points.compareTo(a.points);
      if (points != 0) return points;
      final runs = b.runs.compareTo(a.runs);
      if (runs != 0) return runs;
      final wickets = b.wickets.compareTo(a.wickets);
      if (wickets != 0) return wickets;
      return a.playerId.compareTo(b.playerId);
    });
    return result;
  }

  DailyPerformanceSummary selected(Iterable<String> matchKeys) {
    final keys = matchKeys.toSet();
    return DailyPerformanceSummary(
      date: date,
      matches: matches.where((match) => keys.contains(match.key)).toList(),
    );
  }

  void _aggregate() {
    for (final match in matches) {
      final winnerIds = _winnerIds(match);
      for (final row in match.rankings) {
        final aggregate = players.putIfAbsent(
          row.playerId,
          () => DailyPlayerPerformance(playerId: row.playerId),
        );
        aggregate.matches += 1;
        aggregate.wins += winnerIds.contains(row.playerId) ? 1 : 0;
        aggregate.runs += row.runs;
        aggregate.balls += row.balls;
        aggregate.wickets += row.wickets;
        aggregate.catches += row.catches;
        aggregate.directRunOuts += row.directRunOuts;
        aggregate.assistedRunOuts += row.assistedRunOuts;
        aggregate.stumpings += row.stumpings;
        aggregate.points += row.points;
        if (row.points > aggregate.bestPoints) aggregate.bestPoints = row.points;
        aggregate.matchBreakdown.add(
          DailyMatchPerformance(
            matchKey: match.key,
            matchId: match.id,
            type: match.type,
            title: match.title,
            createdAt: match.completedAt,
            runs: row.runs,
            points: row.points,
            wickets: row.wickets,
          ),
        );
        totalRuns += row.runs;
        totalWickets += row.wickets;
        totalCatches += row.catches;
        totalPoints += row.points;
      }
    }
  }

  Set<String> _winnerIds(DailyMatchEntry entry) {
    if (entry.isSingles) {
      return entry.rankings.isEmpty ? <String>{} : {entry.rankings.first.playerId};
    }
    final match = entry.teamMatch;
    if (match == null) return <String>{};
    final winnerTeamId = TeamScoringEngine.result(match).winnerTeamId;
    if (winnerTeamId == null) return <String>{};
    return match
        .side(winnerTeamId)
        .playerIds
        .where((id) => id != match.commonJokerPlayerId)
        .toSet();
  }

  static DailyPerformanceSummary build(
    DateTime date,
    Iterable<CricketMatch> singlesSource, [
    Iterable<TeamMatch> teamSource = const <TeamMatch>[],
  ]) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    bool inDay(DateTime value) => !value.isBefore(start) && value.isBefore(end);

    final entries = <DailyMatchEntry>[];
    for (final match in singlesSource) {
      if (match.status != MatchStatus.completed) continue;
      final completedAt = match.completedAt;
      if (completedAt == null || !inDay(completedAt)) continue;
      final stats = ScoringEngine.calculateStats(match);
      final rankings = ScoringEngine.rankings(match)
          .map((ranked) {
            final value = stats[ranked.playerId]!;
            return DailyMatchStanding(
              playerId: ranked.playerId,
              runs: value.runs,
              balls: value.balls,
              wickets: value.wickets,
              catches: value.catches,
              directRunOuts: value.directRunOuts,
              assistedRunOuts: value.assistedRunOuts,
              stumpings: value.stumpings,
              points: value.points,
            );
          })
          .toList(growable: false);
      final winner = rankings.isEmpty ? null : rankings.first;
      entries.add(
        DailyMatchEntry(
          type: DailyMatchType.singles,
          id: match.id,
          title: match.title,
          startedAt: match.startedAt ?? match.createdAt,
          completedAt: completedAt,
          playerCount: match.participantIds.length,
          rankings: rankings,
          resultLabel: winner == null
              ? 'Completed Singles match'
              : '${winner.points} PTS • Singles winner',
          singlesMatch: match,
        ),
      );
    }

    for (final match in teamSource) {
      if (match.status != TeamMatchStatus.completed) continue;
      final completedAt = match.completedAt;
      if (completedAt == null || !inDay(completedAt)) continue;
      final combined = <String, TeamPlayerMatchStats>{};
      for (final value in TeamScoringEngine.appearanceStats(match).values) {
        final aggregate = combined.putIfAbsent(
          value.playerId,
          () => TeamPlayerMatchStats(playerId: value.playerId, teamId: value.teamId),
        );
        aggregate
          ..runs += value.runs
          ..balls += value.balls
          ..fours += value.fours
          ..sixes += value.sixes
          ..dismissed = aggregate.dismissed || value.dismissed
          ..dismissals += value.dismissals
          ..wickets += value.wickets
          ..ballsBowled += value.ballsBowled
          ..runsConceded += value.runsConceded
          ..maidens += value.maidens
          ..wides += value.wides
          ..noBalls += value.noBalls
          ..catches += value.catches
          ..directRunOuts += value.directRunOuts
          ..assistedRunOuts += value.assistedRunOuts
          ..stumpings += value.stumpings
          ..points += value.points;
      }
      final rankings = combined.values
          .map(
            (value) => DailyMatchStanding(
              playerId: value.playerId,
              runs: value.runs,
              balls: value.balls,
              wickets: value.wickets,
              catches: value.catches,
              directRunOuts: value.directRunOuts,
              assistedRunOuts: value.assistedRunOuts,
              stumpings: value.stumpings,
              points: value.points,
            ),
          )
          .toList();
      rankings.sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        final runs = b.runs.compareTo(a.runs);
        if (runs != 0) return runs;
        final wickets = b.wickets.compareTo(a.wickets);
        if (wickets != 0) return wickets;
        return a.playerId.compareTo(b.playerId);
      });
      entries.add(
        DailyMatchEntry(
          type: DailyMatchType.team,
          id: match.id,
          title: match.title,
          startedAt: match.startedAt ?? match.createdAt,
          completedAt: completedAt,
          playerCount: {
            ...match.teamA.playerIds,
            ...match.teamB.playerIds,
          }.length,
          rankings: rankings,
          resultLabel: TeamScoringEngine.result(match).summary,
          teamMatch: match,
        ),
      );
    }

    entries.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return DailyPerformanceSummary(date: start, matches: entries);
  }
}
