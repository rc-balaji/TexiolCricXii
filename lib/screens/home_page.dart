import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/team_match.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import '../widgets/ui_bits.dart';
import 'create_match_screen.dart';
import 'create_team_match_screen.dart';
import 'match_summary_screen.dart';
import 'notifications_screen.dart';
import 'participant_match_watch_screen.dart';
import 'public_player_profile_screen.dart';
import 'quick_score_screen.dart';
import 'secret_draw_screen.dart';
import 'tracker_screen.dart';
import 'team_live_match_screen.dart';
import 'team_match_summary_screen.dart';
import 'team_match_watch_screen.dart';
import 'team_toss_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(AppScope.read(context).refreshMatches());
    }
  }

  void _openMatch(BuildContext context, CricketMatch match) {
    final store = AppScope.read(context);
    final canControl = store.canControlMatch(match);
    final page = !canControl && match.status != MatchStatus.completed
        ? ParticipantMatchWatchScreen(matchId: match.id)
        : switch (match.status) {
            MatchStatus.draft ||
            MatchStatus.drawing => SecretDrawScreen(matchId: match.id),
            MatchStatus.live =>
              match.scoringMode == ScoringMode.ballByBall
                  ? TrackerScreen(matchId: match.id)
                  : QuickScoreScreen(matchId: match.id),
            MatchStatus.completed => MatchSummaryScreen(matchId: match.id),
          };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openTeamMatch(BuildContext context, TeamMatch match) {
    final store = AppScope.read(context);
    final page = !store.canControlTeamMatch(match) &&
            match.status != TeamMatchStatus.completed
        ? TeamMatchWatchScreen(matchId: match.id)
        : switch (match.status) {
            TeamMatchStatus.toss => TeamTossScreen(matchId: match.id),
            TeamMatchStatus.live ||
            TeamMatchStatus.inningsBreak ||
            TeamMatchStatus.tieBreak =>
              TeamLiveMatchScreen(matchId: match.id),
            TeamMatchStatus.completed =>
              TeamMatchSummaryScreen(matchId: match.id),
          };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _cancelTeamMatch(BuildContext context, TeamMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this Team Match?'),
        content: Text(
          '${match.title} and its unfinished innings will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep match'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel & clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppScope.read(context).cancelTeamMatch(match.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfinished Team Match cleared.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _cancelMatch(BuildContext context, CricketMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this match?'),
        content: Text(
          '${match.title} will be cleared from Continue playing. Any unfinished score in this match will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep match'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel & clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.read(context).cancelMatch(match.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unfinished match cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.activePlayer!;
    final activeMatches = store.activeMatches;
    final activeTeamMatches = store.activeTeamMatches;
    final recent = <_RecentMatchItem>[
      for (final match in store.matches)
        if (match.status == MatchStatus.completed)
          _RecentMatchItem.singles(match),
      for (final match in store.teamMatches)
        if (match.status == TeamMatchStatus.completed)
          _RecentMatchItem.team(match),
    ]
      ..sort((a, b) => b.when.compareTo(a.when));
    final recentShown = recent.take(5).toList(growable: false);

    Widget createCard({
      required String eyebrow,
      required String title,
      required String description,
      required IconData icon,
      required Color background,
      required Color foreground,
      required String buttonLabel,
      required VoidCallback onPressed,
    }) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: foreground.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: foreground),
              ),
              const Spacer(),
              Text(
                eyebrow,
                style: TextStyle(
                  color: foreground.withValues(alpha: .78),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: foreground,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: foreground.withValues(alpha: .70),
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: foreground,
                foregroundColor: background == AppColors.ink
                    ? AppColors.ink
                    : Colors.white,
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );

    Widget recentCard(_RecentMatchItem item) {
      final singles = item.singles;
      if (singles != null) {
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8F0),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.sports_cricket_rounded, color: AppColors.greenDark),
            ),
            title: Text(singles.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('Singles • ${_whenLabel(item.when)}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openMatch(context, singles),
          ),
        );
      }
      final team = item.team!;
      return Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.groups_2_rounded, color: Color(0xFFA56600)),
          ),
          title: Text(team.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${team.teamA.name} vs ${team.teamB.name} • ${_whenLabel(item.when)}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openTeamMatch(context, team),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: store.refreshMatches,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => openPlayerProfile(context, player.id),
                  child: PlayerAvatar(player: player, radius: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CRICXII MATCH DAY',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => openPlayerProfile(context, player.id),
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Badge(
                  isLabelVisible: store.unreadNotificationCount > 0,
                  label: Text('${store.unreadNotificationCount}'),
                  child: IconButton.filledTonal(
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Player ID',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Your Player ID'),
                      content: SelectableText(
                        player.id,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Start a match',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Choose the format first. Scoring, reports and history stay inside that match.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final singles = createCard(
                  eyebrow: 'SINGLES',
                  title: 'Singles Match',
                  description: 'Secret batting order, Quick Score or ball-by-ball tracking.',
                  icon: Icons.sports_cricket_rounded,
                  background: AppColors.ink,
                  foreground: AppColors.green,
                  buttonLabel: 'Create Singles',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
                  ),
                );
                final team = createCard(
                  eyebrow: 'TEAM',
                  title: 'Team Match',
                  description: 'Flexible teams, live batter choice, toss and repeatable Super Overs.',
                  icon: Icons.groups_2_rounded,
                  background: const Color(0xFFFFF9EB),
                  foreground: const Color(0xFFA56600),
                  buttonLabel: 'Create Team Match',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateTeamMatchScreen()),
                  ),
                );
                if (constraints.maxWidth >= 620) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: singles),
                      const SizedBox(width: 12),
                      Expanded(child: team),
                    ],
                  );
                }
                return Column(
                  children: [
                    singles,
                    const SizedBox(height: 12),
                    team,
                  ],
                );
              },
            ),
            if (activeMatches.isNotEmpty || activeTeamMatches.isNotEmpty) ...[
              const SizedBox(height: 28),
              SectionLabel(
                'Continue playing',
                trailing: IconButton(
                  tooltip: 'Refresh participant matches',
                  onPressed: () => store.refreshMatches(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 10),
              ...activeMatches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 7),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE7F8F0),
                            foregroundColor: AppColors.greenDark,
                            child: Icon(Icons.sports_cricket_rounded),
                          ),
                          title: Text(match.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(
                            store.canControlMatch(match)
                                ? '${match.scoringMode.label} • ${store.isMatchSynced(match.id) ? 'Synced' : 'Waiting to sync'}'
                                : 'Participant watch • Read only',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openMatch(context, match),
                        ),
                        if (store.canHostMatch(match))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _cancelMatch(context, match),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel / clear'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ...activeTeamMatches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 7),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF4D8),
                            foregroundColor: Color(0xFFA56600),
                            child: Icon(Icons.groups_2_rounded),
                          ),
                          title: Text(match.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('${match.teamA.name} vs ${match.teamB.name}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TeamMatchSyncIndicator(matchId: match.id),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          onTap: () => _openTeamMatch(context, match),
                        ),
                        if (store.canHostTeamMatch(match))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _cancelTeamMatch(context, match),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel / clear'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const SectionLabel('Recent matches'),
            const SizedBox(height: 10),
            if (recentShown.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE1E9E4)),
                ),
                child: const Text(
                  'Your completed Singles and Team Matches will appear here.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              ...recentShown.map(recentCard),
          ],
        ),
      ),
    );
  }

  String _whenLabel(DateTime value) {
    final now = DateTime.now();
    final sameDay = value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
    if (sameDay) return 'Today, $time';
    return '${value.day}/${value.month}/${value.year} • $time';
  }

}

class _RecentMatchItem {
  const _RecentMatchItem.singles(CricketMatch value)
      : singles = value,
        team = null;

  const _RecentMatchItem.team(TeamMatch value)
      : singles = null,
        team = value;

  final CricketMatch? singles;
  final TeamMatch? team;

  DateTime get when {
    final singlesMatch = singles;
    if (singlesMatch != null) {
      return singlesMatch.completedAt ?? singlesMatch.createdAt;
    }
    final teamMatch = team;
    if (teamMatch != null) {
      return teamMatch.completedAt ?? teamMatch.createdAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
