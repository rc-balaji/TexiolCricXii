import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'create_match_screen.dart';
import 'match_summary_screen.dart';
import 'notifications_screen.dart';
import 'public_player_profile_screen.dart';
import 'quick_score_screen.dart';
import 'secret_draw_screen.dart';
import 'tracker_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openMatch(BuildContext context, CricketMatch match) {
    final page = switch (match.status) {
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.activePlayer!;
    final activeMatches = store.activeMatches;
    return SafeArea(
      child: ListView(
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
                    'SINGLES MATCH • V1',
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
          const SizedBox(height: 26),
          const SectionLabel('Continue playing'),
          const SizedBox(height: 12),
          if (activeMatches.isEmpty)
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
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
                      '${match.id}  •  ${match.scoringMode.label}  •  ${match.ballLimit} balls',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () => _openMatch(context, match),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Opacity(
            opacity: .62,
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.groups_2_outlined),
                title: const Text(
                  'Team Match',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Planned for a future update'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
