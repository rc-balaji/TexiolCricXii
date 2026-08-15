import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/team_match.dart';
import '../domain/team_scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import 'team_match_summary_screen.dart';
import 'team_match_watch_screen.dart';

class TeamLiveMatchScreen extends StatefulWidget {
  const TeamLiveMatchScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<TeamLiveMatchScreen> createState() => _TeamLiveMatchScreenState();
}

class _TeamLiveMatchScreenState extends State<TeamLiveMatchScreen> {
  bool _working = false;
  bool _soloDialogOpen = false;
  bool _bowlerSheetOpen = false;
  String? _breakBowlerId;

  String _message(Object error) =>
      '$error'.replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message(error))),
    );
  }

  Future<void> _record({
    required int batRuns,
    int extraRuns = 0,
    ExtraType extraType = ExtraType.none,
    bool isWicket = false,
    DismissalType dismissalType = DismissalType.none,
    String? dismissedPlayerId,
    List<String> fielderIds = const [],
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await AppScope.read(context).recordTeamDelivery(
        widget.matchId,
        batRuns: batRuns,
        extraRuns: extraRuns,
        extraType: extraType,
        isWicket: isWicket,
        dismissalType: dismissalType,
        dismissedPlayerId: dismissedPlayerId,
        fielderIds: fielderIds,
      );
      if (!mounted) return;
      await _afterMutation();
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _afterMutation() async {
    if (!mounted) return;
    final match = AppScope.read(context).teamMatchById(widget.matchId);
    if (match == null) return;
    if (match.status == TeamMatchStatus.completed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TeamMatchSummaryScreen(matchId: match.id),
        ),
      );
      return;
    }
    final innings = match.currentInnings;
    if (innings?.awaitingSoloDecision == true) {
      await _askLastPlayer(match);
      return;
    }
    if (match.status == TeamMatchStatus.live &&
        innings != null &&
        TeamScoringEngine.currentBowlerId(match, innings) == null) {
      await _chooseBowler(match);
    }
  }

  Future<void> _askLastPlayer(TeamMatch match) async {
    if (_soloDialogOpen || !mounted) return;
    _soloDialogOpen = true;
    final innings = match.currentInnings!;
    final batter = AppScope.read(context).playerById(innings.strikerId);
    final continueSolo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.person_rounded, size: 34),
          title: const Text('Last Player Standing'),
          content: Text(
            '${batter?.name ?? 'The final batter'} is the only batter left. '
            'Continue as a single player? Odd runs and over changes will not change the striker.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('End innings'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue solo'),
            ),
          ],
        ),
      ),
    );
    _soloDialogOpen = false;
    if (continueSolo == null || !mounted) return;
    try {
      await AppScope.read(context).decideTeamLastPlayer(
        match.id,
        continueSolo: continueSolo,
      );
      if (mounted) await _afterMutation();
    } on Object catch (error) {
      _showError(error);
    }
  }

  String? _bowlerBlockReason(
    TeamMatch match,
    TeamInnings innings,
    String playerId,
  ) {
    if (playerId == innings.strikerId || playerId == innings.nonStrikerId) {
      return 'Joker cannot bowl to self';
    }
    final over = TeamScoringEngine.currentOver(match, innings);
    if (!match.rules.allowConsecutiveOvers &&
        over > 0 &&
        innings.bowlerByOver[over - 1] == playerId) {
      return 'No consecutive overs';
    }
    final side = match.side(innings.bowlingTeamId);
    final used = TeamScoringEngine.bowlerBalls(innings, playerId);
    final quota = side.bowlingQuotaBalls[playerId] ?? 0;
    final remaining = match.rules.ballLimit - TeamScoringEngine.legalBalls(innings);
    final remainingInOver =
        match.rules.ballsPerOver - TeamScoringEngine.ballInOver(match, innings);
    final needed = min(remainingInOver, remaining);
    if (quota - used < needed) return 'Only ${quota - used} balls left';
    return null;
  }

  Future<void> _chooseBowler(TeamMatch match) async {
    if (_bowlerSheetOpen || !mounted || match.currentInnings == null) return;
    _bowlerSheetOpen = true;
    final innings = match.currentInnings!;
    final side = match.side(innings.bowlingTeamId);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final store = AppScope.read(context);
        return SafeArea(
          child: SizedBox(
            height: min(620.0, MediaQuery.sizeOf(context).height * .78),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Choose over ${TeamScoringEngine.currentOver(match, innings) + 1} bowler',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('${side.name} • individual quota enforced'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: side.playerIds.length,
                    itemBuilder: (context, index) {
                      final id = side.playerIds[index];
                      final player = store.playerById(id);
                      final used = TeamScoringEngine.bowlerBalls(innings, id);
                      final quota = side.bowlingQuotaBalls[id] ?? 0;
                      final reason = _bowlerBlockReason(match, innings, id);
                      return Card(
                        child: ListTile(
                          enabled: reason == null,
                          leading: player == null
                              ? const CircleAvatar(child: Icon(Icons.person))
                              : PlayerAvatar(player: player, radius: 20),
                          title: Text(
                            player?.name ?? id,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            reason ??
                                '${used ~/ match.rules.ballsPerOver}.${used % match.rules.ballsPerOver} used • ${(quota - used) ~/ match.rules.ballsPerOver}.${(quota - used) % match.rules.ballsPerOver} left',
                          ),
                          trailing: reason == null
                              ? const Icon(Icons.chevron_right_rounded)
                              : const Icon(Icons.block_rounded),
                          onTap: reason == null
                              ? () => Navigator.pop(context, id)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _bowlerSheetOpen = false;
    if (selected == null || !mounted) return;
    try {
      await AppScope.read(context).selectTeamBowler(match.id, selected);
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _showExtras(TeamMatch match) async {
    final hasExtras = match.rules.wideEnabled ||
        match.rules.noBallEnabled ||
        match.rules.byeEnabled ||
        match.rules.legByeEnabled ||
        match.rules.penaltyExtrasEnabled;
    if (!hasExtras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All extras are disabled for this match.')),
      );
      return;
    }
    final input = await showModalBottomSheet<_DeliveryInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExtrasSheet(rules: match.rules),
    );
    if (input == null || !mounted) return;
    await _record(
      batRuns: input.batRuns,
      extraRuns: input.extraRuns,
      extraType: input.extraType,
    );
  }

  Future<void> _showWicket(TeamMatch match) async {
    final innings = match.currentInnings!;
    final freeHit = TeamScoringEngine.isFreeHitDelivery(match, innings);
    final input = await showModalBottomSheet<_WicketInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WicketSheet(
        match: match,
        innings: innings,
        freeHit: freeHit,
      ),
    );
    if (input == null || !mounted) return;
    await _record(
      batRuns: 0,
      isWicket: true,
      dismissalType: input.type,
      dismissedPlayerId: input.dismissedPlayerId,
      fielderIds: input.fielderIds,
    );
  }

  Future<void> _undo() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final changed = await AppScope.read(context).undoLastTeamDelivery(widget.matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(changed ? 'Last ball undone.' : 'No ball to undo.')),
      );
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _endInnings(TeamMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this innings?'),
        content: const Text('Use this only when your local match rules end the innings early.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End innings')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.read(context).endTeamInnings(match.id);
      if (mounted) await _afterMutation();
    } on Object catch (error) {
      _showError(error);
    }
  }

  List<String> _openingBowlersForSecond(TeamMatch match) {
    final first = match.innings.first;
    final batting = match.side(first.bowlingTeamId);
    final bowling = match.side(first.battingTeamId);
    final batters = batting.battingOrder.take(2).toSet();
    final needed = min(match.rules.ballsPerOver, match.rules.ballLimit);
    return bowling.playerIds
        .where(
          (id) =>
              !batters.contains(id) &&
              (bowling.bowlingQuotaBalls[id] ?? 0) >= needed,
        )
        .toList(growable: false);
  }

  Future<void> _startChase(TeamMatch match) async {
    final bowler = _breakBowlerId;
    if (bowler == null || _working) return;
    setState(() => _working = true);
    try {
      await AppScope.read(context).startTeamSecondInnings(
        match.id,
        openingBowlerId: bowler,
      );
      if (mounted) setState(() => _breakBowlerId = null);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editQuotas(TeamMatch match) async {
    final innings = match.currentInnings;
    if (innings == null) return;
    final side = match.side(innings.bowlingTeamId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final store = AppScope.read(context);
          return SafeArea(
            child: SizedBox(
              height: min(650.0, MediaQuery.sizeOf(context).height * .8),
              child: Column(
                children: [
                  ListTile(
                    title: Text('${side.name} bowling limits', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('Limits cannot go below balls already bowled.'),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: side.playerIds.map((id) {
                        final player = store.playerById(id);
                        final used = TeamScoringEngine.bowlerBalls(innings, id);
                        final quota = side.bowlingQuotaBalls[id] ?? 0;
                        return Card(
                          child: ListTile(
                            leading: player == null ? null : PlayerAvatar(player: player, radius: 19),
                            title: Text(player?.name ?? id, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('$used balls bowled'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Remove one over',
                                  onPressed: quota - match.rules.ballsPerOver < used
                                      ? null
                                      : () async {
                                          final changed = await _setQuota(
                                            match,
                                            side,
                                            id,
                                            quota - match.rules.ballsPerOver,
                                          );
                                          if (!changed) return;
                                          if (!context.mounted) return;
                                          setSheetState(() {});
                                        },
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                ),
                                Text(
                                  '${quota ~/ match.rules.ballsPerOver}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                IconButton(
                                  tooltip: 'Add one over',
                                  onPressed: () async {
                                    final changed = await _setQuota(
                                      match,
                                      side,
                                      id,
                                      quota + match.rules.ballsPerOver,
                                    );
                                    if (!changed) return;
                                    if (!context.mounted) return;
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.add_circle_outline_rounded),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _setQuota(
    TeamMatch match,
    TeamSide side,
    String playerId,
    int legalBalls,
  ) async {
    try {
      await AppScope.read(context).updateTeamBowlingQuota(
        match.id,
        teamId: side.id,
        bowlerId: playerId,
        legalBalls: legalBalls,
      );
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      _showError(error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.teamMatchById(widget.matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Team Match not found')));
    }
    if (match.status == TeamMatchStatus.completed) {
      return TeamMatchSummaryScreen(matchId: match.id);
    }
    if (!store.canControlTeamMatch(match)) {
      return TeamMatchWatchScreen(matchId: match.id);
    }
    if (match.status == TeamMatchStatus.inningsBreak) {
      return _buildInningsBreak(context, match);
    }
    final innings = match.currentInnings;
    if (innings == null) {
      return const Scaffold(body: Center(child: Text('Complete the toss to start.')));
    }
    final bowlerId = TeamScoringEngine.currentBowlerId(match, innings);
    final bowler = store.playerById(bowlerId);
    final striker = store.playerById(innings.strikerId);
    final nonStriker = store.playerById(innings.nonStrikerId);
    final batting = match.side(innings.battingTeamId);
    final bowling = match.side(innings.bowlingTeamId);
    final total = TeamScoringEngine.total(innings);
    final wickets = TeamScoringEngine.wickets(innings);
    final freeHit = TeamScoringEngine.isFreeHitDelivery(match, innings);
    final recent = innings.events.reversed.take(12).toList().reversed.toList();

    if (innings.awaitingSoloDecision && !_soloDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askLastPlayer(match));
    } else if (bowlerId == null && !_bowlerSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseBowler(match));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(innings.index == 0 ? '1st Innings' : '2nd Innings'),
        actions: [
          TeamMatchSyncIndicator(matchId: match.id),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'quota') _editQuotas(match);
              if (value == 'end') _endInnings(match);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'quota',
                enabled: store.isTeamMatchHost(match),
                child: const Text('Bowling limits'),
              ),
              const PopupMenuItem(value: 'end', child: Text('End innings')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batting.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${TeamScoringEngine.overLabel(match, innings)} / ${match.rules.ballLimit ~/ match.rules.ballsPerOver} ov',
                      style: const TextStyle(color: Color(0xFFB8CCC2), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$total/$wickets',
                  style: const TextStyle(color: Colors.white, fontSize: 48, height: 1, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  innings.target == null
                      ? 'Extras ${TeamScoringEngine.extras(innings)} • ${bowling.name} bowling'
                      : 'Target ${innings.target} • Need ${max(0, innings.target! - total)} from ${max(0, match.rules.ballLimit - TeamScoringEngine.legalBalls(innings))} balls',
                  style: const TextStyle(color: Color(0xFFB8CCC2)),
                ),
                if (innings.soloMode || freeHit) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (innings.soloMode) const _DarkBadge(icon: Icons.person_rounded, label: 'SOLO BATTER'),
                      if (freeHit) const _DarkBadge(icon: Icons.bolt_rounded, label: 'FREE HIT'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PlayerRoleCard(
                  label: innings.soloMode ? 'SOLO STRIKER' : 'STRIKER',
                  name: striker?.name ?? innings.strikerId,
                  player: striker,
                  highlighted: true,
                  joker: innings.strikerId == match.commonJokerPlayerId,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlayerRoleCard(
                  label: 'NON-STRIKER',
                  name: nonStriker?.name ?? (innings.soloMode ? 'Not used' : '—'),
                  player: nonStriker,
                  joker: innings.nonStrikerId == match.commonJokerPlayerId,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlayerRoleCard(
                  label: 'BOWLER',
                  name: bowler?.name ?? 'Choose',
                  player: bowler,
                  onTap: () => _chooseBowler(match),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Runs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 1.35,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [0, 1, 2, 3, 4, 5, 6]
                .map(
                  (run) => FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: run == 4 || run == 6 ? AppColors.greenDark : AppColors.ink,
                    ),
                    onPressed: _working || bowlerId == null ? null : () => _record(batRuns: run),
                    child: Text('$run', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _working || bowlerId == null ? null : () => _showExtras(match),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Extras'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: _working || bowlerId == null ? null : () => _showWicket(match),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Wicket'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: _working || innings.events.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Undo last ball'),
          ),
          if (bowlerId == null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _chooseBowler(match),
              icon: const Icon(Icons.sports_baseball_rounded),
              label: const Text('Choose bowler to continue'),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text('Recent balls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Text('${innings.events.length} events', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Card(child: ListTile(title: Text('Score the first ball to begin.')))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: recent.map((event) => _BallChip(event: event)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInningsBreak(BuildContext context, TeamMatch match) {
    final store = AppScope.of(context);
    final first = match.innings.first;
    final firstBatting = match.side(first.battingTeamId);
    final chase = match.side(first.bowlingTeamId);
    final bowling = match.side(first.battingTeamId);
    final bowlers = _openingBowlersForSecond(match);
    if (_breakBowlerId != null && !bowlers.contains(_breakBowlerId)) {
      _breakBowlerId = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Innings Break'),
        actions: [TeamMatchSyncIndicator(matchId: match.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(26)),
            child: Column(
              children: [
                const Icon(Icons.flag_rounded, color: AppColors.gold, size: 38),
                const SizedBox(height: 10),
                Text(firstBatting.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                Text(
                  '${TeamScoringEngine.total(first)}/${TeamScoringEngine.wickets(first)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 46),
                ),
                Text(
                  '${chase.name} need ${TeamScoringEngine.total(first) + 1} to win',
                  style: const TextStyle(color: Color(0xFFB8CCC2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Start the chase', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${chase.name} batting • ${bowling.name} bowling', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _breakBowlerId,
            decoration: const InputDecoration(labelText: 'Second innings opening bowler'),
            items: bowlers.map((id) {
              final player = store.playerById(id);
              return DropdownMenuItem(
                value: id,
                child: Text(player?.name ?? id),
              );
            }).toList(),
            onChanged: (value) => setState(() => _breakBowlerId = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _breakBowlerId == null || _working ? null : () => _startChase(match),
            icon: _working
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text('Start • Target ${TeamScoringEngine.total(first) + 1}'),
          ),
          if (bowlers.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No eligible opener. Increase a bowling limit or move the Joker from the opening batting pair.',
              style: TextStyle(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryInput {
  const _DeliveryInput({required this.extraType, required this.batRuns, required this.extraRuns});

  final ExtraType extraType;
  final int batRuns;
  final int extraRuns;
}

class _ExtrasSheet extends StatefulWidget {
  const _ExtrasSheet({required this.rules});

  final TeamMatchRules rules;

  @override
  State<_ExtrasSheet> createState() => _ExtrasSheetState();
}

class _ExtrasSheetState extends State<_ExtrasSheet> {
  late ExtraType _type;
  int _batRuns = 0;
  int _extraRuns = 1;

  List<ExtraType> get _types => [
        if (widget.rules.wideEnabled) ExtraType.wide,
        if (widget.rules.noBallEnabled) ExtraType.noBall,
        if (widget.rules.byeEnabled) ExtraType.bye,
        if (widget.rules.legByeEnabled) ExtraType.legBye,
        if (widget.rules.penaltyExtrasEnabled) ExtraType.penalty,
      ];

  @override
  void initState() {
    super.initState();
    _type = _types.first;
    _extraRuns = _minimum(_type);
  }

  int _minimum(ExtraType type) => switch (type) {
        ExtraType.wide => widget.rules.wideValue,
        ExtraType.noBall => widget.rules.noBallValue,
        ExtraType.penalty => 5,
        _ => 1,
      };

  String _label(ExtraType type) => switch (type) {
        ExtraType.wide => 'Wide',
        ExtraType.noBall => 'No-ball',
        ExtraType.bye => 'Bye',
        ExtraType.legBye => 'Leg bye',
        ExtraType.penalty => 'Penalty',
        ExtraType.none => 'None',
      };

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record extras', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              DropdownButtonFormField<ExtraType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Extra type'),
                items: _types.map((type) => DropdownMenuItem(value: type, child: Text(_label(type)))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _type = value;
                    _extraRuns = _minimum(value);
                    if (value != ExtraType.noBall) _batRuns = 0;
                  });
                },
              ),
              if (_type == ExtraType.noBall) ...[
                const SizedBox(height: 14),
                const Text('Runs off the bat', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: [0, 1, 2, 3, 4, 6]
                      .map(
                        (value) => ChoiceChip(
                          label: Text('$value'),
                          selected: _batRuns == value,
                          onSelected: (_) => setState(() => _batRuns = value),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Text('Extra runs', style: TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: _extraRuns <= _minimum(_type) ? null : () => setState(() => _extraRuns--),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_extraRuns', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  IconButton(
                    onPressed: _extraRuns >= 12 ? null : () => setState(() => _extraRuns++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _DeliveryInput(extraType: _type, batRuns: _batRuns, extraRuns: _extraRuns),
                ),
                child: Text('Add ${_batRuns + _extraRuns} run${_batRuns + _extraRuns == 1 ? '' : 's'}'),
              ),
            ],
          ),
        ),
      );
}

class _WicketInput {
  const _WicketInput({required this.type, required this.dismissedPlayerId, required this.fielderIds});

  final DismissalType type;
  final String dismissedPlayerId;
  final List<String> fielderIds;
}

class _WicketSheet extends StatefulWidget {
  const _WicketSheet({required this.match, required this.innings, required this.freeHit});

  final TeamMatch match;
  final TeamInnings innings;
  final bool freeHit;

  @override
  State<_WicketSheet> createState() => _WicketSheetState();
}

class _WicketSheetState extends State<_WicketSheet> {
  late DismissalType _type;
  late String _dismissed;
  String? _fielder1;
  String? _fielder2;

  List<DismissalType> get _types => widget.freeHit
      ? const [DismissalType.runOutDirect, DismissalType.runOutAssisted, DismissalType.retiredOut]
      : DismissalType.values.where((value) => value != DismissalType.none).toList();

  @override
  void initState() {
    super.initState();
    _type = _types.first;
    _dismissed = widget.innings.strikerId;
  }

  bool get _needsOne => const {
        DismissalType.caught,
        DismissalType.runOutDirect,
        DismissalType.stumped,
      }.contains(_type);

  bool get _needsTwo => _type == DismissalType.runOutAssisted;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final bowling = widget.match.side(widget.innings.bowlingTeamId);
    final activeBatters = {widget.innings.strikerId, widget.innings.nonStrikerId};
    final fielders = bowling.playerIds.where((id) => !activeBatters.contains(id)).toList();
    final batters = [widget.innings.strikerId, if (widget.innings.nonStrikerId != null) widget.innings.nonStrikerId!];
    final valid = (!_needsOne || _fielder1 != null) &&
        (!_needsTwo || (_fielder1 != null && _fielder2 != null && _fielder1 != _fielder2));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.freeHit ? 'Free-hit wicket' : 'Record wicket', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            if (widget.freeHit)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Bowler-credit dismissals are disabled.', style: TextStyle(color: AppColors.muted)),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<DismissalType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Dismissal'),
              items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type.label))).toList(),
              onChanged: (value) => setState(() {
                _type = value ?? _type;
                _fielder1 = null;
                _fielder2 = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dismissed,
              decoration: const InputDecoration(labelText: 'Batter out'),
              items: batters.map((id) => DropdownMenuItem(value: id, child: Text(store.playerById(id)?.name ?? id))).toList(),
              onChanged: (value) => setState(() => _dismissed = value ?? _dismissed),
            ),
            if (_needsOne || _needsTwo) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _fielder1,
                decoration: InputDecoration(labelText: _needsTwo ? 'Primary fielder' : 'Fielder / keeper'),
                items: fielders.map((id) => DropdownMenuItem(value: id, child: Text(store.playerById(id)?.name ?? id))).toList(),
                onChanged: (value) => setState(() => _fielder1 = value),
              ),
            ],
            if (_needsTwo) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _fielder2,
                decoration: const InputDecoration(labelText: 'Assisting fielder'),
                items: fielders.where((id) => id != _fielder1).map((id) => DropdownMenuItem(value: id, child: Text(store.playerById(id)?.name ?? id))).toList(),
                onChanged: (value) => setState(() => _fielder2 = value),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: valid
                  ? () {
                      final bowler = TeamScoringEngine.currentBowlerId(widget.match, widget.innings);
                      final fielders = switch (_type) {
                        DismissalType.caughtAndBowled => [if (bowler != null) bowler],
                        _ when _needsTwo => [_fielder1!, _fielder2!],
                        _ when _needsOne => [_fielder1!],
                        _ => <String>[],
                      };
                      Navigator.pop(
                        context,
                        _WicketInput(type: _type, dismissedPlayerId: _dismissed, fielderIds: fielders),
                      );
                    }
                  : null,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Record wicket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRoleCard extends StatelessWidget {
  const _PlayerRoleCard({
    required this.label,
    required this.name,
    this.player,
    this.highlighted = false,
    this.joker = false,
    this.onTap,
  });

  final String label;
  final String name;
  final Player? player;
  final bool highlighted;
  final bool joker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: highlighted ? const Color(0xFFE7F8F0) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
            child: Column(
              children: [
                if (player != null)
                  PlayerAvatar(player: player, radius: 21)
                else
                  const CircleAvatar(radius: 21, child: Icon(Icons.person_outline_rounded)),
                const SizedBox(height: 7),
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                if (joker) const Text('🃏 JOKER', style: TextStyle(fontSize: 9, color: AppColors.greenDark, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      );
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF17382B), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.green, size: 15),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _BallChip extends StatelessWidget {
  const _BallChip({required this.event});

  final TeamDeliveryEvent event;

  String get label {
    if (event.isWicket) return 'W';
    return switch (event.extraType) {
      ExtraType.wide => '${event.extraRuns}Wd',
      ExtraType.noBall => '${event.totalRuns}Nb',
      ExtraType.bye => '${event.extraRuns}B',
      ExtraType.legBye => '${event.extraRuns}Lb',
      ExtraType.penalty => '${event.extraRuns}P',
      ExtraType.none => '${event.batRuns}',
    };
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: event.isWicket
              ? const Color(0xFFFFE8E9)
              : event.batRuns == 4 || event.batRuns == 6
                  ? const Color(0xFFE7F8F0)
                  : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: event.isWicket ? AppColors.danger : const Color(0xFFDCE6E0)),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: event.isWicket ? AppColors.danger : AppColors.ink)),
      );
}
