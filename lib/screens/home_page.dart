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
import 'daily_performance_screen.dart';
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
            TeamMatchStatus.live || TeamMatchStatus.inningsBreak =>
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
                      'READY TO PLAY?',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
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
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF071A13), Color(0xFF103B2B)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SINGLES MATCH • STABLE',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Settle it on\nthe ground.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: .98,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add players, draw the secret batting order and track the match.',
                  style: TextStyle(color: Color(0xFFB8CCC2), height: 1.4),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateMatchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create singles match'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 112,
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Matches',
                    value: '${player.stats.matches}',
                    icon: Icons.sports_cricket_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: 'Runs',
                    value: '${player.stats.runs}',
                    icon: Icons.show_chart_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: 'Points',
                    value: '${player.stats.points}',
                    icon: Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
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
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.greenDark,
                ),
              ),
              title: const Text(
                "Today's performance",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Overall ranking, match timeline and performance PDF for any date.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DailyPerformanceScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          SectionLabel(
            'Continue playing',
            trailing: IconButton(
              tooltip: 'Refresh participant matches',
              onPressed: () => store.refreshMatches(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (activeMatches.isEmpty && activeTeamMatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E9E4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.greenDark,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No unfinished matches. Create one when the gang is ready.',
                      style: TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else
            ...activeMatches.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.sports_cricket,
                            color: AppColors.greenDark,
                          ),
                        ),
                        title: Text(
                          match.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          store.canControlMatch(match)
                              ? '${match.id}  •  ${store.isMatchTracker(match) && !store.isMatchHost(match) ? 'Tracker controls' : 'Host controls'}  •  ${store.isMatchSynced(match.id) ? 'Synced' : 'Waiting to sync'}  •  ${match.scoringMode.label}'
                              : '${match.id}  •  Hosted by ${store.playerById(match.creatorPlayerId)?.name ?? match.creatorPlayerId}  •  Read only',
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => _openMatch(context, match),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _openMatch(context, match),
                                icon: Icon(
                                  store.canControlMatch(match)
                                      ? Icons.play_arrow_rounded
                                      : Icons.visibility_rounded,
                                ),
                                label: Text(
                                  store.canControlMatch(match) ? 'Resume' : 'Watch',
                                ),
                              ),
                            ),
                            if (store.canHostMatch(match)) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => _cancelMatch(context, match),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Cancel / clear'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D8),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.groups_2_rounded, color: Color(0xFFA56600)),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (match.commonJokerPlayerId != null)
                            const Text('🃏', style: TextStyle(fontSize: 17)),
                        ],
                      ),
                      subtitle: Text(
                        '${match.teamA.name} vs ${match.teamB.name} • ${match.id}\n'
                        '${store.canControlTeamMatch(match) ? (store.isTeamMatchTracker(match) && !store.isTeamMatchHost(match) ? 'Scorer controls' : 'Host controls') : 'Participant watch'}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TeamMatchSyncIndicator(matchId: match.id),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        ],
                      ),
                      onTap: () => _openTeamMatch(context, match),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _openTeamMatch(context, match),
                              icon: Icon(
                                store.canControlTeamMatch(match)
                                    ? Icons.play_arrow_rounded
                                    : Icons.visibility_rounded,
                              ),
                              label: Text(
                                store.canControlTeamMatch(match) ? 'Resume Team Match' : 'Watch',
                              ),
                            ),
                          ),
                          if (store.canHostTeamMatch(match)) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _cancelTeamMatch(context, match),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Cancel / clear'),
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFFFF9EB),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.groups_2_rounded, color: Color(0xFFA56600)),
                      SizedBox(width: 9),
                      Text('TEAM MATCH • V1.4', style: TextStyle(color: Color(0xFFA56600), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Pick players. Choose the start. Play.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('Players-first teams, optional Joker, timed/manual/no toss, bowling limits and linked rematches.', style: TextStyle(color: AppColors.muted, height: 1.35)),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateTeamMatchScreen()),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Team Match'),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
