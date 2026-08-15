import 'dart:convert';

import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/team_match.dart';
import 'package:crixx/domain/team_scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CricXii Team Match scoring', () {
    test('supports team sizes above eleven with no hard cap', () {
      final a = List.generate(12, (index) => 'a$index');
      final b = List.generate(13, (index) => 'b$index');
      final match = _match(
        teamAIds: a,
        teamBIds: b,
        quotaA: {a.first: 6},
        quotaB: {b.first: 6},
      );

      expect(() => TeamScoringEngine.validateSetup(match), returnsNormally);
      expect(match.teamA.playerIds, hasLength(12));
      expect(match.teamB.playerIds, hasLength(13));
    });

    test('Last Player Standing keeps the same striker after odd runs', () {
      final match = _match(
        ballsPerOver: 2,
        teamAIds: const ['a1', 'a2', 'a3'],
        teamBIds: const ['b1', 'b2', 'b3'],
        quotaA: const {'a1': 2, 'a2': 4},
        quotaB: const {'b1': 2, 'b2': 4},
      );
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'w1',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'w2',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );

      final innings = match.currentInnings!;
      expect(innings.awaitingSoloDecision, isTrue);
      final finalBatter = innings.strikerId;
      TeamScoringEngine.decideLastPlayerStanding(match, continueSolo: true);
      TeamScoringEngine.selectBowler(match, innings, 'b2');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'solo-one',
        batRuns: 1,
      );

      expect(innings.soloMode, isTrue);
      expect(innings.strikerId, finalBatter);
      expect(innings.nonStrikerId, isNull);
    });

    test('disabled extras are rejected per type', () {
      final match = _match(wideEnabled: false);
      _start(match, openingBowler: 'b1');

      expect(
        () => TeamScoringEngine.recordDelivery(
          match,
          eventId: 'wide',
          batRuns: 0,
          extraRuns: 1,
          extraType: ExtraType.wide,
        ),
        throwsStateError,
      );
    });

    test('free hit survives an illegal wide and blocks bowler wicket', () {
      final match = _match(freeHitEnabled: true);
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'nb',
        batRuns: 0,
        extraRuns: 1,
        extraType: ExtraType.noBall,
      );
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'wd',
        batRuns: 0,
        extraRuns: 1,
        extraType: ExtraType.wide,
      );

      expect(
        TeamScoringEngine.isFreeHitDelivery(match, match.currentInnings!),
        isTrue,
      );
      expect(
        () => TeamScoringEngine.recordDelivery(
          match,
          eventId: 'illegal-wicket',
          batRuns: 0,
          isWicket: true,
          dismissalType: DismissalType.bowled,
        ),
        throwsStateError,
      );
    });

    test('shared Joker cannot bowl to themselves', () {
      final match = _match(
        teamAIds: const ['joker', 'a2', 'a3'],
        teamBIds: const ['joker', 'b2', 'b3'],
        jokerId: 'joker',
        quotaA: const {'joker': 6},
        quotaB: const {'joker': 6, 'b2': 6},
      );
      _start(match, openingBowler: 'b2');

      expect(
        () => TeamScoringEngine.selectBowler(
          match,
          match.currentInnings!,
          'joker',
        ),
        throwsStateError,
      );
    });

    test('skipped toss starts the explicitly selected batting team', () {
      final match = _match();
      match.toss = TeamToss(
        mode: TeamTossMode.skipped,
        firstBattingTeamId: match.teamB.id,
        createdAt: DateTime.utc(2026, 8, 15, 10),
      );

      TeamScoringEngine.startFirstInnings(
        match,
        openingBowlerId: 'a1',
      );

      expect(match.currentInnings!.battingTeamId, match.teamB.id);
      expect(match.currentInnings!.bowlingTeamId, match.teamA.id);
    });

    test('v1.3 toss JSON remains startable after the v1.4 upgrade', () {
      final match = _match();
      match.toss = TeamToss.fromJson({
        'callerTeamId': match.teamA.id,
        'call': TeamTossCall.heads.name,
        'result': TeamTossCall.tails.name,
        'winnerTeamId': match.teamB.id,
        'decision': TeamTossDecision.bowl.name,
        'createdAt': DateTime.utc(2026, 8, 15, 10).toIso8601String(),
      });

      TeamScoringEngine.startFirstInnings(
        match,
        openingBowlerId: 'b1',
      );

      expect(match.toss!.mode, TeamTossMode.inApp);
      expect(match.currentInnings!.battingTeamId, match.teamA.id);
    });

    test('timed toss winner must match the caller and coin result', () {
      final match = _match();
      match.toss = TeamToss(
        mode: TeamTossMode.inApp,
        tosserTeamId: match.teamB.id,
        callerTeamId: match.teamA.id,
        call: TeamTossCall.heads,
        result: TeamTossCall.heads,
        winnerTeamId: match.teamB.id,
        decision: TeamTossDecision.bat,
        firstBattingTeamId: match.teamB.id,
        createdAt: DateTime.utc(2026, 8, 15, 10),
      );

      expect(
        () => TeamScoringEngine.startFirstInnings(
          match,
          openingBowlerId: 'a1',
        ),
        throwsStateError,
      );
      expect(match.innings, isEmpty);
    });

    test('individual bowling quota is enforced at over selection', () {
      final match = _match(
        ballsPerOver: 2,
        allowConsecutiveOvers: true,
        quotaA: const {'a1': 2, 'a2': 4},
        quotaB: const {'b1': 2, 'b2': 4},
      );
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(match, eventId: 'b1', batRuns: 0);
      TeamScoringEngine.recordDelivery(match, eventId: 'b2', batRuns: 0);

      expect(
        () => TeamScoringEngine.selectBowler(
          match,
          match.currentInnings!,
          'b1',
        ),
        throwsStateError,
      );
      expect(
        () => TeamScoringEngine.selectBowler(
          match,
          match.currentInnings!,
          'b2',
        ),
        returnsNormally,
      );
    });

    test('completed result and full JSON round-trip are stable', () {
      final match = _match(ballLimit: 2, ballsPerOver: 2);
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(match, eventId: 'a-six', batRuns: 6);
      TeamScoringEngine.recordDelivery(match, eventId: 'a-dot', batRuns: 0);
      expect(match.status, TeamMatchStatus.inningsBreak);

      TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
      TeamScoringEngine.recordDelivery(match, eventId: 'b-one', batRuns: 1);
      TeamScoringEngine.recordDelivery(match, eventId: 'b-dot', batRuns: 0);

      expect(match.status, TeamMatchStatus.completed);
      expect(TeamScoringEngine.result(match).winnerTeamId, match.teamA.id);
      expect(TeamScoringEngine.result(match).marginRuns, 5);

      final restored = TeamMatch.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(match.toJson())) as Map),
      );
      expect(restored.id, match.id);
      expect(restored.innings, hasLength(2));
      expect(restored.innings.last.events, hasLength(2));
      expect(TeamScoringEngine.result(restored).summary, TeamScoringEngine.result(match).summary);
      expect(restored.seriesId, match.seriesId);
      expect(restored.seriesMatchNumber, 1);
      expect(restored.toss!.firstBattingTeamId, match.teamA.id);
    });

    test('aggregate points rank Player of Today and Series consistently', () {
      final first = _completedMatch(id: 'TXT-SERIES1');
      final second = _completedMatch(id: 'TXT-SERIES2');

      expect(TeamScoringEngine.topPlayerId([first, second]), 'a1');
      expect(
        TeamScoringEngine.pointsForPlayer([first, second], 'a1'),
        TeamScoringEngine.pointsForPlayer([first], 'a1') * 2,
      );
    });
  });
}

