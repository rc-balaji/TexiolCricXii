import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/team_match.dart';
import '../domain/team_scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import 'team_live_match_screen.dart';
import 'team_match_summary_screen.dart';
import 'team_toss_screen.dart';

class TeamMatchWatchScreen extends StatefulWidget {
  const TeamMatchWatchScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<TeamMatchWatchScreen> createState() => _TeamMatchWatchScreenState();
}

class _TeamMatchWatchScreenState extends State<TeamMatchWatchScreen> {
  bool _takingControl = false;
  Stream<TeamMatch?>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.read(context).watchSharedTeamMatch(widget.matchId);
  }

  Widget _controllerPage(TeamMatch match) => switch (match.status) {
        TeamMatchStatus.toss => TeamTossScreen(matchId: match.id),
        TeamMatchStatus.live || TeamMatchStatus.inningsBreak =>
          TeamLiveMatchScreen(matchId: match.id),
        TeamMatchStatus.completed => TeamMatchSummaryScreen(matchId: match.id),
      };

  Future<void> _takeControl(TeamMatch match) async {
    if (_takingControl) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take control on this device?'),
        content: const Text(
          'Use this when the other scorer has stopped. CricXii will pull the latest cloud revision before moving the scoring lease.',
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
    setState(() => _takingControl = true);
    try {
      final store = AppScope.read(context);
      await store.takeTeamMatchControl(match.id);
      if (!mounted) return;
      final latest = store.teamMatchById(match.id);
      if (latest == null || !store.canControlTeamMatch(latest)) {
        throw StateError('Control is not available for this match stage.');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _controllerPage(latest)),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _takingControl = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final local = store.teamMatchById(widget.matchId);
    return StreamBuilder<TeamMatch?>(
      stream: _stream,
      initialData: local,
      builder: (context, snapshot) {
        final match = snapshot.data ?? store.teamMatchById(widget.matchId);
        if (match == null) {
          return const Scaffold(body: Center(child: Text('Team Match is unavailable.')));
        }
        final innings = match.currentInnings;
        final result = TeamScoringEngine.result(match);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Watch Team Match'),
            actions: [TeamMatchSyncIndicator(matchId: match.id)],
          ),
          body: RefreshIndicator(
            onRefresh: store.refreshMatchHistory,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(27)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, color: AppColors.green, size: 20),
                          const SizedBox(width: 7),
                          const Text('LIVE PARTICIPANT VIEW', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const Spacer(),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(match.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('${match.teamA.name} vs ${match.teamB.name}', style: const TextStyle(color: Color(0xFFB8CCC2))),
                      const SizedBox(height: 18),
                      if (match.innings.isEmpty)
                        const Text('Waiting for match start', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))
                      else
                        Row(
                          children: match.innings.map((value) {
                            final side = match.side(value.battingTeamId);
                            return Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(side.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB8CCC2), fontSize: 12)),
                                  Text('${TeamScoringEngine.total(value)}/${TeamScoringEngine.wickets(value)}', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                                  Text('${TeamScoringEngine.overLabel(match, value)} ov', style: const TextStyle(color: Color(0xFFB8CCC2), fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      if (match.status == TeamMatchStatus.completed) ...[
                        const SizedBox(height: 14),
                        Text(result.summary, style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
                      ] else if (innings?.target != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Target ${innings!.target} • Need ${(innings.target! - TeamScoringEngine.total(innings)).clamp(0, innings.target!)}',
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _StageCard(match: match),
                if (innings != null && match.status == TeamMatchStatus.live) ...[
                  const SizedBox(height: 14),
                  _PlayersAtCrease(match: match, innings: innings),
                  const SizedBox(height: 14),
                  _RecentWatchBalls(innings: innings),
                ],
                const SizedBox(height: 18),
                if (match.status == TeamMatchStatus.completed)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => TeamMatchSummaryScreen(matchId: match.id)),
                    ),
                    icon: const Icon(Icons.emoji_events_rounded),
                    label: const Text('Open full result'),
                  )
                else if (store.canTakeTeamMatchControl(match) &&
                    (match.status != TeamMatchStatus.toss ||
                        store.isTeamMatchHost(match)))
                  FilledButton.icon(
                    onPressed: _takingControl ? null : () => _takeControl(match),
                    icon: _takingControl
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sports_cricket_rounded),
                    label: const Text('Take scoring control'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'This screen follows the shared cloud score. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.match});

  final TeamMatch match;

  @override
  Widget build(BuildContext context) {
    final text = switch (match.status) {
      TeamMatchStatus.toss => 'Start method not chosen',
      TeamMatchStatus.live => 'Innings ${(match.currentInnings?.index ?? 0) + 1} in progress',
      TeamMatchStatus.inningsBreak => 'Innings break • chase setup pending',
      TeamMatchStatus.completed => 'Match completed',
    };
    return Card(
      child: ListTile(
        leading: Icon(
          match.status == TeamMatchStatus.completed ? Icons.check_circle_rounded : Icons.timelapse_rounded,
          color: AppColors.greenDark,
        ),
        title: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('Match ID ${match.id}'),
      ),
    );
  }
}

class _PlayersAtCrease extends StatelessWidget {
  const _PlayersAtCrease({required this.match, required this.innings});

  final TeamMatch match;
  final TeamInnings innings;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final striker = store.playerById(innings.strikerId);
    final bowlerId = TeamScoringEngine.currentBowlerId(match, innings);
    final bowler = store.playerById(bowlerId);
    return Row(
      children: [
        Expanded(
          child: Card(
            color: const Color(0xFFE7F8F0),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (striker != null) PlayerAvatar(player: striker, radius: 21),
                  if (striker != null) const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('STRIKER', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w900)),
                    Text(striker?.name ?? innings.strikerId, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (innings.soloMode) const Text('Solo mode', style: TextStyle(color: AppColors.greenDark, fontSize: 11)),
                  ])),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (bowler != null) PlayerAvatar(player: bowler, radius: 21),
                  if (bowler != null) const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('BOWLER', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w900)),
                    Text(bowler?.name ?? 'Changing over', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ])),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentWatchBalls extends StatelessWidget {
  const _RecentWatchBalls({required this.innings});

  final TeamInnings innings;

  String _label(TeamDeliveryEvent event) {
    if (event.isWicket) return 'W';
    return switch (event.extraType) {
      ExtraType.none => '${event.batRuns}',
      ExtraType.wide => '${event.extraRuns}Wd',
      ExtraType.noBall => '${event.totalRuns}Nb',
      ExtraType.bye => '${event.extraRuns}B',
      ExtraType.legBye => '${event.extraRuns}Lb',
      ExtraType.penalty => '${event.extraRuns}P',
    };
  }

  @override
  Widget build(BuildContext context) {
    final events = innings.events.reversed.take(12).toList().reversed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RECENT BALLS', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: events.map((event) => Chip(label: Text(_label(event)))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
