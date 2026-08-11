import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/match_planning.dart';
import '../domain/scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'public_player_profile_screen.dart';
import 'register_player_dialog.dart';

class LiveMatchScreen extends StatelessWidget {
  const LiveMatchScreen({required this.matchId, super.key});

  final String matchId;

  Future<void> _editRemainingOrder(BuildContext context) async {
    final store = AppScope.read(context);
    final match = store.matchById(matchId);
    if (match == null) return;
    final order = store.remainingReorderablePlayerIds(match);
    if (order.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fewer than two future players remain.')),
      );
      return;
    }
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'Reorder remaining players',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Completed players and the current batter stay locked. Drag only the future queue.',
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: order.length,
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final value = order.removeAt(oldIndex);
                        order.insert(newIndex, value);
                      });
                    },
                    itemBuilder: (context, index) {
                      final player = store.playerById(order[index])!;
                      return Card(
                        key: ValueKey(player.id),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(player.id),
                          trailing: const Icon(Icons.drag_handle_rounded),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, order),
                    child: const Text('Use remaining order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (updated != null && context.mounted) {
      await store.reorderRemainingPlayers(matchId, updated);
    }
  }

  Future<void> _addPlayer(BuildContext context) async {
    final store = AppScope.read(context);
    final match = store.matchById(matchId);
    if (match == null) return;
    final candidates = store.visiblePlayers
        .where((player) => !match.participantIds.contains(player.id))
        .toList();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Add player during match',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'The new player is appended to the unplayed queue. You can reorder them afterwards.',
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_add_alt_1_rounded),
                ),
                title: const Text(
                  'Create a new player account',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onTap: () => Navigator.pop(context, '__new__'),
              ),
              const Divider(height: 1),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(
                        child: Text(
                          'No other saved players. Create a new account above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final player = candidates[index];
                          return ListTile(
                            leading: PlayerAvatar(player: player),
                            title: Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(player.id),
                            onTap: () => Navigator.pop(context, player.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    late final String playerId;
    if (choice == '__new__') {
      final created = await showPlayerAccountRegistration(context);
      if (created == null || !context.mounted) return;
      playerId = created.player.id;
    } else {
      playerId = choice;
    }
    try {
      await store.addPlayerToLiveMatch(matchId, playerId);
      if (context.mounted) {
        final player = store.playerById(playerId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${player?.name ?? playerId} added to the remaining queue.',
            ),
          ),
        );
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showBowlingPlan(BuildContext context) async {
    final store = AppScope.read(context);
    final match = store.matchById(matchId);
    if (match == null) return;
    if (match.autoBowlingPlan && match.bowlingPlan.isEmpty) {
      await store.regenerateBowlingPlan(matchId);
    }
    if (!context.mounted) return;
    final current = ScoringEngine.currentBatterId(match);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Bowling plan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Past balls keep their actual bowler. Rebalancing only changes future batting turns.',
                ),
                trailing: match.autoBowlingPlan
                    ? IconButton(
                        tooltip: 'Rebalance future plan',
                        onPressed: () async {
                          Navigator.pop(context);
                          await store.regenerateBowlingPlan(matchId);
                        },
                        icon: const Icon(Icons.balance_rounded),
                      )
                    : null,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: match.battingOrder.length,
                  itemBuilder: (context, index) {
                    final batterId = match.battingOrder[index];
                    final batter = store.playerById(batterId)!;
                    final blocks = BowlingScheduler.blocksForBatter(
                      match,
                      batterId,
                    );
                    return Card(
                      color: batterId == current
                          ? const Color(0xFFE7F8F0)
                          : null,
                      child: ExpansionTile(
                        leading: PlayerAvatar(player: batter, radius: 20),
                        title: Text(
                          '${index + 1}. ${batter.name}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          batterId == current ? 'Batting now' : 'Bowling allocation',
                        ),
                        children: blocks.isEmpty
                            ? const [
                                ListTile(
                                  title: Text('Manual bowling — no fixed plan'),
                                ),
                              ]
                            : blocks.map((block) {
                                final bowler = store.playerById(block.bowlerId);
                                final label = block.legalBalls == 6
                                    ? 'Over ${block.blockIndex + 1}'
                                    : 'Final ${block.legalBalls} balls';
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.sports_baseball_rounded,
                                  ),
                                  title: Text(label),
                                  trailing: Text(
                                    bowler?.name ?? block.bowlerId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.matchById(matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Match not found')));
    }
    final states = ScoringEngine.rebuildTurns(match);
    final rankings = ScoringEngine.rankings(match);
    final currentId = ScoringEngine.currentBatterId(match);
    final current = store.playerById(currentId);
    final currentState = currentId == null ? null : states[currentId];
    final currentBlock = currentId == null || currentState == null
        ? null
        : BowlingScheduler.blockFor(
            match,
            currentId,
            currentState.legalBalls,
          );
    final currentBowler = currentBlock == null
        ? null
        : store.playerById(currentBlock.bowlerId);
    final remaining = match.battingOrder.where((id) {
      return !(states[id]?.isComplete(match.ballLimit) ?? false);
    }).toList();
    final recent = match.events.reversed.take(12).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live match'),
        actions: [
          IconButton(
            tooltip: 'Add player',
            onPressed: match.status == MatchStatus.live
                ? () => _addPlayer(context)
                : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'order') _editRemainingOrder(context);
              if (value == 'bowling') _showBowlingPlan(context);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'order',
                child: Text('Reorder remaining players'),
              ),
              PopupMenuItem(
                value: 'bowling',
                child: Text('View bowling plan'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(25),
            ),
            child: current == null
                ? const Text(
                    'Match completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAYING NOW',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => openPlayerProfile(context, current.id),
                        child: Row(
                          children: [
                            PlayerAvatar(player: current, radius: 29),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    current.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    match.scoringMode == ScoringMode.ballByBall
                                        ? '${currentState?.runs ?? 0} runs • ${OversFormat.progressLabel(currentState?.legalBalls ?? 0)} / ${OversFormat.setupOversLabel(match.ballLimit)}'
                                        : 'Direct runs • waiting for final total',
                                    style: const TextStyle(
                                      color: Color(0xFFB8CCC2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentBowler != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Current bowler: ${currentBowler.name}${currentBlock!.legalBalls < 6 ? ' • ${currentBlock.legalBalls}-ball block' : ' • Over ${currentBlock.blockIndex + 1}'}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: match.status == MatchStatus.live
                      ? () => _editRemainingOrder(context)
                      : null,
                  icon: const Icon(Icons.swap_vert_rounded),
                  label: const Text('Edit order'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: match.status == MatchStatus.live
                      ? () => _addPlayer(context)
                      : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add player'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'LIVE RANKING',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ...rankings.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final stats = entry.value;
            final player = store.playerById(stats.playerId);
            if (player == null) return const SizedBox.shrink();
            final turn = states[player.id];
            final status = turn?.isComplete(match.ballLimit) ?? false
                ? 'Completed'
                : player.id == currentId
                ? 'Playing now'
                : 'Yet to play';
            return Card(
              child: ListTile(
                onTap: () => openPlayerProfile(context, player.id),
                leading: CircleAvatar(
                  backgroundColor: rank == 1
                      ? AppColors.gold
                      : const Color(0xFFE8EFEB),
                  child: Text(
                    '$rank',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${stats.runs} runs • $status',
                  style: const TextStyle(color: AppColors.muted),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stats.points} PTS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.greenDark,
                      ),
                    ),
                    Text(
                      '${stats.wickets} WKTS',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 22),
          const Text(
            'CURRENT / NEXT ORDER',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (remaining.isEmpty)
            const Text('No remaining players.')
          else
            ...remaining.asMap().entries.map((entry) {
              final player = store.playerById(entry.value);
              if (player == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(entry.key == 0 ? 'NOW' : '${entry.key + 1}'),
                ),
                title: Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openPlayerProfile(context, player.id),
              );
            }),
          if (match.scoringMode == ScoringMode.ballByBall) ...[
            const SizedBox(height: 22),
            const Text(
              'RECENT BALLS',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              const Text(
                'No deliveries recorded yet.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: recent.map((event) {
                  final batter = store.playerById(event.batterId);
                  return Chip(
                    label: Text(
                      '${batter?.name ?? event.batterId}: ${_eventLabel(event)}',
                    ),
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _showBowlingPlan(context),
            icon: const Icon(Icons.sports_baseball_rounded),
            label: const Text('View bowling plan'),
          ),
        ],
      ),
    );
  }

  String _eventLabel(ScoreEvent event) {
    if (event.isOut) return 'W';
    if (event.extraType == ExtraType.wide) return 'Wd';
    if (event.extraType == ExtraType.noBall) return 'Nb';
    return '${event.batRuns}';
  }
}
