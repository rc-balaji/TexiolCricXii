import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/daily_performance.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../export/daily_performance_export.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';

class DailyReportBuilderScreen extends StatefulWidget {
  const DailyReportBuilderScreen({
    super.key,
    required this.summary,
    required this.players,
  });

  final DailyPerformanceSummary summary;
  final Map<String, Player> players;

  @override
  State<DailyReportBuilderScreen> createState() => _DailyReportBuilderScreenState();
}

class _DailyReportBuilderScreenState extends State<DailyReportBuilderScreen> {
  bool _overview = true;
  bool _topThree = true;
  bool _overallRanking = true;
  bool _playerPerformance = true;
  bool _matchSummary = true;
  bool _matchRankings = true;
  bool _busy = false;
  late Set<String> _matchIds;

  @override
  void initState() {
    super.initState();
    _matchIds = widget.summary.matches.map((match) => match.id).toSet();
  }

  DailyReportOptions get _options => DailyReportOptions(
    overview: _overview,
    topThree: _topThree,
    overallRanking: _overallRanking,
    playerPerformance: _playerPerformance,
    matchSummary: _matchSummary,
    matchRankings: _matchRankings,
    matchIds: Set<String>.from(_matchIds),
  );

  bool get _canExport => _options.hasAnySection && _matchIds.isNotEmpty;

  DailyPerformanceSummary get _selectedSummary =>
      DailyPerformanceExport.selectedSummary(widget.summary, _options);

