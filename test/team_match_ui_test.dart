import 'package:crixx/data/app_store.dart';
import 'package:crixx/domain/enums.dart';
import 'package:crixx/domain/player.dart';
import 'package:crixx/domain/team_match.dart';
import 'package:crixx/domain/team_scoring_engine.dart';
import 'package:crixx/screens/create_team_match_screen.dart';
import 'package:crixx/screens/team_live_match_screen.dart';
import 'package:crixx/screens/team_toss_screen.dart';
import 'package:crixx/theme/app_theme.dart';
import 'package:crixx/widgets/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TeamStore extends AppStore {
  TeamMatch? created;

  @override
  Player? playerById(String? id) =>
      players.where((p) => p.id == id).firstOrNull;

  @override
  Future<TeamMatch> createTeamMatch({
    required String title,
    required TeamSide teamA,
    required TeamSide teamB,
    required TeamMatchRules rules,
    String? commonJokerPlayerId,
    String? trackerPlayerId,
    String? previousMatchId,
    bool isPractice = false,
  }) async {
    final match = TeamMatch(
      id: 'created',
      title: title,
      creatorPlayerId: activePlayerId!,
      teamA: teamA,
      teamB: teamB,
      rules: rules,
      createdAt: DateTime(2026),
      commonJokerPlayerId: commonJokerPlayerId,
      trackerPlayerId: trackerPlayerId,
      isPractice: isPractice,
    );
    TeamScoringEngine.validateSetup(match);
    created = match;
    teamMatches.add(match);
    notifyListeners();
    return match;
  }

  @override
  Future<void> startTeamMatchAfterToss(
    String matchId, {
    required TeamToss toss,
    required String openingBowlerId,
    String? openingStrikerId,
    String? openingNonStrikerId,
  }) async {
    final match = teamMatchById(matchId)!..toss = toss;
    TeamScoringEngine.startFirstInnings(
      match,
      openingBowlerId: openingBowlerId,
      openingStrikerId: openingStrikerId,
      openingNonStrikerId: openingNonStrikerId,
    );
    notifyListeners();
  }

  @override
  Future<void> recordTeamDelivery(
    String matchId, {
    required int batRuns,
    int extraRuns = 0,
    int? runningRuns,
    ExtraType extraType = ExtraType.none,
    bool isWicket = false,
    DismissalType dismissalType = DismissalType.none,
    String? dismissedPlayerId,
    List<String> fielderIds = const [],
  }) async {
    TeamScoringEngine.recordDelivery(
      teamMatchById(matchId)!,
      eventId: 'wicket',
      batRuns: batRuns,
      extraRuns: extraRuns,
      runningRuns: runningRuns,
      extraType: extraType,
      isWicket: isWicket,
      dismissalType: dismissalType,
      dismissedPlayerId: dismissedPlayerId,
      fielderIds: fielderIds,
    );
    notifyListeners();
  }

  @override
  Future<void> selectTeamNextBatter(String matchId, String playerId) async {
    final match = teamMatchById(matchId)!;
    TeamScoringEngine.selectNextBatter(match, match.currentInnings!, playerId);
    notifyListeners();
  }

  @override
  Future<void> swapTeamBatters(String matchId) async {
    final match = teamMatchById(matchId)!;
    TeamScoringEngine.swapBatters(match, match.currentInnings!);
    notifyListeners();
  }

  @override
  Future<void> replaceTeamBatter(
    String matchId, {
    required bool replaceStriker,
    required String playerId,
  }) async {
    final match = teamMatchById(matchId)!;
    TeamScoringEngine.replaceBatter(
      match,
      match.currentInnings!,
      replaceStriker: replaceStriker,
      playerId: playerId,
    );
    notifyListeners();
  }

  @override
  Future<void> addPlayerToLiveTeamMatch(
    String matchId, {
    required String teamId,
    required String playerId,
  }) async {
    final match = teamMatchById(matchId)!;
    final side = match.side(teamId);
    side.playerIds.add(playerId);
    side.battingOrder.add(playerId);
    notifyListeners();
  }

  @override
  Future<Player> createPlayerForLiveTeamMatch(
    String matchId, {
    required String teamId,
    required String name,
  }) async {
    final player = Player(
      id: 'live-player',
      name: name,
      avatarColor: 0xFF19C37D,
      createdAt: DateTime(2026),
    );
    players.add(player);
    final side = teamMatchById(matchId)!.side(teamId);
    side.playerIds.add(player.id);
    side.battingOrder.add(player.id);
    notifyListeners();
    return player;
  }
}

