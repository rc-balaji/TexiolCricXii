import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../export/scorecard_export.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'quick_score_screen.dart';
import 'tracker_screen.dart';

class MatchSummaryScreen extends StatefulWidget {
  const MatchSummaryScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  bool _exporting = false;

  Future<void> _share() async {
    final store = AppScope.read(context);
    final match = store.matchById(widget.matchId)!;
    final players = <String, Player>{};
    for (final id in match.participantIds) {
      final player = store.playerById(id);
      if (player != null) players[id] = player;
    }
    setState(() => _exporting = true);
    try {
      await ScorecardExport.sharePdf(match, players);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share the PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _save() async {
    final store = AppScope.read(context);
    final match = store.matchById(widget.matchId)!;
    final players = <String, Player>{};
    for (final id in match.participantIds) {
      final player = store.playerById(id);
      if (player != null) players[id] = player;
    }
    setState(() => _exporting = true);
    try {
      final file = await ScorecardExport.savePdf(match, players);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF saved: ${file.path}')));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _editLast() async {
    final store = AppScope.read(context);
    final changed = await store.undoLast(widget.matchId);
    if (!mounted) return;
    if (!changed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No score entry to edit.')));
      return;
    }
    final match = store.matchById(widget.matchId)!;
    final page = match.scoringMode == ScoringMode.ballByBall
        ? TrackerScreen(matchId: match.id)
        : QuickScoreScreen(matchId: match.id);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.matchById(widget.matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Match not found')));
    }
    final rankings = ScoringEngine.rankings(match);
    if (rankings.isEmpty) {
      return const Scaffold(body: Center(child: Text('No scores recorded')));
    }
    final winner = store.playerById(rankings.first.playerId)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match summary'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editLast();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Undo final entry & edit'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF071A13), Color(0xFF124B37)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'MATCH WINNER',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PlayerAvatar(player: winner, radius: 37),
                  const SizedBox(height: 10),
                  Text(
                    winner.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.winnerMetric == MatchWinnerMetric.runs
                        ? '${rankings.first.runs} runs'
                        : '${rankings.first.points} points • ${rankings.first.runs} runs',
                    style: const TextStyle(color: Color(0xFFB8CCC2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${match.id} • ${match.scoringMode.label} • '
                      '${match.scoringMode == ScoringMode.ballByBall ? '${match.ballLimit} balls each' : 'final totals'}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Official ranking: ${match.winnerMetric == MatchWinnerMetric.runs ? 'Runs only' : 'Overall points'}',
                      style: const TextStyle(
                        color: AppColors.greenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'FINAL RANKING',
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
              final player = store.playerById(stats.playerId)!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: rank == 1
                              ? AppColors.gold
                              : const Color(0xFFE8EFEB),
                          foregroundColor: AppColors.ink,
                          child: Text(
                            '$rank',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 11),
                        PlayerAvatar(player: player, radius: 22),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${stats.wickets} wkts • ${stats.catches} catches • '
                                '${stats.directRunOuts + stats.assistedRunOuts} run-outs',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stats.runs}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${stats.points} pts${match.scoringMode == ScoringMode.ballByBall ? ' • ${stats.balls}b' : ''}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _exporting ? null : _share,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded),
              label: const Text('Share scorecard PDF'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _save,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Save PDF'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