  Future<void> _share() async {
    if (!_canExport || _busy) return;
    setState(() => _busy = true);
    try {
      await DailyPerformanceExport.sharePdf(
        widget.summary,
        widget.players,
        options: _options,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_canExport || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await DailyPerformanceExport.savePdf(
        widget.summary,
        widget.players,
        options: _options,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved: ${file.path}')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview() {
    if (!_canExport) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DailyReportPreviewScreen(
          summary: _selectedSummary,
          players: widget.players,
          options: _options,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMatchesSelected = _matchIds.length == widget.summary.matches.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Build performance PDF')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 130),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORT BUILDER',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Choose only what you want to share.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_date(widget.summary.date)} • ${_matchIds.length}/${widget.summary.matches.length} matches selected',
                  style: const TextStyle(color: Color(0xFFB8CCC2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Include sections'),
          _check('Overview & day totals', _overview, (value) => _overview = value),
          _check('Top 3 players', _topThree, (value) => _topThree = value),
          _check('Overall day ranking', _overallRanking, (value) => _overallRanking = value),
          _check('Player performance breakdown', _playerPerformance, (value) => _playerPerformance = value),
          _check('Match-wise winner summary', _matchSummary, (value) => _matchSummary = value),
          _check('Full ranking table for every match', _matchRankings, (value) => _matchRankings = value),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: _SectionTitle('Include matches')),
              TextButton(
                onPressed: () => setState(() {
                  if (allMatchesSelected) {
                    _matchIds.clear();
                  } else {
                    _matchIds = widget.summary.matches.map((match) => match.id).toSet();
                  }
                }),
                child: Text(allMatchesSelected ? 'Clear all' : 'Select all'),
              ),
            ],
          ),
          ...widget.summary.matches.asMap().entries.map((entry) {
            final match = entry.value;
            final rankings = ScoringEngine.rankings(match);
            final winner = rankings.isEmpty ? null : rankings.first;
            return Card(
              child: CheckboxListTile(
                value: _matchIds.contains(match.id),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _matchIds.add(match.id);
                  } else {
                    _matchIds.remove(match.id);
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  '${entry.key + 1}. ${match.title}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  winner == null
                      ? match.id
                      : 'Winner: ${widget.players[winner.playerId]?.name ?? winner.playerId} • ${winner.points} PTS',
                ),
              ),
            );
          }),
          if (!_options.hasAnySection)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Select at least one report section.',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
              ),
            ),
          if (_matchIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Select at least one match.',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canExport && !_busy ? _preview : null,
                icon: const Icon(Icons.preview_rounded),
                label: const Text('Preview selected report'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canExport && !_busy ? _share : null,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _canExport && !_busy ? _save : null,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(String title, bool value, void Function(bool) setValue) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: CheckboxListTile(
      value: value,
      onChanged: (checked) => setState(() => setValue(checked ?? false)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DailyReportPreviewScreen extends StatelessWidget {
  const _DailyReportPreviewScreen({
    required this.summary,
    required this.players,
    required this.options,
  });

  final DailyPerformanceSummary summary;
  final Map<String, Player> players;
  final DailyReportOptions options;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report preview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          if (options.overview) ...[
            _PreviewHeader(summary: summary, players: players),
            const SizedBox(height: 18),
          ],
          if (options.topThree && summary.rankings.isNotEmpty) ...[
            const _SectionTitle('Top 3 players'),
            ...summary.rankings.take(3).toList().asMap().entries.map((entry) {
              final row = entry.value;
              final player = players[row.playerId];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
                title: Text(player?.name ?? row.playerId),
                subtitle: Text('${row.runs} runs • ${row.wickets} wickets'),
                trailing: Text(
                  '${row.points} PTS',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],
          if (options.overallRanking) ...[
            const _SectionTitle('Overall day ranking'),
            ...summary.rankings.asMap().entries.map((entry) {
              final row = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('#${entry.key + 1}'),
                title: Text(players[row.playerId]?.name ?? row.playerId),
                subtitle: Text('${row.matches} matches • ${row.runs} runs • ${row.wickets} wickets'),
                trailing: Text('${row.points} PTS'),
              );
            }),
            const SizedBox(height: 14),
          ],
          if (options.playerPerformance) ...[
            const _SectionTitle('Player performance'),
            ...summary.rankings.map((row) {
              final player = players[row.playerId];
              return Card(
                child: ListTile(
                  leading: player == null ? null : PlayerAvatar(player: player, radius: 20),
                  title: Text(player?.name ?? row.playerId),
                  subtitle: Text('${row.matches} matches • ${row.wins} wins • ${row.runs} runs • ${row.wickets} wickets'),
                  trailing: Text('${row.points} PTS'),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],
          if (options.matchSummary) ...[
            const _SectionTitle('Match-wise winners'),
            ...summary.matches.asMap().entries.map((entry) {
              final match = entry.value;
              final rankings = ScoringEngine.rankings(match);
              final winner = rankings.isEmpty ? null : rankings.first;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
                title: Text(match.title),
                subtitle: Text('${match.id} • ${match.participantIds.length} players'),
                trailing: winner == null
                    ? null
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            players[winner.playerId]?.name ?? winner.playerId,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text('${winner.points} PTS'),
                        ],
                      ),
              );
            }),
            const SizedBox(height: 14),
          ],
          if (options.matchRankings) ...[
            const _SectionTitle('Full match rankings'),
            ...summary.matches.map((match) => _MatchPreview(
              match: match,
              players: players,
            )),
          ],
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.summary, required this.players});

  final DailyPerformanceSummary summary;
  final Map<String, Player> players;

  @override
  Widget build(BuildContext context) {
    final leader = summary.rankings.isEmpty ? null : summary.rankings.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S PERFORMANCE",
            style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.matches.length} matches • ${summary.totalRuns} runs • ${summary.totalWickets} wickets',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.totalPoints} points for this selected day/report',
            style: const TextStyle(color: Color(0xFFB8CCC2)),
          ),
          if (leader != null) ...[
            const SizedBox(height: 8),
            Text(
              'Leader: ${players[leader.playerId]?.name ?? leader.playerId} • ${leader.points} PTS',
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchPreview extends StatelessWidget {
  const _MatchPreview({required this.match, required this.players});

  final CricketMatch match;
  final Map<String, Player> players;

  @override
  Widget build(BuildContext context) {
    final rankings = ScoringEngine.rankings(match);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(match.id, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const Divider(height: 18),
            ...rankings.asMap().entries.map((entry) {
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text('#${entry.key + 1}')),
                    Expanded(child: Text(players[row.playerId]?.name ?? row.playerId)),
                    Text('${row.runs}R  ${row.wickets}W  ${row.points}P'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
    ),
  );
}
