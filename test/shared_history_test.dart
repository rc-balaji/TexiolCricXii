import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player_history.dart';
import 'package:crixx/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('participant career includes completed matches created by other players', () {
    final first = _completedQuickMatch(
      id: 'TXM-FIRST',
      creator: 'p1',
      participants: const ['p1', 'p2'],
      totals: const [10, 15],
    );
    final second = _completedQuickMatch(
      id: 'TXM-SECOND',
      creator: 'p3',
      participants: const ['p2', 'p3'],
      totals: const [20, 5],
    );

    final history = PlayerHistory.completedMatchesFor('p2', [first, second]);
    final stats = PlayerHistory.calculateSinglesCareer('p2', history);

    expect(history.map((match) => match.id).toSet(), {'TXM-FIRST', 'TXM-SECOND'});
    expect(stats.matches, 2);
    expect(stats.runs, 35);
    expect(stats.wins, 2);
  });

  test('career excludes matches where the player did not participate', () {
    final own = _completedQuickMatch(
      id: 'TXM-OWN',
      creator: 'p1',
      participants: const ['p1', 'p2'],
      totals: const [9, 8],
    );
    final unrelated = _completedQuickMatch(
      id: 'TXM-OTHER',
      creator: 'p3',
      participants: const ['p3', 'p4'],
      totals: const [30, 29],
    );

    final stats = PlayerHistory.calculateSinglesCareer('p2', [own, unrelated]);
    expect(stats.matches, 1);
    expect(stats.runs, 8);
  });
}

CricketMatch _completedQuickMatch({
  required String id,
  required String creator,
  required List<String> participants,
  required List<int> totals,
}) {
  final match = CricketMatch(
    id: id,
    title: id,
    creatorPlayerId: creator,
    scoringMode: ScoringMode.quickTotal,
    ballLimit: 9,
    participantIds: List<String>.from(participants),
    battingOrder: List<String>.from(participants),
    createdAt: DateTime.utc(2026, 8, 12),
    status: MatchStatus.live,
  );
  for (var index = 0; index < participants.length; index++) {
    ScoringEngine.recordQuickTotal(
      match,
      eventId: '$id-$index',
      runs: totals[index],
    );
  }
  expect(match.status, MatchStatus.completed);
  match.completedAt = DateTime.utc(2026, 8, 12, 20, 30);
  return match;
}
