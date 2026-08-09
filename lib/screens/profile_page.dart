import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'match_summary_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _switchProfile(BuildContext context) async {
    final store = AppScope.read(context);
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          children: [
            const ListTile(
              title: Text(
                'Switch local profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Previously added profiles stay available on this device.',
              ),
            ),
            ...store.players.map(
              (player) => ListTile(
                leading: PlayerAvatar(player: player, showClaimState: true),
                title: Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(player.id),
                trailing: player.id == store.activePlayerId
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.greenDark,
                      )
                    : null,
                onTap: () => Navigator.pop(context, player.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null) await store.switchPlayer(id);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.activePlayer!;
    final gang = store.gangById(player.gangId);
    final history =
        store.matches
            .where(
              (match) =>
                  match.status == MatchStatus.completed &&
                  match.participantIds.contains(player.id),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(title: 'Player profile'),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  PlayerAvatar(
                    player: player,
                    radius: 42,
                    showClaimState: true,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    player.id,
                    style: const TextStyle(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        label: Text(
                          player.claimed
                              ? 'Claimed profile'
                              : 'Unclaimed profile',
                        ),
                      ),
                      Chip(label: Text(gang?.name ?? 'Solo player')),
                    ],
                  ),
                  if (player.instagramHandle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '@${player.instagramHandle}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _switchProfile(context),
                    icon: const Icon(Icons.switch_account_rounded),
                    label: const Text('Switch profile'),
                  ),
                ],
              ),
            ),
          ),
          if (store.firebaseEnabled) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  store.cloudConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: store.cloudConnected
                      ? AppColors.greenDark
                      : AppColors.muted,
                ),
                title: Text(
                  store.cloudConnected
                      ? 'Cloud backup connected'
                      : 'Offline session',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  store.cloudEmail ?? 'Scores remain on this phone',
                ),
                trailing: TextButton(
                  onPressed: store.cloudConnected
                      ? store.signOutCloud
                      : store.requestCloudSignIn,
                  child: Text(store.cloudConnected ? 'Sign out' : 'Sign in'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Career stats'),
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
                value: '${player.stats.runs}',
                icon: Icons.show_chart_rounded,
              ),
              MetricTile(
                label: 'Points',
                value: '${player.stats.points}',
                icon: Icons.bolt_rounded,
              ),
              MetricTile(
                label: 'Wickets',
                value: '${player.stats.wickets}',
                icon: Icons.sports_baseball_rounded,
              ),
              MetricTile(
                label: 'Catches',
                value: '${player.stats.catches}',
                icon: Icons.back_hand_outlined,
              ),
              MetricTile(
                label: 'Matches',
                value: '${player.stats.matches}',
                icon: Icons.calendar_month_rounded,
              ),
              MetricTile(
                label: 'Wins',
                value: '${player.stats.wins}',
                icon: Icons.emoji_events_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.speed_rounded),
                  title: const Text('Strike rate'),
                  trailing: Text(
                    player.stats.strikeRate.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.compare_arrows_rounded),
                  title: const Text('Run outs'),
                  trailing: Text(
                    '${player.stats.directRunOuts} direct • ${player.stats.assistedRunOuts} assists',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Match history'),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('No completed matches yet'),
                subtitle: Text('Finished Singles matches will stay here.'),
              ),
            )
          else
            ...history.map(
              (match) => Padding(
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
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MatchSummaryScreen(matchId: match.id),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sports_handball_outlined),
            title: const Text('Stumpings'),
            trailing: Text(
              '${player.stats.stumpings}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Not-out finishes'),
            trailing: Text(
              '${player.stats.matches - player.stats.outs}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
