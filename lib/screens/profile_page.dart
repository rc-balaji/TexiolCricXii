import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/team_match.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/match_sync_indicator.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import '../widgets/ui_bits.dart';
import 'account_settings_screen.dart';
import 'daily_performance_screen.dart';
import 'match_summary_screen.dart';
import 'team_match_summary_screen.dart';
import 'player_management_screen.dart';
import 'profile_edit_screen.dart';

enum _ProfileMatchFilter { all, singles, team }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  _ProfileMatchFilter _filter = _ProfileMatchFilter.all;
  bool _refreshingHistory = false;
  bool _loadingOlderHistory = false;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _refreshHistory(BuildContext context) async {
    if (_refreshingHistory) return;
    setState(() => _refreshingHistory = true);
    final store = AppScope.of(context);
    await store.refreshMatchHistory();
    if (!mounted || !context.mounted) return;
    setState(() => _refreshingHistory = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match history and career stats refreshed.')),
    );
  }

  Future<void> _loadOlderHistory(BuildContext context) async {
    if (_loadingOlderHistory) return;
    setState(() => _loadingOlderHistory = true);
    final store = AppScope.read(context);
    switch (_filter) {
      case _ProfileMatchFilter.all:
        await store.loadOlderMatchHistory();
        await store.loadOlderTeamMatchHistory();
        break;
      case _ProfileMatchFilter.singles:
        await store.loadOlderMatchHistory();
        break;
      case _ProfileMatchFilter.team:
        await store.loadOlderTeamMatchHistory();
        break;
    }
    if (!mounted) return;
    setState(() => _loadingOlderHistory = false);
  }

  Future<void> _openLink(BuildContext context, String value, {bool instagram = false}) async {
    final raw = value.trim();
    final uri = instagram
        ? Uri.parse(
            raw.startsWith('http')
                ? raw
                : 'https://www.instagram.com/${raw.replaceFirst('@', '')}/',
          )
        : Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that profile link.')),
        );
      }
    }
  }

  String _joined(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _singleHistoryCard(BuildContext context, CricketMatch match) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: ListTile(
            leading: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.greenDark,
            ),
            title: Text(
              match.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('${match.id} • ${match.scoringMode.label}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MatchSyncIndicator(matchId: match.id),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => _open(
              context,
              MatchSummaryScreen(matchId: match.id),
            ),
          ),
        ),
      );

  Widget _teamHistoryCard(BuildContext context, TeamMatch match) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        leading: const Icon(
          Icons.groups_2_rounded,
          color: Color(0xFFA56600),
        ),
        title: Text(
          match.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${match.teamA.name} vs ${match.teamB.name} • ${match.id}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeamMatchSyncIndicator(matchId: match.id),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => _open(
          context,
          TeamMatchSummaryScreen(matchId: match.id),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.activePlayer!;
    final gang = store.gangById(player.gangId);
    final history = store.matches
        .where(
          (match) =>
              match.status == MatchStatus.completed &&
              match.participantIds.contains(player.id),
        )
        .toList()
      ..sort((a, b) {
        final aDate = a.completedAt ?? a.createdAt;
        final bDate = b.completedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    final teamHistory = store.teamMatches
        .where(
          (match) =>
              match.status == TeamMatchStatus.completed &&
              match.participantIds.contains(player.id),
        )
        .toList()
      ..sort((a, b) {
        final aDate = a.completedAt ?? a.createdAt;
        final bDate = b.completedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    int scopedStat(int singles, int team) => switch (_filter) {
      _ProfileMatchFilter.all => singles + team,
      _ProfileMatchFilter.singles => singles,
      _ProfileMatchFilter.team => team,
    };
    final scopeLabel = switch (_filter) {
      _ProfileMatchFilter.all => 'All cricket',
      _ProfileMatchFilter.singles => 'Singles',
      _ProfileMatchFilter.team => 'Team Match',
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Profile',
            subtitle: 'Your clean public cricket identity and permanent records.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  PlayerAvatar(player: player, radius: 48),
                  const SizedBox(height: 14),
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SelectableText(
                    player.id,
                    style: const TextStyle(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(label: Text(player.battingStyle.label)),
                      Chip(label: Text(gang?.name ?? 'Solo player')),
                      if (player.age != null) Chip(label: Text('Age ${player.age}')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    player.bowlingStyles.isEmpty
                        ? 'Bowling style not added'
                        : player.bowlingStyles.join(' • '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (player.bio != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      player.bio!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Joined CricXii • ${_joined(player.createdAt)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  if (player.instagramHandle != null ||
                      player.facebookUrl != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (player.instagramHandle != null)
                          ActionChip(
                            avatar: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: Text('@${player.instagramHandle}'),
                            onPressed: () => _openLink(
                              context,
                              player.instagramHandle!,
                              instagram: true,
                            ),
                          ),
                        if (player.facebookUrl != null)
                          ActionChip(
                            avatar: const Icon(Icons.facebook_rounded, size: 16),
                            label: const Text('Facebook'),
                            onPressed: () => _openLink(
                              context,
                              player.facebookUrl!,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _open(
                            context,
                            const ProfileEditScreen(),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit profile'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _open(
                            context,
                            const AccountSettingsScreen(),
                          ),
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Account'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text(
                    'Player management',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('Edit, remove or archive testing players'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(
                    context,
                    const PlayerManagementScreen(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.greenDark,
                  ),
                  title: const Text(
                    'CricXii account',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${store.accountEmail ?? 'No email'} • Player ID ${player.id}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(
                    context,
                    const AccountSettingsScreen(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8F0),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.insights_rounded, color: AppColors.greenDark),
              ),
              title: const Text(
                'Daily performance & PDF',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Review any day, mix Singles + Team Matches and export selected scorecards.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(context, const DailyPerformanceScreen()),
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<_ProfileMatchFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _ProfileMatchFilter.all,
                label: Text('All'),
              ),
              ButtonSegment(
                value: _ProfileMatchFilter.singles,
                label: Text('Singles'),
              ),
              ButtonSegment(
                value: _ProfileMatchFilter.team,
                label: Text('Team Match'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.single),
          ),
          const SizedBox(height: 18),
          SectionLabel(
            '$scopeLabel career stats',
            trailing: IconButton(
              tooltip: 'Refresh shared match history',
              onPressed: _refreshingHistory ? null : () => _refreshHistory(context),
              icon: _refreshingHistory
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricTile(
                label: 'Runs',
                value:
                    '${scopedStat(player.stats.runs, player.teamStats.runs)}',
                icon: Icons.show_chart_rounded,
              ),
              MetricTile(
                label: 'Points',
                value:
                    '${scopedStat(player.stats.points, player.teamStats.points)}',
                icon: Icons.bolt_rounded,
              ),
              MetricTile(
                label: 'Wickets',
                value:
                    '${scopedStat(player.stats.wickets, player.teamStats.wickets)}',
                icon: Icons.sports_baseball_rounded,
              ),
              MetricTile(
                label: 'Catches',
                value:
                    '${scopedStat(player.stats.catches, player.teamStats.catches)}',
                icon: Icons.back_hand_outlined,
              ),
              MetricTile(
                label: 'Matches',
                value:
                    '${scopedStat(player.stats.matches, player.teamStats.matches)}',
                icon: _filter == _ProfileMatchFilter.team
                    ? Icons.groups_2_rounded
                    : Icons.calendar_month_rounded,
              ),
              MetricTile(
                label: 'Wins',
                value:
                    '${scopedStat(player.stats.wins, player.teamStats.wins)}',
                icon: Icons.emoji_events_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionLabel('Records & history'),
          const SizedBox(height: 12),
          if (_filter == _ProfileMatchFilter.all) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SINGLES HISTORY',
                style: TextStyle(
                  color: AppColors.greenDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (history.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('No completed Singles matches yet'),
                ),
              )
            else
              ...history.map((match) => _singleHistoryCard(context, match)),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TEAM MATCH HISTORY',
                style: TextStyle(
                  color: Color(0xFFA56600),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (teamHistory.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.groups_2_outlined),
                  title: Text('No completed Team Matches yet'),
                ),
              )
            else
              ...teamHistory.map(
                (match) => _teamHistoryCard(context, match),
              ),
            if (store.hasOlderMatchHistory ||
                store.hasOlderTeamMatchHistory)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _loadingOlderHistory
                      ? null
                      : () => _loadOlderHistory(context),
                  icon: _loadingOlderHistory
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_rounded),
                  label: const Text('Load older history'),
                ),
              ),
          ] else if (_filter == _ProfileMatchFilter.team &&
              teamHistory.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.groups_2_outlined),
                title: Text('No completed Team Matches yet'),
              ),
            )
          else if (_filter == _ProfileMatchFilter.team) ...[
            ...teamHistory.map((match) => _teamHistoryCard(context, match)),
            if (store.hasOlderTeamMatchHistory)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _loadingOlderHistory ? null : () => _loadOlderHistory(context),
                  icon: _loadingOlderHistory
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.history_rounded),
                  label: const Text('Load older Team Matches'),
                ),
              ),
          ] else if (history.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('No completed Singles matches yet'),
              ),
            )
          else ...[
            ...history.map((match) => _singleHistoryCard(context, match)),
            if (store.hasOlderMatchHistory)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _loadingOlderHistory
                      ? null
                      : () => _loadOlderHistory(context),
                  icon: _loadingOlderHistory
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_rounded),
                  label: const Text('Load older matches'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
