import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/match_planning.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'match_summary_screen.dart';
import 'public_player_profile_screen.dart';

class ParticipantMatchWatchScreen extends StatefulWidget {
  const ParticipantMatchWatchScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<ParticipantMatchWatchScreen> createState() =>
      _ParticipantMatchWatchScreenState();
}

class _ParticipantMatchWatchScreenState
    extends State<ParticipantMatchWatchScreen> {
  Stream<CricketMatch?>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.read(context).watchSharedMatch(widget.matchId);
  }

  Future<void> _refresh() async {
    await AppScope.read(context).refreshMatches();
    if (mounted) setState(() {});
  }

  Future<void> _takeControl() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take control on this device?'),
        content: const Text(
          'Use this only when the other scoring device is no longer entering '
          'balls. Any score that exists only on that offline device cannot be '
          'merged automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep watching'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Take control'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final store = AppScope.read(context);
    try {
      await store.takeMatchControl(widget.matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Control moved to this device. Resume from Home.'),
        ),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final cached = store.matchById(widget.matchId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match watch'),
        actions: [
          IconButton(
            tooltip: 'Refresh match',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<CricketMatch?>(
        stream: _stream,
        initialData: cached,
        builder: (context, snapshot) {
          final match = snapshot.data ?? store.matchById(widget.matchId);
          if (match == null) {
            return _MissingMatch(onRefresh: _refresh);
          }
          return _MatchWatchBody(match: match, onTakeControl: _takeControl);
        },
      ),
    );
  }
}

class _MissingMatch extends StatelessWidget {
  const _MissingMatch({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_cricket_rounded, size: 48),
          const SizedBox(height: 14),
          const Text(
            'This match is no longer available.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'The host may have cancelled it, or this account is no longer a participant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ),
  );
}

class _MatchWatchBody extends StatelessWidget {
  const _MatchWatchBody({
    required this.match,
    required this.onTakeControl,
  });

  final CricketMatch match;
  final Future<void> Function() onTakeControl;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final states = ScoringEngine.rebuildTurns(match);
    final rankings = ScoringEngine.rankings(match);
    final currentId = ScoringEngine.currentBatterId(match);
    final current = store.playerById(currentId);
    final currentState = currentId == null ? null : states[currentId];
    final currentBlock = currentId == null || currentState == null
        ? null
        : BowlingScheduler.blockFor(match, currentId, currentState.legalBalls);
    final currentBowler = currentBlock == null
        ? null
        : store.playerById(currentBlock.bowlerId);
    final host = store.playerById(match.creatorPlayerId);
    final recent = match.events.reversed.take(12).toList().reversed.toList();
    final remaining = match.battingOrder.where((id) {
      return !(states[id]?.isComplete(match.ballLimit) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: store.refreshMatches,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, color: AppColors.greenDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PARTICIPANT VIEW - READ ONLY',
                        style: TextStyle(
                          color: AppColors.greenDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hosted by ${host?.name ?? match.creatorPlayerId}. The host controls setup; the selected tracker may enter live score.',
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (store.canTakeMatchControl(match) &&
              !store.canControlMatch(match)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onTakeControl,
              icon: const Icon(Icons.phonelink_lock_rounded),
              label: Text(
                store.isMatchHost(match)
                    ? 'Take control on this device'
                    : 'Take tracker control on this device',
              ),
            ),
          ],
          const SizedBox(height: 16),
          _MatchHeader(match: match),
          const SizedBox(height: 16),
          if (match.status == MatchStatus.draft ||
              match.status == MatchStatus.drawing)
            _PreparingSection(match: match)
          else if (match.status == MatchStatus.live) ...[
            _PlayingNow(
              match: match,
              current: current,
              currentState: currentState,
              currentBowler: currentBowler,
              currentBlock: currentBlock,
            ),
            const SizedBox(height: 22),
            _RankingSection(match: match, rankings: rankings, states: states),
            const SizedBox(height: 22),
            _OrderSection(remaining: remaining),
            if (match.scoringMode == ScoringMode.ballByBall) ...[
              const SizedBox(height: 22),
              _RecentBalls(events: recent),
            ],
          ] else ...[
            _CompletedSection(match: match, rankings: rankings),
          ],
          const SizedBox(height: 20),
          const Text(
            'This screen listens only while it is open. Pull down or tap Refresh after returning to the app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final CricketMatch match;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.title,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(status: match.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${match.id}  •  ${match.scoringMode.label}  •  ${OversFormat.setupOversLabel(match.ballLimit)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 5),
          Text(
            '${match.participantIds.length} players  •  ${match.pointPresetName}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      MatchStatus.draft => 'DRAFT',
      MatchStatus.drawing => 'DRAW',
      MatchStatus.live => 'LIVE',
      MatchStatus.completed => 'FINAL',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status == MatchStatus.live
            ? const Color(0xFFFFE9E9)
            : const Color(0xFFE7F8F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: status == MatchStatus.live ? Colors.redAccent : AppColors.greenDark,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PreparingSection extends StatelessWidget {
  const _PreparingSection({required this.match});

  final CricketMatch match;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final order = match.battingOrder.isNotEmpty
        ? match.battingOrder
        : match.drawPlayerOrder.isNotEmpty
        ? match.drawPlayerOrder
        : match.participantIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppColors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The host is preparing the draw / batting order. This page will update when the match starts.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'PLAYERS / CURRENT ORDER',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...order.asMap().entries.map((entry) {
          final player = store.playerById(entry.value);
          if (player == null) return const SizedBox.shrink();
          return ListTile(
            onTap: () => openPlayerProfile(context, player.id),
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${entry.key + 1}')),
            title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(player.id),
            trailing: const Icon(Icons.chevron_right_rounded),
          );
        }),
      ],
    );
  }
}

class _PlayingNow extends StatelessWidget {
  const _PlayingNow({
    required this.match,
    required this.current,
    required this.currentState,
    required this.currentBowler,
    required this.currentBlock,
  });

  final CricketMatch match;
  final Player? current;
  final TurnState? currentState;
  final Player? currentBowler;
  final BowlingBlock? currentBlock;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(25),
    ),
    child: current == null
        ? const Text(
            'Waiting for the next player...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
                onTap: () => openPlayerProfile(context, current!.id),
                child: Row(
                  children: [
                    PlayerAvatar(player: current!, radius: 29),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            match.scoringMode == ScoringMode.ballByBall
                                ? '${currentState?.runs ?? 0} runs • ${OversFormat.progressLabel(currentState?.legalBalls ?? 0)} / ${OversFormat.setupOversLabel(match.ballLimit)}'
                                : 'Direct runs • waiting for the host entry',
                            style: const TextStyle(color: Color(0xFFB8CCC2)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (currentBowler != null && currentBlock != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Current bowler: ${currentBowler!.name} • ${currentBlock!.legalBalls < 6 ? '${currentBlock!.legalBalls}-ball block' : 'Over ${currentBlock!.blockIndex + 1}'}',
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
  );
}

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.match,
    required this.rankings,
    required this.states,
  });

  final CricketMatch match;
  final List<PlayerMatchStats> rankings;
  final Map<String, TurnState> states;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final currentId = ScoringEngine.currentBatterId(match);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIVE RANKING',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 9),
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
                backgroundColor: rank == 1 ? AppColors.gold : const Color(0xFFE8EFEB),
                child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${stats.runs} runs • $status'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.points} PTS',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.greenDark),
                  ),
                  Text(
                    '${stats.wickets} WKTS',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _OrderSection extends StatelessWidget {
  const _OrderSection({required this.remaining});

  final List<String> remaining;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CURRENT / NEXT ORDER',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        if (remaining.isEmpty)
          const Text('No remaining players.')
        else
          ...remaining.asMap().entries.map((entry) {
            final player = store.playerById(entry.value);
            if (player == null) return const SizedBox.shrink();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => openPlayerProfile(context, player.id),
              leading: CircleAvatar(child: Text(entry.key == 0 ? 'NOW' : '${entry.key + 1}')),
              title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              trailing: const Icon(Icons.chevron_right_rounded),
            );
          }),
      ],
    );
  }
}

class _RecentBalls extends StatelessWidget {
  const _RecentBalls({required this.events});

  final List<ScoreEvent> events;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT BALLS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 9),
        if (events.isEmpty)
          const Text('No deliveries recorded yet.', style: TextStyle(color: AppColors.muted))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: events.map((event) {
              final batter = store.playerById(event.batterId);
              final label = event.isOut
                  ? 'W'
                  : event.extraType == ExtraType.wide
                  ? 'Wd'
                  : event.extraType == ExtraType.noBall
                  ? 'Nb'
                  : '${event.batRuns}';
              return Chip(label: Text('${batter?.name ?? event.batterId}: $label'));
            }).toList(),
          ),
      ],
    );
  }
}

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({required this.match, required this.rankings});

  final CricketMatch match;
  final List<PlayerMatchStats> rankings;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final winner = rankings.isEmpty ? null : store.playerById(rankings.first.playerId);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 42),
              const SizedBox(height: 10),
              const Text(
                'MATCH COMPLETED',
                style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w900),
              ),
              if (winner != null) ...[
                const SizedBox(height: 10),
                PlayerAvatar(player: winner, radius: 30),
                const SizedBox(height: 8),
                Text(
                  winner.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${rankings.first.points} PTS • ${rankings.first.runs} runs',
                  style: const TextStyle(color: Color(0xFFB8CCC2)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MatchSummaryScreen(matchId: match.id)),
          ),
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Open final scorecard'),
        ),
      ],
    );
  }
}
