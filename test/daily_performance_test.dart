import 'package:crixx/domain/cricket_match.dart';
import 'package:crixx/domain/daily_performance.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/team_match.dart';
import 'package:crixx/domain/team_scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyPerformanceSummary', () {
    test('uses completedAt as the day boundary and ignores missing completion time', () {
      final date = DateTime(2026, 8, 15);
      final valid = _singles(
        id: 'S-valid',
        completedAt: DateTime(2026, 8, 15, 9),
      );
      final missingCompletedAt = _singles(id: 'S-missing');
      final yesterday = _singles(
        id: 'S-yesterday',
        completedAt: DateTime(2026, 8, 14, 23, 59),
      );

      final summary = DailyPerformanceSummary.build(
        date,
        [valid, missingCompletedAt, yesterday],
      );

      expect(summary.matches.map((match) => match.id), ['S-valid']);
      expect(summary.reportTitle, 'Today Singles Performance');
    });

    test('mixes selected Singles and Team matches and derives the report title', () {
      final date = DateTime(2026, 8, 15);
      final singles = _singles(
        id: 'S-today',
        completedAt: DateTime(2026, 8, 15, 8),
      );
      final team = _completedTeam(
        id: 'T-today',
        completedAt: DateTime(2026, 8, 15, 10),
      );

      final summary = DailyPerformanceSummary.build(date, [singles], [team]);
      expect(summary.matches, hasLength(2));
      expect(summary.singlesCount, 1);
      expect(summary.teamCount, 1);
      expect(summary.reportTitle, 'Today Overall Performance');

      final teamOnly = summary.selected({'team:${team.id}'});
      expect(teamOnly.matches, hasLength(1));
      expect(teamOnly.teamCount, 1);
      expect(teamOnly.reportTitle, 'Today Team Match Performance');

      final empty = summary.selected(const <String>{});
      expect(empty.matches, isEmpty);
      expect(empty.reportTitle, 'Today Performance');
    });
  });
}

CricketMatch _singles({required String id, DateTime? completedAt}) => CricketMatch(
      id: id,
      title: id,
      creatorPlayerId: 'p1',
      scoringMode: ScoringMode.quickTotal,
      ballLimit: 6,
      participantIds: const ['p1', 'p2'],
      battingOrder: const ['p1', 'p2'],
      createdAt: DateTime(2026, 8, 15, 7),
      startedAt: DateTime(2026, 8, 15, 7, 30),
      completedAt: completedAt,
      status: MatchStatus.completed,
    );

TeamMatch _completedTeam({required String id, required DateTime completedAt}) {
  final match = TeamMatch(
    id: id,
    title: id,
    creatorPlayerId: 'a1',
    teamA: TeamSide(
      id: 'A',
      name: 'Alpha',
      colorValue: 0xFF19C37D,
      playerIds: const ['a1', 'a2', 'a3'],
      bowlingQuotaBalls: const {'a1': 1},
    ),
    teamB: TeamSide(
      id: 'B',
      name: 'Bravo',
      colorValue: 0xFF7C5CFC,
      playerIds: const ['b1', 'b2', 'b3'],
      bowlingQuotaBalls: const {'b1': 1},
    ),
    rules: const TeamMatchRules(ballLimit: 1, ballsPerOver: 1),
    createdAt: DateTime(2026, 8, 15, 9),
  );
  match.toss = TeamToss(
    mode: TeamTossMode.skipped,
    firstBattingTeamId: match.teamA.id,
    createdAt: DateTime(2026, 8, 15, 9, 5),
  );
  TeamScoringEngine.startFirstInnings(
    match,
    openingBowlerId: 'b1',
    at: DateTime(2026, 8, 15, 9, 10),
  );
  TeamScoringEngine.recordDelivery(
    match,
    eventId: '$id-a',
    batRuns: 1,
    at: DateTime(2026, 8, 15, 9, 11),
  );
  TeamScoringEngine.startSecondInnings(
    match,
    openingBowlerId: 'a1',
    at: DateTime(2026, 8, 15, 9, 12),
  );
  TeamScoringEngine.recordDelivery(
    match,
    eventId: '$id-b',
    batRuns: 0,
    at: completedAt,
  );
  expect(match.status, TeamMatchStatus.completed);
  return match;
}
