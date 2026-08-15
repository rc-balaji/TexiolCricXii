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
      expect(match.currentInnings!.awaitingNextBatter, isTrue);
      TeamScoringEngine.selectNextBatter(
        match,
        match.currentInnings!,
        'a3',
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

    test('wicket pauses scoring until the next batter is selected', () {
      final match = _match(
        teamAIds: const ['a1', 'a2', 'a3', 'a4'],
        teamBIds: const ['b1', 'b2', 'b3', 'b4'],
      );
      _start(match, openingBowler: 'b1');

      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'wicket-choice',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      final innings = match.currentInnings!;
      expect(innings.awaitingNextBatter, isTrue);
      expect(TeamScoringEngine.availableNextBatters(match, innings), containsAll(['a3', 'a4']));
      expect(
        () => TeamScoringEngine.recordDelivery(
          match,
          eventId: 'blocked-before-choice',
          batRuns: 1,
        ),
        throwsStateError,
      );

      TeamScoringEngine.selectNextBatter(match, innings, 'a4');
      expect(innings.awaitingNextBatter, isFalse);
      expect(innings.strikerId, 'a4');
      expect(innings.nextBatterByWicketSequence[1], 'a4');
      final restoredAfterChoice = TeamMatch.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(match.toJson())) as Map,
        ),
      );
      expect(
        restoredAfterChoice.currentInnings!.nextBatterByWicketSequence[1],
        'a4',
      );

      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'after-choice',
        batRuns: 0,
      );
      expect(TeamScoringEngine.undoLast(match), isTrue);
      expect(innings.awaitingNextBatter, isFalse);
      expect(innings.strikerId, 'a4');
      expect(innings.nextBatterByWicketSequence[1], 'a4');
    });

    test('repeated Super Overs stay available until a round has a winner', () {
      final match = _match(ballLimit: 1, ballsPerOver: 1);
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-a',
        batRuns: 1,
      );
      TeamScoringEngine.startSecondInnings(
        match,
        openingBowlerId: 'a1',
      );
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-b',
        batRuns: 1,
      );

      expect(match.status, TeamMatchStatus.tieBreak);
      expect(TeamScoringEngine.result(match).summary, contains('Super Over available'));

      final firstSuperOver = TeamScoringEngine.startSuperOver(
        match,
        battingTeamId: match.teamA.id,
        openingBowlerId: 'b1',
      );
      expect(firstSuperOver.isSuperOver, isTrue);
      expect(firstSuperOver.superOverNumber, 1);
      expect(firstSuperOver.ballLimitOverride, 1);
      expect(firstSuperOver.wicketLimitOverride, 2);
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so1-a',
        batRuns: 1,
      );
      expect(match.status, TeamMatchStatus.inningsBreak);

      final firstSuperOverChase = TeamScoringEngine.startSecondInnings(
        match,
        openingBowlerId: 'a1',
      );
      expect(firstSuperOverChase.isSuperOver, isTrue);
      expect(firstSuperOverChase.superOverNumber, 1);
      expect(firstSuperOverChase.wicketLimitOverride, 2);
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so1-b',
        batRuns: 1,
      );

      expect(match.status, TeamMatchStatus.tieBreak);
      expect(TeamScoringEngine.result(match).summary, contains('another Super Over available'));

      final secondSuperOver = TeamScoringEngine.startSuperOver(
        match,
        battingTeamId: match.teamB.id,
        openingBowlerId: 'a1',
      );
      expect(secondSuperOver.superOverNumber, 2);
      expect(TeamScoringEngine.superOverCount(match), 2);

      final restored = TeamMatch.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(match.toJson())) as Map,
        ),
      );
      expect(restored.status, TeamMatchStatus.live);
      expect(restored.innings.last.isSuperOver, isTrue);
      expect(restored.innings.last.superOverNumber, 2);
      expect(restored.innings.last.wicketLimitOverride, 2);
    });

    test('Super Over innings ends on the second wicket', () {
      final match = _match(
        ballLimit: 1,
        ballsPerOver: 6,
        quotaA: const {'a1': 6},
        quotaB: const {'b1': 6},
      );
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-a-dot',
        batRuns: 0,
      );
      expect(match.status, TeamMatchStatus.inningsBreak);
      TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-b-dot',
        batRuns: 0,
      );
      expect(match.status, TeamMatchStatus.tieBreak);

      final innings = TeamScoringEngine.startSuperOver(
        match,
        battingTeamId: match.teamA.id,
        openingBowlerId: 'b1',
      );
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so-w1',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      expect(innings.awaitingNextBatter, isTrue);
      TeamScoringEngine.selectNextBatter(match, innings, 'a3');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so-w2',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );

      expect(TeamScoringEngine.wickets(innings), 2);
      expect(innings.completed, isTrue);
      expect(match.status, TeamMatchStatus.inningsBreak);
    });

    test('appearance stats keep Super Over not-out bonus after a main-innings dismissal', () {
      final match = _match(ballLimit: 1, ballsPerOver: 1);
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-a-out',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'main-b-dot-stats',
        batRuns: 0,
      );
      expect(match.status, TeamMatchStatus.tieBreak);

      TeamScoringEngine.startSuperOver(
        match,
        battingTeamId: match.teamA.id,
        openingBowlerId: 'b1',
      );
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so-a-not-out',
        batRuns: 0,
      );
      TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'so-b-dot-stats',
        batRuns: 0,
      );

      final stats = TeamScoringEngine.appearanceStats(match)['A:a1']!;
      expect(stats.dismissals, 1);
      expect(stats.dismissed, isTrue);
      expect(stats.points, match.rules.pointRules.notOutBonus);
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
