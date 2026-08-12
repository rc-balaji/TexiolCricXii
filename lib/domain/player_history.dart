import 'cricket_match.dart';
import 'enums.dart';
import 'player.dart';
import 'scoring_engine.dart';

class PlayerHistory {
  const PlayerHistory._();

  static List<CricketMatch> completedMatchesFor(
    String playerId,
    Iterable<CricketMatch> matches,
  ) {
    final result = matches
        .where(
          (match) =>
              match.status == MatchStatus.completed &&
              match.participantIds.contains(playerId),
        )
        .toList(growable: false);
    return result..sort((a, b) {
      final aDate = a.completedAt ?? a.createdAt;
      final bDate = b.completedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
  }

  static PlayerStats calculateSinglesCareer(
    String playerId,
    Iterable<CricketMatch> matches,
  ) {
    final total = PlayerStats();
    for (final match in completedMatchesFor(playerId, matches)) {
      final matchStats = ScoringEngine.calculateStats(match)[playerId];
      if (matchStats == null) continue;
      total
        ..matches += 1
        ..runs += matchStats.runs
        ..balls += matchStats.balls
        ..outs += matchStats.isOut ? 1 : 0
        ..wickets += matchStats.wickets
        ..catches += matchStats.catches
        ..directRunOuts += matchStats.directRunOuts
        ..assistedRunOuts += matchStats.assistedRunOuts
        ..stumpings += matchStats.stumpings
        ..points += matchStats.points;
      final rankings = ScoringEngine.rankings(match);
      if (rankings.isNotEmpty && rankings.first.playerId == playerId) {
        total.wins += 1;
      }
    }
    return total;
  }

  static void copyStats(PlayerStats target, PlayerStats source) {
    target
      ..matches = source.matches
      ..runs = source.runs
      ..balls = source.balls
      ..outs = source.outs
      ..wickets = source.wickets
      ..catches = source.catches
      ..directRunOuts = source.directRunOuts
      ..assistedRunOuts = source.assistedRunOuts
      ..stumpings = source.stumpings
      ..points = source.points
      ..wins = source.wins;
  }
}
