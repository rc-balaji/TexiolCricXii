import 'dart:convert';

import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/team_match.dart';
import 'package:crixx/domain/team_scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CricXii Team Match scoring', () {
    test('undo seventh ball restores the striker after six dot balls', () {
      final match = _match(ballLimit: 12, allowConsecutiveOvers: true);
      _start(match, openingBowler: 'b1');
      _dots(match, 6);
      final innings = match.currentInnings!;
      expect(innings.strikerId, 'a2');
      TeamScoringEngine.selectBowler(match, innings, 'b1');
      TeamScoringEngine.recordDelivery(match, eventId: 'seventh', batRuns: 1);

      expect(TeamScoringEngine.undoLast(match), isTrue);
      expect(TeamScoringEngine.legalBalls(innings), 6);
      expect(innings.strikerId, 'a2');
      expect(innings.nonStrikerId, 'a1');
      expect(12 - TeamScoringEngine.legalBalls(innings), 6);
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'seventh-again',
        batRuns: 0,
      );
      expect(innings.events.last.strikerId, 'a2');
    });

    test('undo replays irregular runs, illegal balls and over-end wickets', () {
      final match = _match(
        ballLimit: 12,
        allowConsecutiveOvers: true,
        teamAIds: const ['a1', 'a2', 'a3', 'a4'],
      );
      _start(match, openingBowler: 'b1');
      TeamScoringEngine.recordDelivery(match, eventId: 'single', batRuns: 1);
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'wide',
        batRuns: 0,
        extraRuns: 1,
        extraType: ExtraType.wide,
      );
      _dots(match, 4);
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'sixth-wicket',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      final innings = match.currentInnings!;
      TeamScoringEngine.selectNextBatter(match, innings, 'a4');
      expect(innings.strikerId, 'a1');
      expect(innings.nonStrikerId, 'a4');
      TeamScoringEngine.selectBowler(match, innings, 'b1');
      TeamScoringEngine.recordDelivery(match, eventId: 'seventh', batRuns: 3);

      TeamScoringEngine.undoLast(match);
      expect(innings.strikerId, 'a1');
      expect(innings.nonStrikerId, 'a4');
      expect(innings.dismissedPlayerIds, ['a2']);
      expect(innings.awaitingNextBatter, isFalse);
      TeamScoringEngine.undoLast(match);
      expect(innings.strikerId, 'a2');
      expect(innings.nonStrikerId, 'a1');
      expect(innings.dismissedPlayerIds, isEmpty);
      expect(innings.nextBatterByWicketSequence, isEmpty);
      expect(innings.bowlerByOver.containsKey(1), isFalse);
    });

    test('chosen openers persist and undo returns to their original ends', () {
      final match = _match();
      match.toss = TeamToss(
        mode: TeamTossMode.skipped,
        firstBattingTeamId: 'A',
        createdAt: DateTime.utc(2026),
      );
      TeamScoringEngine.startFirstInnings(
        match,
        openingBowlerId: 'b1',
        openingStrikerId: 'a3',
        openingNonStrikerId: 'a1',
      );
      TeamScoringEngine.recordDelivery(match, eventId: 'single', batRuns: 1);
      final restored = _roundTrip(match);
      TeamScoringEngine.undoLast(restored);
      final innings = restored.currentInnings!;
      expect(innings.strikerId, 'a3');
      expect(innings.nonStrikerId, 'a1');
      expect(TeamScoringEngine.battingDisplayOrder(restored, innings), [
        'a3',
        'a1',
        'a2',
      ]);
      TeamScoringEngine.endInnings(restored);
      final chase = TeamScoringEngine.startSecondInnings(
        restored,
        openingBowlerId: 'a1',
        openingStrikerId: 'b2',
        openingNonStrikerId: 'b3',
      );
      expect(chase.strikerId, 'b2');
      expect(chase.nonStrikerId, 'b3');
    });

    test(
      'legacy innings infer original openers from first delivery on undo',
      () {
        final match = _match();
        _start(match, openingBowler: 'b1');
        TeamScoringEngine.recordDelivery(match, eventId: 'single', batRuns: 1);
        final json =
            jsonDecode(jsonEncode(match.toJson())) as Map<String, dynamic>;
        final inningsJson =
            (json['innings'] as List).first as Map<String, dynamic>;
        inningsJson.remove('openingStrikerId');
        inningsJson.remove('openingNonStrikerId');
        final restored = TeamMatch.fromJson(json);
        TeamScoringEngine.undoLast(restored);
        expect(restored.currentInnings!.strikerId, 'a1');
        expect(restored.currentInnings!.nonStrikerId, 'a2');
      },
    );

    test(
      'opening pair must be distinct teammates and excludes a batting Joker',
      () {
        final match = _match(
          teamAIds: const ['a1', 'a2', 'joker'],
          teamBIds: const ['b1', 'b2', 'joker'],
          jokerId: 'joker',
          quotaA: const {},
          quotaB: const {},
        );
        match.toss = TeamToss(
          mode: TeamTossMode.skipped,
          firstBattingTeamId: 'A',
          createdAt: DateTime.utc(2026),
        );
        expect(
          () => TeamScoringEngine.startFirstInnings(
            match,
            openingBowlerId: 'b1',
            openingStrikerId: 'a1',
            openingNonStrikerId: 'a1',
          ),
          throwsStateError,
        );
        expect(match.innings, isEmpty);
        expect(
          TeamScoringEngine.openingBowlerIds(
            match,
            battingTeamId: 'A',
            openingStrikerId: 'joker',
            openingNonStrikerId: 'a1',
          ),
          ['b1', 'b2'],
        );
      },
    );

    test('empty allocations let any teammate bowl without a cap', () {
      final match = _match(
        ballLimit: 18,
        allowConsecutiveOvers: true,
        quotaA: const {},
        quotaB: const {},
      );
      expect(() => TeamScoringEngine.validateSetup(match), returnsNormally);
      _start(match, openingBowler: 'b3');
      _dots(match, 6);
      TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b3');
      _dots(match, 6);
      TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b3');
      _dots(match, 6);
      expect(TeamScoringEngine.bowlerBalls(match.currentInnings!, 'b3'), 18);
    });

    test('common cap applies equally to every bowler and survives JSON', () {
      final match = _match(
        ballLimit: 24,
        allowConsecutiveOvers: true,
        maxOversPerBowler: 2,
        quotaA: const {},
        quotaB: const {},
      );
      TeamScoringEngine.validateSetup(match);
      _start(match, openingBowler: 'b3');
      _dots(match, 6);
      TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b3');
      _dots(match, 6);
      final restored = _roundTrip(match);
      final innings = restored.currentInnings!;
      expect(restored.rules.maxOversPerBowler, 2);
      expect(TeamScoringEngine.eligibleBowlers(restored, innings), [
        'b1',
        'b2',
      ]);
      expect(
        () => TeamScoringEngine.selectBowler(restored, innings, 'b3'),
        throwsStateError,
      );
    });

    test(
      'nine overs allow four bowlers at two overs and one live bonus over',
      () {
        final match = _match(
          ballLimit: 54,
          allowConsecutiveOvers: true,
          maxOversPerBowler: 2,
          extraOverBowlerCount: 1,
          teamAIds: const ['a1', 'a2', 'a3', 'a4'],
          teamBIds: const ['b1', 'b2', 'b3', 'b4'],
          quotaA: const {},
          quotaB: const {},
        );
        TeamScoringEngine.validateSetup(match);
        _start(match, openingBowler: 'b1');
        final innings = match.currentInnings!;
        for (final bowler in ['b1', 'b2', 'b3', 'b4']) {
          for (var over = 0; over < 2; over++) {
            TeamScoringEngine.selectBowler(match, innings, bowler);
            _dots(match, 6);
          }
        }
        expect(TeamScoringEngine.eligibleBowlers(match, innings), hasLength(4));
        TeamScoringEngine.selectBowler(match, innings, 'b4');
        TeamScoringEngine.recordDelivery(
          match,
          eventId: 'bonus-ball',
          batRuns: 0,
        );
        expect(TeamScoringEngine.extraOverBowlersUsed(match, innings), {'b4'});
        expect(TeamScoringEngine.bowlerLimitBalls(match, innings, 'b1'), 12);
        expect(TeamScoringEngine.bowlerLimitBalls(match, innings, 'b4'), 18);
        expect(
          () => TeamScoringEngine.selectBowler(match, innings, 'b2'),
          throwsStateError,
        );

        final restored = _roundTrip(match);
        expect(
          TeamScoringEngine.extraOverBowlersUsed(
            restored,
            restored.currentInnings!,
          ),
          {'b4'},
        );
        TeamScoringEngine.undoLast(match);
        expect(TeamScoringEngine.extraOverBowlersUsed(match, innings), isEmpty);
        TeamScoringEngine.selectBowler(match, innings, 'b2');
        _dots(match, 6);
        expect(innings.completed, isTrue);
        expect(TeamScoringEngine.extraOverBowlersUsed(match, innings), {'b2'});
      },
    );

    test('two bonus slots cannot be taken by a third bowler', () {
      final match = _match(
        ballLimit: 36,
        allowConsecutiveOvers: true,
        maxOversPerBowler: 1,
        extraOverBowlerCount: 2,
        teamAIds: const ['a1', 'a2', 'a3', 'a4'],
        teamBIds: const ['b1', 'b2', 'b3', 'b4'],
        quotaA: const {},
        quotaB: const {},
      );
      TeamScoringEngine.validateSetup(match);
      _start(match, openingBowler: 'b1');
      final innings = match.currentInnings!;
      for (final bowler in ['b1', 'b1', 'b2', 'b2', 'b3']) {
        TeamScoringEngine.selectBowler(match, innings, bowler);
        _dots(match, 6);
      }
      expect(TeamScoringEngine.extraOverBowlersUsed(match, innings), {
        'b1',
        'b2',
      });
      expect(TeamScoringEngine.eligibleBowlers(match, innings), ['b4']);
    });

    test(
      'an extra-over wide reserves its slot until that delivery is undone',
      () {
        final match = _match(
          ballLimit: 24,
          allowConsecutiveOvers: true,
          maxOversPerBowler: 1,
          extraOverBowlerCount: 1,
          quotaA: const {},
          quotaB: const {},
        );
        _start(match, openingBowler: 'b1');
        for (final bowler in ['b1', 'b2', 'b3']) {
          TeamScoringEngine.selectBowler(match, match.currentInnings!, bowler);
          _dots(match, 6);
        }
        TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b1');
        TeamScoringEngine.recordDelivery(
          match,
          eventId: 'extra-over-wide',
          batRuns: 0,
          extraRuns: 1,
          extraType: ExtraType.wide,
        );
        final restored = _roundTrip(match);
        final innings = restored.currentInnings!;
        expect(TeamScoringEngine.legalBalls(innings), 18);
        expect(TeamScoringEngine.extraOverBowlersUsed(restored, innings), {
          'b1',
        });
        expect(TeamScoringEngine.bowlerLimitBalls(restored, innings, 'b2'), 6);
        expect(
          TeamScoringEngine.canChangeCurrentBowler(restored, innings),
          isFalse,
        );
        expect(
          () => TeamScoringEngine.selectBowler(restored, innings, 'b2'),
          throwsStateError,
        );
        _dots(restored, 1);
        TeamScoringEngine.undoLast(restored);
        expect(TeamScoringEngine.extraOverBowlersUsed(restored, innings), {
          'b1',
        });
        TeamScoringEngine.undoLast(restored);
        expect(
          TeamScoringEngine.extraOverBowlersUsed(restored, innings),
          isEmpty,
        );
        expect(
          TeamScoringEngine.canChangeCurrentBowler(restored, innings),
          isTrue,
        );
        TeamScoringEngine.selectBowler(restored, innings, 'b2');
        _dots(restored, 6);
        expect(innings.completed, isTrue);
        expect(TeamScoringEngine.extraOverBowlersUsed(restored, innings), {
          'b2',
        });
      },
    );

    test(
      'common cap allows the shorter final over and renews in a Super Over',
      () {
        final match = _match(
          ballLimit: 8,
          allowConsecutiveOvers: true,
          maxOversPerBowler: 1,
          extraOverBowlerCount: 1,
          quotaA: const {},
          quotaB: const {},
        );
        TeamScoringEngine.validateSetup(match);
        _start(match, openingBowler: 'b1');
        _dots(match, 6);
        TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b1');
        _dots(match, 2);
        expect(match.currentInnings!.completed, isTrue);
        expect(TeamScoringEngine.bowlerBalls(match.currentInnings!, 'b1'), 8);
        TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
        _dots(match, 6);
        TeamScoringEngine.selectBowler(match, match.currentInnings!, 'a1');
        _dots(match, 2);
        expect(match.status, TeamMatchStatus.tieBreak);
        final superOver = TeamScoringEngine.startSuperOver(
          match,
          battingTeamId: 'A',
          openingBowlerId: 'b1',
          openingStrikerId: 'a3',
          openingNonStrikerId: 'a2',
        );
        expect(superOver.strikerId, 'a3');
        expect(
          TeamScoringEngine.extraOverBowlersUsed(match, superOver),
          isEmpty,
        );
        expect(TeamScoringEngine.bowlerLimitBalls(match, superOver, 'b1'), 6);
        _dots(match, 6);
        expect(superOver.completed, isTrue);
        expect(
          TeamScoringEngine.extraOverBowlersUsed(match, superOver),
          isEmpty,
        );
      },
    );

    test('setup rejects impossible and uneven no-consecutive schedules', () {
      final single = _match(ballLimit: 12);
      expect(() => TeamScoringEngine.validateSetup(single), throwsStateError);
      final uneven = _match(
        ballLimit: 24,
        quotaA: const {'a1': 18, 'a2': 6},
        quotaB: const {'b1': 18, 'b2': 6},
      );
      expect(() => TeamScoringEngine.validateSetup(uneven), throwsStateError);
      final feasible = _match(
        ballLimit: 30,
        quotaA: const {'a1': 18, 'a2': 12},
        quotaB: const {'b1': 18, 'b2': 12},
      );
      expect(() => TeamScoringEngine.validateSetup(feasible), returnsNormally);
      final fragments = _match(
        quotaA: const {'a1': 3, 'a2': 3},
        quotaB: const {'b1': 3, 'b2': 3},
      );
      expect(
        () => TeamScoringEngine.validateSetup(fragments),
        throwsStateError,
      );
    });

    test(
      'setup counts a shorter final over and the optional bonus capacity',
      () {
        final partial = _match(
          ballLimit: 14,
          quotaA: const {'a1': 8, 'a2': 6},
          quotaB: const {'b1': 8, 'b2': 6},
        );
        expect(() => TeamScoringEngine.validateSetup(partial), returnsNormally);
        final insufficient = _match(
          ballLimit: 54,
          maxOversPerBowler: 2,
          teamAIds: const ['a1', 'a2', 'a3', 'a4'],
          teamBIds: const ['b1', 'b2', 'b3', 'b4'],
          quotaA: const {},
          quotaB: const {},
        );
        expect(
          () => TeamScoringEngine.validateSetup(insufficient),
          throwsStateError,
        );
      },
    );

    test('old rules retain no-consecutive setting and existing quota maps', () {
      final rules = TeamMatchRules.fromJson({'ballLimit': 12});
      expect(rules.allowConsecutiveOvers, isFalse);
      expect(rules.maxOversPerBowler, isNull);
      expect(const TeamMatchRules(ballLimit: 12).allowConsecutiveOvers, isTrue);
      final match = _roundTrip(_match(quotaB: const {'b2': 6}));
      match.toss = TeamToss(
        mode: TeamTossMode.skipped,
        firstBattingTeamId: 'A',
        createdAt: DateTime.utc(2026),
      );
      expect(
        () => TeamScoringEngine.startFirstInnings(match, openingBowlerId: 'b1'),
        throwsStateError,
      );
      TeamScoringEngine.startFirstInnings(match, openingBowlerId: 'b2');
    });

    test(
      'run-out with completed runs and no-ball is one reversible delivery',
      () {
        final match = _match();
        _start(match, openingBowler: 'b1');
        TeamScoringEngine.recordDelivery(
          match,
          eventId: 'runout',
          batRuns: 1,
          extraRuns: 1,
          runningRuns: 1,
          extraType: ExtraType.noBall,
          isWicket: true,
          dismissalType: DismissalType.runOutDirect,
          dismissedPlayerId: 'a2',
          fielderIds: const ['b2'],
        );
        final innings = match.currentInnings!;
        expect(innings.events, hasLength(1));
        expect(TeamScoringEngine.total(innings), 2);
        expect(TeamScoringEngine.legalBalls(innings), 0);
        expect(innings.pendingNextBatterEnd, 'striker');
        expect(TeamScoringEngine.appearanceStats(match)['B:b1']!.wickets, 0);
        TeamScoringEngine.selectNextBatter(match, innings, 'a3');
        TeamScoringEngine.undoLast(match);
        expect(innings.strikerId, 'a1');
        expect(innings.nonStrikerId, 'a2');
        expect(innings.dismissedPlayerIds, isEmpty);
      },
    );

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
      TeamScoringEngine.selectNextBatter(match, match.currentInnings!, 'a3');
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
      TeamScoringEngine.recordDelivery(match, eventId: 'solo-one', batRuns: 1);

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
      expect(
        TeamScoringEngine.availableNextBatters(match, innings),
        containsAll(['a3', 'a4']),
      );
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
      TeamScoringEngine.recordDelivery(match, eventId: 'main-a', batRuns: 1);
      TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
      TeamScoringEngine.recordDelivery(match, eventId: 'main-b', batRuns: 1);

      expect(match.status, TeamMatchStatus.tieBreak);
      expect(
        TeamScoringEngine.result(match).summary,
        contains('Super Over available'),
      );

      final firstSuperOver = TeamScoringEngine.startSuperOver(
        match,
        battingTeamId: match.teamA.id,
        openingBowlerId: 'b1',
      );
      expect(firstSuperOver.isSuperOver, isTrue);
      expect(firstSuperOver.superOverNumber, 1);
      expect(firstSuperOver.ballLimitOverride, 1);
      expect(firstSuperOver.wicketLimitOverride, 2);
      TeamScoringEngine.recordDelivery(match, eventId: 'so1-a', batRuns: 1);
      expect(match.status, TeamMatchStatus.inningsBreak);

      final firstSuperOverChase = TeamScoringEngine.startSecondInnings(
        match,
        openingBowlerId: 'a1',
      );
      expect(firstSuperOverChase.isSuperOver, isTrue);
      expect(firstSuperOverChase.superOverNumber, 1);
      expect(firstSuperOverChase.wicketLimitOverride, 2);
      TeamScoringEngine.recordDelivery(match, eventId: 'so1-b', batRuns: 1);

      expect(match.status, TeamMatchStatus.tieBreak);
      expect(
        TeamScoringEngine.result(match).summary,
        contains('another Super Over available'),
      );

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

    test(
      'appearance stats keep Super Over not-out bonus after a main-innings dismissal',
      () {
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
      },
    );

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

    test('incoming Joker can hand their unfinished over to another bowler', () {
      final match = _match(
        teamAIds: const ['a1', 'a2', 'joker'],
        teamBIds: const ['b1', 'b2', 'joker'],
        jokerId: 'joker',
        quotaA: const {},
        quotaB: const {},
      );
      _start(match, openingBowler: 'joker');
      final innings = match.currentInnings!;
      TeamScoringEngine.recordDelivery(
        match,
        eventId: 'joker-wicket',
        batRuns: 0,
        isWicket: true,
        dismissalType: DismissalType.bowled,
      );
      TeamScoringEngine.selectNextBatter(match, innings, 'joker');
      expect(TeamScoringEngine.canChangeCurrentBowler(match, innings), isTrue);
      expect(
        () => TeamScoringEngine.recordDelivery(
          match,
          eventId: 'joker-self',
          batRuns: 0,
        ),
        throwsStateError,
      );
      TeamScoringEngine.selectBowler(match, innings, 'b1');
      _dots(match, 1);
      expect(innings.events.last.bowlerId, 'b1');
      expect(TeamScoringEngine.canChangeCurrentBowler(match, innings), isFalse);
      expect(
        () => TeamScoringEngine.selectBowler(match, innings, 'b2'),
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

      TeamScoringEngine.startFirstInnings(match, openingBowlerId: 'a1');

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

      TeamScoringEngine.startFirstInnings(match, openingBowlerId: 'b1');

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
        () => TeamScoringEngine.startFirstInnings(match, openingBowlerId: 'a1'),
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
        () =>
            TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b1'),
        throwsStateError,
      );
      expect(
        () =>
            TeamScoringEngine.selectBowler(match, match.currentInnings!, 'b2'),
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
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(match.toJson())) as Map,
        ),
      );
      expect(restored.id, match.id);
      expect(restored.innings, hasLength(2));
      expect(restored.innings.last.events, hasLength(2));
      expect(
        TeamScoringEngine.result(restored).summary,
        TeamScoringEngine.result(match).summary,
      );
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
  int? maxOversPerBowler,
  int extraOverBowlerCount = 0,
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
      maxOversPerBowler: maxOversPerBowler,
      extraOverBowlerCount: extraOverBowlerCount,
    ),
    createdAt: DateTime.utc(2026, 8, 15),
    commonJokerPlayerId: jokerId,
  );
}

void _dots(TeamMatch match, int count) {
  for (var i = 0; i < count; i++) {
    TeamScoringEngine.recordDelivery(
      match,
      eventId: 'dot-${match.currentInnings!.events.length}',
      batRuns: 0,
    );
  }
}

TeamMatch _roundTrip(TeamMatch match) => TeamMatch.fromJson(
  jsonDecode(jsonEncode(match.toJson())) as Map<String, dynamic>,
);

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
  TeamScoringEngine.recordDelivery(match, eventId: '$id-a', batRuns: 1);
  TeamScoringEngine.startSecondInnings(match, openingBowlerId: 'a1');
  TeamScoringEngine.recordDelivery(match, eventId: '$id-b', batRuns: 0);
  return match;
}
