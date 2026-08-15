import 'package:flutter/material.dart';

import '../domain/daily_performance.dart';
import '../domain/player.dart';
import '../export/daily_performance_export.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';

enum _ReportMatchFilter { all, singles, team }

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
  _ReportMatchFilter _filter = _ReportMatchFilter.all;
  late Set<String> _matchKeys;

  @override
  void initState() {
    super.initState();
    _matchKeys = widget.summary.matches.map((match) => match.key).toSet();
  }

  DailyReportOptions get _options => DailyReportOptions(
        overview: _overview,
        topThree: _topThree,
        overallRanking: _overallRanking,
        playerPerformance: _playerPerformance,
        matchSummary: _matchSummary,
        matchRankings: _matchRankings,
        matchKeys: Set<String>.from(_matchKeys),
      );

  bool get _canExport => _options.hasAnySection && _matchKeys.isNotEmpty;

  DailyPerformanceSummary get _selectedSummary =>
      DailyPerformanceExport.selectedSummary(widget.summary, _options);

  List<DailyMatchEntry> get _shownMatches => switch (_filter) {
        _ReportMatchFilter.all => widget.summary.matches,
        _ReportMatchFilter.singles => widget.summary.matches
            .where((match) => match.type == DailyMatchType.singles)
            .toList(),
        _ReportMatchFilter.team => widget.summary.matches
            .where((match) => match.type == DailyMatchType.team)
            .toList(),
      };

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

  void _selectShown(bool selected) {
    setState(() {
      if (selected) {
        _matchKeys.addAll(_shownMatches.map((match) => match.key));
      } else {
        _matchKeys.removeAll(_shownMatches.map((match) => match.key));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSummary;
    final shown = _shownMatches;
    final anyShownSelected =
        shown.any((match) => _matchKeys.contains(match.key));
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
                Text(
                  selected.reportTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_date(widget.summary.date)} • ${_matchKeys.length}/${widget.summary.matches.length} selected • ${selected.singlesCount} Singles • ${selected.teamCount} Team',
                  style: const TextStyle(color: Color(0xFFB8CCC2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Include sections'),
          _check('Day overview', _overview, (value) => _overview = value),
          _check('Top 3 players', _topThree, (value) => _topThree = value),
          _check('Overall rankings', _overallRanking, (value) => _overallRanking = value),
          _check('Player performance', _playerPerformance, (value) => _playerPerformance = value),
          _check('Match-wise results', _matchSummary, (value) => _matchSummary = value),
          _check('Full rankings per match', _matchRankings, (value) => _matchRankings = value),
          const SizedBox(height: 22),
          const _SectionTitle('Include matches'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${widget.summary.matches.length})'),
                selected: _filter == _ReportMatchFilter.all,
                onSelected: (_) => setState(() => _filter = _ReportMatchFilter.all),
              ),
              ChoiceChip(
                label: Text('Singles (${widget.summary.singlesCount})'),
                selected: _filter == _ReportMatchFilter.singles,
                onSelected: (_) => setState(() => _filter = _ReportMatchFilter.singles),
              ),
              ChoiceChip(
                label: Text('Team Match (${widget.summary.teamCount})'),
                selected: _filter == _ReportMatchFilter.team,
                onSelected: (_) => setState(() => _filter = _ReportMatchFilter.team),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: shown.isEmpty ? null : () => _selectShown(true),
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Select shown'),
              ),
              TextButton.icon(
                onPressed: !anyShownSelected ? null : () => _selectShown(false),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear shown'),
              ),
            ],
          ),
          if (_filter == _ReportMatchFilter.all) ...[
            _matchGroup('SINGLES MATCHES', shown.where((match) => match.isSingles).toList()),
            _matchGroup('TEAM MATCHES', shown.where((match) => match.isTeam).toList()),
          ] else
            _matchGroup(
              _filter == _ReportMatchFilter.singles ? 'SINGLES MATCHES' : 'TEAM MATCHES',
              shown,
            ),
          if (!_options.hasAnySection)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Select at least one report section.',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
              ),
            ),
          if (_matchKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Select at least one completed match.',
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

  Widget _matchGroup(String title, List<DailyMatchEntry> matches) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        ...matches.map((match) {
          final leader = match.rankings.isEmpty ? null : match.rankings.first;
          return Card(
            child: CheckboxListTile(
              value: _matchKeys.contains(match.key),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  _matchKeys.add(match.key);
                } else {
                  _matchKeys.remove(match.key);
                }
              }),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: match.isSingles
                      ? const Color(0xFFE7F8F0)
                      : const Color(0xFFFFF4D8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.isSingles ? 'SINGLES' : 'TEAM',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(match.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                match.isTeam
                    ? match.resultLabel
                    : leader == null
                        ? 'Completed Singles match'
                        : 'Winner: ${widget.players[leader.playerId]?.name ?? leader.playerId} • ${leader.points} PTS',
              ),
            ),
          );
        }),
      ],
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Report preview')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            if (options.overview) ...[
              _PreviewHeader(summary: summary),
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
                  trailing: Text('${row.points} PTS', style: const TextStyle(fontWeight: FontWeight.w900)),
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
              const _SectionTitle('Match-wise results'),
              ...summary.matches.asMap().entries.map((entry) {
                final match = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(match.title),
                  subtitle: Text('${match.isSingles ? 'Singles' : 'Team Match'} • ${match.resultLabel}'),
                  trailing: Text('${match.playerCount} players'),
                );
              }),
              const SizedBox(height: 14),
            ],
            if (options.matchRankings) ...[
              const _SectionTitle('Full rankings per match'),
              ...summary.matches.map((match) => _MatchPreview(match: match, players: players)),
            ],
          ],
        ),
      );
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.summary});

  final DailyPerformanceSummary summary;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODAY PERFORMANCE', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(summary.reportTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              '${summary.matches.length} matches • ${summary.singlesCount} Singles • ${summary.teamCount} Team • ${summary.totalRuns} runs • ${summary.totalWickets} wickets',
              style: const TextStyle(color: Color(0xFFB8CCC2)),
            ),
          ],
        ),
      );
}

class _MatchPreview extends StatelessWidget {
  const _MatchPreview({required this.match, required this.players});

  final DailyMatchEntry match;
  final Map<String, Player> players;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('${match.isSingles ? 'Singles' : 'Team Match'} • ${match.resultLabel}', style: const TextStyle(color: AppColors.muted)),
              const Divider(height: 20),
              ...match.rankings.asMap().entries.map((entry) {
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 30, child: Text('#${entry.key + 1}')),
                      Expanded(child: Text(players[row.playerId]?.name ?? row.playerId)),
                      Text('${row.runs}R • ${row.wickets}W • ${row.points}P'),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      );
}