TeamMatch _match({
  String id = 'TXT-TEST01',
  int ballLimit = 6,
  int ballsPerOver = 6,
  bool wideEnabled = true,
  bool freeHitEnabled = false,
  bool allowConsecutiveOvers = false,
  List<String> teamAIds = const ['a1', 'a2', 'a3'],
  List<String> teamBIds = const ['b1', 'b2', 'b3'],
  Map<String, int>? quotaA,
  Map<String, int>? quotaB,
  String? jokerId,
}) {
  return TeamMatch(
    id: id,
    title: 'Team Engine Test',
    creatorPlayerId: teamAIds.first,
    teamA: TeamSide(
      id: 'A',
      name: 'Alpha',
      colorValue: 0xFF19C37D,
      playerIds: List<String>.from(teamAIds),
      bowlingQuotaBalls: quotaA ?? {teamAIds.first: ballLimit},
    ),
    teamB: TeamSide(
      id: 'B',
      name: 'Bravo',
      colorValue: 0xFF7C5CFC,
      playerIds: List<String>.from(teamBIds),
      bowlingQuotaBalls: quotaB ?? {teamBIds.first: ballLimit},
    ),
    rules: TeamMatchRules(
      ballLimit: ballLimit,
      ballsPerOver: ballsPerOver,
      wideEnabled: wideEnabled,
      freeHitEnabled: freeHitEnabled,
      allowConsecutiveOvers: allowConsecutiveOvers,
    ),
    createdAt: DateTime.utc(2026, 8, 15),
    commonJokerPlayerId: jokerId,
  );
}

void _start(TeamMatch match, {required String openingBowler}) {
  match.toss = TeamToss(
    mode: TeamTossMode.inApp,
    tosserTeamId: match.teamB.id,
    callerTeamId: match.teamA.id,
    call: TeamTossCall.heads,
    result: TeamTossCall.heads,
    winnerTeamId: match.teamA.id,
    decision: TeamTossDecision.bat,
    firstBattingTeamId: match.teamA.id,
    createdAt: DateTime.utc(2026, 8, 15, 10),
  );
  TeamScoringEngine.startFirstInnings(
    match,
    openingBowlerId: openingBowler,
    at: DateTime.utc(2026, 8, 15, 10),
  );
}

TeamMatch _completedMatch({required String id}) {
  final match = _match(id: id, ballLimit: 1, ballsPerOver: 1);
  _start(match, openingBowler: 'b1');
  TeamScoringEngine.recordDelivery(
    match,
    eventId: '$id-a',
    batRuns: 1,
  );
  TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
  TeamScoringEngine.recordDelivery(
    match,
    eventId: '$id-b',
    batRuns: 0,
  );
  return match;
}
