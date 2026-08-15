import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../domain/team_match.dart';
import '../domain/team_scoring_engine.dart';
import '../export/team_scorecard_export.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import 'create_team_match_screen.dart';

enum _NextTeamMatchChoice { sameTeams, changeTeams }

class TeamMatchSummaryScreen extends StatefulWidget {
  const TeamMatchSummaryScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<TeamMatchSummaryScreen> createState() => _TeamMatchSummaryScreenState();
}

class _TeamMatchSummaryScreenState extends State<TeamMatchSummaryScreen> {
  bool _exporting = false;
  bool _syncing = false;
  bool _openingNextMatch = false;

  Map<String, Player> _players(TeamMatch match) {
    final store = AppScope.read(context);
    return {
      for (final id in match.participantIds)
        if (store.playerById(id) != null) id: store.playerById(id)!,
    };
  }

  Future<void> _share(TeamMatch match) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await TeamScorecardExport.sharePdf(match, _players(match));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share Team PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _save(TeamMatch match) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final file = await TeamScorecardExport.savePdf(match, _players(match));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Team PDF saved: ${file.path}')),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save Team PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _sync(TeamMatch match) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final store = AppScope.read(context);
    bool synced;
    try {
      if (store.canTakeTeamMatchControl(match)) {
        synced = await store.syncTeamMatchNow(match.id);
      } else {
        await store.refreshMatchHistory();
        synced = store.isTeamMatchSynced(match.id);
      }
      if (!mounted) return;
      final error = store.matchSyncError(match.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'This Team Match is synced with cloud.'
                : error ?? 'Cloud sync is still pending. Local history is safe.',
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync retry failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _home() => Navigator.of(context).popUntil((route) => route.isFirst);

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  Future<void> _createNextMatch(
    TeamMatch match, {
    required _NextTeamMatchChoice choice,
  }) async {
    if (!mounted || _openingNextMatch) return;
    setState(() => _openingNextMatch = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateTeamMatchScreen(
            templateMatchId: match.id,
            quickRematch: choice == _NextTeamMatchChoice.sameTeams,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingNextMatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.teamMatchById(widget.matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Team Match not found')));
    }
    final result = TeamScoringEngine.result(match);
    final completedAt = match.completedAt ?? match.createdAt;
    final todayMatches = store.teamMatches
        .where(
          (value) =>
              value.status == TeamMatchStatus.completed &&
              _sameDay(value.completedAt ?? value.createdAt, completedAt),
        )
        .toList(growable: false);
    final seriesMatches = store.teamMatches
        .where(
          (value) =>
              value.status == TeamMatchStatus.completed &&
              value.seriesId == match.seriesId,
        )
        .toList(growable: false);
    final matchPoints = TeamScoringEngine.aggregatePlayerPoints([match]);
    final todayPoints = TeamScoringEngine.aggregatePlayerPoints(todayMatches);
    final seriesPoints = TeamScoringEngine.aggregatePlayerPoints(seriesMatches);
    final pomId = TeamScoringEngine.topPlayerFromPoints(matchPoints);
    final todayPlayerId = TeamScoringEngine.topPlayerFromPoints(todayPoints);
    final seriesPlayerId = TeamScoringEngine.topPlayerFromPoints(seriesPoints);
    final synced = store.isTeamMatchSynced(match.id);
    final error = store.matchSyncError(match.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Match Result'),
        automaticallyImplyLeading: true,
        actions: [TeamMatchSyncIndicator(matchId: match.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 42),
                const SizedBox(height: 8),
                Text(
                  match.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  result.summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Series match ${match.seriesMatchNumber}',
                  style: const TextStyle(
                    color: Color(0xFFB8CCC2),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: match.innings.map((innings) {
                    final side = match.side(innings.battingTeamId);
                    return SizedBox(
                      width: 140,
                      child: Column(
                        children: [
                          Text(
                            TeamScoringEngine.inningsLabel(innings),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            side.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8CCC2),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${TeamScoringEngine.overLabel(match, innings)} ov',
                            style: const TextStyle(
                              color: Color(0xFFB8CCC2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (pomId != null || todayPlayerId != null || seriesPlayerId != null) ...[
            const SizedBox(height: 14),
            Text(
              'Point awards',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (pomId != null)
              _AwardCard(
                label: 'Player of the Match',
                player: store.playerById(pomId),
                playerId: pomId,
                points: matchPoints[pomId] ?? 0,
                detail: 'This match',
                icon: Icons.star_rounded,
              ),
            if (todayPlayerId != null)
              _AwardCard(
                label: 'Player of Today',
                player: store.playerById(todayPlayerId),
                playerId: todayPlayerId,
                points: todayPoints[todayPlayerId] ?? 0,
                detail: '${todayMatches.length} Team Match${todayMatches.length == 1 ? '' : 'es'} today',
                icon: Icons.today_rounded,
              ),
            if (seriesPlayerId != null)
              _AwardCard(
                label: 'Player of the Series',
                player: store.playerById(seriesPlayerId),
                playerId: seriesPlayerId,
                points: seriesPoints[seriesPlayerId] ?? 0,
                detail: '${seriesMatches.length} match${seriesMatches.length == 1 ? '' : 'es'} in this series',
                icon: Icons.workspace_premium_rounded,
              ),
          ],
          const SizedBox(height: 14),
          Card(
            color: synced ? const Color(0xFFE7F8F0) : const Color(0xFFFFF7E4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        synced ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                        color: synced ? AppColors.greenDark : const Color(0xFFA56600),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          synced ? 'Synced with cloud' : 'Cloud sync pending',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    synced
                        ? 'This result is available in shared match history.'
                        : error ?? 'The result is safe on this phone. You can sync now or go Home and retry from History later.',
                    style: const TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _syncing ? null : () => _sync(match),
                    icon: _syncing
                        ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(synced ? Icons.sync_rounded : Icons.cloud_upload_outlined),
                    label: Text(synced ? 'Sync again' : 'Sync now'),
                  ),
                ],
              ),
            ),
          ),
          if (store.isTeamMatchHost(match)) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFEAF4FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Play the next Team Match?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Keep the same teams or review today’s players and build new teams. Both continue this Series.',
                      style: TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openingNextMatch
                                ? null
                                : () => _createNextMatch(
                                    match,
                                    choice: _NextTeamMatchChoice.changeTeams,
                                  ),
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('Change teams'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openingNextMatch
                                ? null
                                : () => _createNextMatch(
                                    match,
                                    choice: _NextTeamMatchChoice.sameTeams,
                                  ),
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Same teams'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Scorecards', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...match.innings.map(
            (innings) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InningsScorecard(match: match, innings: innings),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _save(match),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Save PDF'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exporting ? null : () => _share(match),
                  icon: _exporting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.share_rounded),
                  label: const Text('Share PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _home,
            icon: const Icon(Icons.home_rounded),
            label: Text(synced ? 'Back to Home' : 'Go Home • sync later'),
          ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.label,
    required this.player,
    required this.playerId,
    required this.points,
    required this.detail,
    required this.icon,
  });

  final String label;
  final Player? player;
  final String playerId;
  final int points;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF7E4),
    child: ListTile(
      leading: player == null
          ? CircleAvatar(child: Icon(icon))
          : PlayerAvatar(player: player!, radius: 23),
      title: Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      subtitle: Text(
        player?.name ?? playerId,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$points pts',
            style: const TextStyle(
              color: Color(0xFFA56600),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(detail, style: const TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );
}

class _InningsScorecard extends StatelessWidget {
  const _InningsScorecard({required this.match, required this.innings});

  final TeamMatch match;
  final TeamInnings innings;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final stats = TeamScoringEngine.inningsAppearanceStats(match, innings);
    final batting = match.side(innings.battingTeamId);
    final bowling = match.side(innings.bowlingTeamId);
    TeamPlayerMatchStats stat(String teamId, String id) =>
        stats['$teamId:$id'] ?? TeamPlayerMatchStats(playerId: id, teamId: teamId);
    final bowlers = bowling.playerIds
        .map((id) => stat(bowling.id, id))
        .where((value) => value.ballsBowled > 0)
        .toList();
    return Card(
      child: ExpansionTile(
        initiallyExpanded: innings.index == 0,
        title: Text(
          '${TeamScoringEngine.inningsLabel(innings)} • ${batting.name} • ${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${TeamScoringEngine.overLabel(match, innings)} overs • Extras ${TeamScoringEngine.extras(innings)}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('BATTING', style: TextStyle(color: AppColors.greenDark, fontSize: 11, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowHeight: 34,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Text('Batter')),
                DataColumn(label: Text('R')),
                DataColumn(label: Text('B')),
                DataColumn(label: Text('4')),
                DataColumn(label: Text('6')),
                DataColumn(label: Text('SR')),
              ],
              rows: TeamScoringEngine.battingDisplayOrder(match, innings).map((id) {
                final value = stat(batting.id, id);
                final player = store.playerById(id);
                return DataRow(cells: [
                  DataCell(Row(children: [
                    if (player != null) PlayerAvatar(player: player, radius: 13),
                    if (player != null) const SizedBox(width: 6),
                    Text('${player?.name ?? id}${id == match.commonJokerPlayerId ? ' 🃏' : ''}${value.dismissed ? '' : '*'}'),
                  ])),
                  DataCell(Text('${value.runs}')),
                  DataCell(Text('${value.balls}')),
                  DataCell(Text('${value.fours}')),
                  DataCell(Text('${value.sixes}')),
                  DataCell(Text(value.strikeRate.toStringAsFixed(1))),
                ]);
              }).toList(),
            ),
          ),
          if (bowlers.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('BOWLING', style: TextStyle(color: AppColors.greenDark, fontSize: 11, fontWeight: FontWeight.w900))),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowHeight: 34,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('Bowler')),
                  DataColumn(label: Text('O')),
                  DataColumn(label: Text('R')),
                  DataColumn(label: Text('W')),
                  DataColumn(label: Text('Eco')),
                  DataColumn(label: Text('Wd')),
                  DataColumn(label: Text('Nb')),
                ],
                rows: bowlers.map((value) {
                  final player = store.playerById(value.playerId);
                  return DataRow(cells: [
                    DataCell(Text('${player?.name ?? value.playerId}${value.playerId == match.commonJokerPlayerId ? ' 🃏' : ''}')),
                    DataCell(Text('${value.ballsBowled ~/ match.rules.ballsPerOver}.${value.ballsBowled % match.rules.ballsPerOver}')),
                    DataCell(Text('${value.runsConceded}')),
                    DataCell(Text('${value.wickets}')),
                    DataCell(Text(value.economy.toStringAsFixed(2))),
                    DataCell(Text('${value.wides}')),
                    DataCell(Text('${value.noBalls}')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