_TeamStore _store() {
  final store = _TeamStore()..activePlayerId = 'a1';
  for (final id in ['a1', 'a2', 'a3', 'b1', 'b2', 'b3', 'joker']) {
    store.players.add(
      Player(
        id: id,
        name: id,
        avatarColor: 0xFF19C37D,
        createdAt: DateTime(2026),
      ),
    );
  }
  return store;
}

TeamMatch _match() => TeamMatch(
  id: 'match',
  title: 'Team UI regression',
  creatorPlayerId: 'a1',
  teamA: TeamSide(
    id: 'A',
    name: 'Team A',
    colorValue: 0xFF19C37D,
    playerIds: ['a1', 'a2', 'a3'],
  ),
  teamB: TeamSide(
    id: 'B',
    name: 'Team B',
    colorValue: 0xFF7C5CFC,
    playerIds: ['b1', 'b2', 'b3'],
  ),
  rules: const TeamMatchRules(ballLimit: 30),
  createdAt: DateTime(2026),
);

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Finder _dropdown(String label) => find.byWidgetPredicate(
  (w) => w is DropdownButtonFormField && w.decoration.labelText == label,
);

Future<void> _visible(
  WidgetTester tester,
  Finder finder, {
  bool sheet = false,
}) async {
  if (finder.evaluate().isNotEmpty)
    await tester.ensureVisible(finder);
  else {
    final list = find.byKey(const ValueKey('team-match-setup-scroll'));
    final liveList = find.byKey(const ValueKey('team-live-match-scroll'));
    final scrollable = liveList.evaluate().isNotEmpty ? liveList : list;
    for (var attempt = 0; attempt < 6 && finder.evaluate().isEmpty; attempt++) {
      await tester.drag(scrollable, const Offset(0, 240));
      await tester.pumpAndSettle();
    }
    for (
      var attempt = 0;
      attempt < 12 && finder.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(scrollable, const Offset(0, -240));
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isNotEmpty) await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester,
  String label,
  String value, {
  bool sheet = false,
}) async {
  final field = _dropdown(label);
  await _visible(tester, field, sheet: sheet);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, _TeamStore store, Widget screen) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: MaterialApp(theme: buildAppTheme(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one-page setup assigns teams and optional bowling rules at 320px',
    (tester) async {
      final store = _store();
      await _pump(tester, store, const CreateTeamMatchScreen());
      expect(find.byType(Stepper), findsNothing);
      await _visible(tester, find.text('Shared Joker'));
      await tester.tap(find.text('Shared Joker'));
      await tester.pumpAndSettle();
      for (final assignment in [
        ('a1', 'A'),
        ('a2', 'A'),
        ('b1', 'B'),
        ('b2', 'B'),
        ('joker', 'J'),
      ]) {
        await _visible(tester, _field('Search players'));
        await tester.enterText(_field('Search players'), assignment.$1);
        await tester.pumpAndSettle();
        final chip = find.byKey(
          ValueKey('assign-${assignment.$1}-${assignment.$2}'),
        );
        await _visible(tester, chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await _visible(tester, find.text('Limit overs per bowler'));
      final limitSwitch = find.ancestor(
        of: find.text('Limit overs per bowler'),
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(limitSwitch).value, isFalse);
      await tester.tap(find.text('Limit overs per bowler'));
      await tester.pumpAndSettle();
      await _visible(tester, find.text('Allow an extra over'));
      await tester.tap(find.text('Allow an extra over'));
      await tester.pumpAndSettle();
      await _visible(tester, _field('How many bowlers per team?'));
      await tester.enterText(_field('How many bowlers per team?'), '1');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Continue to toss • 3 vs 3'));
      await tester.pumpAndSettle();
      expect(store.created, isNotNull);
      expect(store.created!.teamA.playerIds, ['a1', 'a2', 'joker']);
      expect(store.created!.teamB.playerIds, ['b1', 'b2', 'joker']);
      expect(store.created!.rules.maxOversPerBowler, 2);
      expect(store.created!.rules.extraOverBowlerCount, 1);
      expect(store.created!.teamA.bowlingQuotaBalls, isEmpty);
      expect(store.created!.teamB.bowlingQuotaBalls, isEmpty);
      expect(find.byType(TeamTossScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('toss requires deliberately chosen opening pair and bowler', (
    tester,
  ) async {
    final store = _store();
    final match = _match();
    store.teamMatches.add(match);
    await _pump(tester, store, const TeamTossScreen(matchId: 'match'));
    await _visible(tester, find.text('Record a real toss'));
    await tester.tap(find.text('Record a real toss'));
    await tester.pumpAndSettle();
    await _choose(tester, 'Toss winner', 'Team A');
    final start = find.widgetWithText(FilledButton, 'Start • Team A batting');
    await _visible(tester, start);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(_dropdown('Team A striker'))
          .initialValue,
      isNull,
    );
    await _choose(tester, 'Team A striker', 'a3');
    await _choose(tester, 'Team A non-striker', 'a1');
    await _choose(tester, 'Team B opening bowler', 'b2');
    await _visible(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(match.currentInnings!.strikerId, 'a3');
    expect(match.currentInnings!.nonStrikerId, 'a1');
    expect(
      TeamScoringEngine.currentBowlerId(match, match.currentInnings!),
      'b2',
    );
    expect(tester.takeException(), isNull);
  });

  for (final extra in [ExtraType.none, ExtraType.wide, ExtraType.noBall]) {
    testWidgets(
      'run-out with two completed runs and ${extra.name} is one delivery',
      (tester) async {
        final store = _store();
        final match =
            _match()
              ..toss = TeamToss(
                createdAt: DateTime(2026),
                mode: TeamTossMode.skipped,
                firstBattingTeamId: 'A',
              );
        TeamScoringEngine.startFirstInnings(
          match,
          openingBowlerId: 'b1',
          openingStrikerId: 'a1',
          openingNonStrikerId: 'a2',
        );
        store.teamMatches.add(match);
        await _pump(tester, store, const TeamLiveMatchScreen(matchId: 'match'));
        await _visible(tester, find.text('Wicket'));
        await tester.tap(find.text('Wicket'));
        await tester.pumpAndSettle();
        await _choose(tester, 'Dismissal', 'Run out (direct)', sheet: true);
        await _choose(tester, 'Batter out', 'a2', sheet: true);
        await _visible(
          tester,
          find.byTooltip('Add completed run'),
          sheet: true,
        );
        await tester.tap(find.byTooltip('Add completed run'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add completed run'));
        await tester.pumpAndSettle();
        if (extra != ExtraType.none)
          await _choose(
            tester,
            'Extra on this ball',
            extra == ExtraType.wide ? 'Wide' : 'No-ball',
            sheet: true,
          );
        await _choose(tester, 'Fielder / keeper', 'b2', sheet: true);
        final record = find.widgetWithText(FilledButton, 'Record wicket');
        await _visible(tester, record, sheet: true);
        await tester.tap(record);
        await tester.pumpAndSettle();
        final event = match.currentInnings!.events.single;
        expect(event.runningRuns, 2);
        expect(event.batRuns, extra == ExtraType.wide ? 0 : 2);
        expect(
          event.extraRuns,
          extra == ExtraType.wide
              ? 3
              : extra == ExtraType.noBall
              ? 1
              : 0,
        );
        expect(event.extraType, extra);
        expect(event.legalBall, extra == ExtraType.none);
        expect(event.isWicket, isTrue);
        expect(event.dismissedPlayerId, 'a2');
        expect(event.fielderIds, ['b2']);
        await tester.tap(find.text('a3').last);
        await tester.pumpAndSettle();
        expect(match.currentInnings!.strikerId, 'a1');
        expect(match.currentInnings!.nonStrikerId, 'a3');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('live match exposes over scorecard and batter controls', (
    tester,
  ) async {
    final store = _store();
    final match =
        _match()
          ..toss = TeamToss(
            createdAt: DateTime(2026),
            mode: TeamTossMode.skipped,
            firstBattingTeamId: 'A',
          );
    TeamScoringEngine.startFirstInnings(
      match,
      openingBowlerId: 'b1',
      openingStrikerId: 'a1',
      openingNonStrikerId: 'a2',
    );
    store.teamMatches.add(match);
    await _pump(tester, store, const TeamLiveMatchScreen(matchId: 'match'));

    expect(find.text('Live scorecard'), findsOneWidget);
    expect(find.text('Recent balls • over by over'), findsOneWidget);
    await _visible(tester, find.text('Swap ends'));
    await _visible(tester, find.text('Change batter'));

    await tester.tap(find.text('Swap ends'));
    await tester.pumpAndSettle();
    expect(match.currentInnings!.strikerId, 'a2');
    expect(match.currentInnings!.nonStrikerId, 'a1');

    await tester.tap(find.text('Change batter'));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('a3'), sheet: true);
    await tester.tap(find.text('a3').last);
    await tester.pumpAndSettle();
    expect(match.currentInnings!.strikerId, 'a3');
    expect(match.currentInnings!.nonStrikerId, 'a1');
    expect(
      TeamScoringEngine.availableNextBatters(match, match.currentInnings!),
      ['a2'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live scorer can add an existing player to a team', (
    tester,
  ) async {
    final store = _store();
    final match = _match()
      ..toss = TeamToss(
        createdAt: DateTime(2026),
        mode: TeamTossMode.skipped,
        firstBattingTeamId: 'A',
      );
    TeamScoringEngine.startFirstInnings(
      match,
      openingBowlerId: 'b1',
      openingStrikerId: 'a1',
      openingNonStrikerId: 'a2',
    );
    store.teamMatches.add(match);
    await _pump(tester, store, const TeamLiveMatchScreen(matchId: 'match'));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add players'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('joker').last);
    await tester.pumpAndSettle();

    expect(match.teamA.playerIds, contains('joker'));
    expect(match.teamA.battingOrder, contains('joker'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('live scorer can create and add a player offline', (tester) async {
    final store = _store();
    final match = _match()
      ..toss = TeamToss(
        createdAt: DateTime(2026),
        mode: TeamTossMode.skipped,
        firstBattingTeamId: 'A',
      );
    TeamScoringEngine.startFirstInnings(
      match,
      openingBowlerId: 'b1',
      openingStrikerId: 'a1',
      openingNonStrikerId: 'a2',
    );
    store.teamMatches.add(match);
    await _pump(tester, store, const TeamLiveMatchScreen(matchId: 'match'));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add players'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new player'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Player name'), 'Guest Batter');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create player'), findsNothing);
    expect(find.text('Add player to live match'), findsNothing);
    expect(match.teamA.playerIds, contains('live-player'));
    expect(store.playerById('live-player')?.name, 'Guest Batter');
    expect(tester.takeException(), isNull);
  });
}
