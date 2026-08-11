import 'cricket_match.dart';
import 'enums.dart';
import 'scoring_engine.dart';

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
    required this.matchId,
    required this.title,
    required this.createdAt,
    required this.runs,
    required this.points,
    required this.wickets,
  });

  final String matchId;
  final String title;
  final DateTime createdAt;
  final int runs;
  final int points;
  final int wickets;
}

class DailyPerformanceSummary {
  DailyPerformanceSummary({required this.date, required this.matches});

  final DateTime date;
  final List<CricketMatch> matches;
  final Map<String, DailyPlayerPerformance> players =
      <String, DailyPlayerPerformance>{};
  int totalRuns = 0;
  int totalWickets = 0;
  int totalCatches = 0;
  int totalPoints = 0;

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

  static DailyPerformanceSummary build(
    DateTime date,
    Iterable<CricketMatch> source,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final dayMatches = source
        .where(
          (match) =>
              match.status == MatchStatus.completed &&
              !match.createdAt.isBefore(start) &&
              match.createdAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final summary = DailyPerformanceSummary(date: start, matches: dayMatches);

    for (final match in dayMatches) {
      final stats = ScoringEngine.calculateStats(match);
      final matchRankings = ScoringEngine.rankings(match);
      final winnerId = matchRankings.isEmpty ? null : matchRankings.first.playerId;
      for (final entry in stats.entries) {
        final value = entry.value;
        final aggregate = summary.players.putIfAbsent(
          entry.key,
          () => DailyPlayerPerformance(playerId: entry.key),
        );
        aggregate.matches += 1;
        aggregate.wins += winnerId == entry.key ? 1 : 0;
        aggregate.runs += value.runs;
        aggregate.balls += value.balls;
        aggregate.wickets += value.wickets;
        aggregate.catches += value.catches;
        aggregate.directRunOuts += value.directRunOuts;
        aggregate.assistedRunOuts += value.assistedRunOuts;
        aggregate.stumpings += value.stumpings;
        aggregate.points += value.points;
        if (value.points > aggregate.bestPoints) {
          aggregate.bestPoints = value.points;
        }
        aggregate.matchBreakdown.add(
          DailyMatchPerformance(
            matchId: match.id,
            title: match.title,
            createdAt: match.createdAt,
            runs: value.runs,
            points: value.points,
            wickets: value.wickets,
          ),
        );
        summary.totalRuns += value.runs;
        summary.totalWickets += value.wickets;
        summary.totalCatches += value.catches;
        summary.totalPoints += value.points;
      }
    }
    return summary;
  }
}
