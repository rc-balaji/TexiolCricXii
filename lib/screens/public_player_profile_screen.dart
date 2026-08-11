import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';

Future<void> openPlayerProfile(BuildContext context, String playerId) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicPlayerProfileScreen(playerId: playerId),
    ),
  );
}

class PublicPlayerProfileScreen extends StatelessWidget {
  const PublicPlayerProfileScreen({required this.playerId, super.key});

  final String playerId;

  Future<void> _openSocial(BuildContext context, String value, {bool instagram = false}) async {
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.playerById(playerId);
    final viewer = store.activePlayer;
    if (player == null) {
      return const Scaffold(body: Center(child: Text('Player not found')));
    }
    final friends = viewer != null && store.areFriends(viewer.id, player.id);
    final pendingRequest = viewer == null
        ? null
        : store.pendingRequestWith(player.id);
    final outgoingRequest = pendingRequest != null &&
        pendingRequest.fromPlayerId == viewer?.id;
    final incomingRequest = pendingRequest != null &&
        pendingRequest.toPlayerId == viewer?.id;
    final contacts = <(IconData, String, String?)>[
      (
        Icons.phone_outlined,
        'Phone',
        player.canViewField(
          'phone',
          viewerPlayerId: viewer?.id,
          areFriends: friends,
        )
            ? player.phoneNumber
            : null,
      ),
      (
        Icons.chat_outlined,
        'WhatsApp',
        player.canViewField(
          'whatsapp',
          viewerPlayerId: viewer?.id,
          areFriends: friends,
        )
            ? player.whatsappNumber
            : null,
      ),
      (
        Icons.location_on_outlined,
        'Place',
        player.canViewField(
          'location',
          viewerPlayerId: viewer?.id,
          areFriends: friends,
        )
            ? player.location
            : null,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Player profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  PlayerAvatar(player: player, radius: 46),
                  const SizedBox(height: 12),
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
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${player.battingStyle.label} • ${player.bowlingStyles.join(', ')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (player.age != null) ...[
                    const SizedBox(height: 8),
                    Chip(label: Text('Age ${player.age}')),
                  ],
                  if (player.bio != null) ...[
                    const SizedBox(height: 12),
                    Text(player.bio!, textAlign: TextAlign.center),
                  ],
                  if (viewer?.id != player.id) ...[
                    const SizedBox(height: 14),
                    if (friends)
                      FilledButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.people_rounded),
                        label: Text('Friends'),
                      )
                    else if (outgoingRequest)
                      FilledButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.schedule_send_rounded),
                        label: Text('Request sent'),
                      )
                    else if (incomingRequest)
                      FilledButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.notifications_active_outlined),
                        label: Text('Request received'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await AppScope.read(context).sendFriendRequestTo(
                              player.id,
                              knownPlayer: player,
                            );
                          } on Object catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$error'.replaceFirst('Bad state: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Send friend request'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Singles stats'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricTile(
                label: 'Matches',
                value: '${player.stats.matches}',
                icon: Icons.sports_cricket_rounded,
              ),
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
            ],
          ),
          const SizedBox(height: 18),
          if (player.instagramHandle != null || player.facebookUrl != null) ...[
            const SectionLabel('Social profiles'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (player.instagramHandle != null)
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined),
                      title: const Text('Instagram'),
                      subtitle: Text('@${player.instagramHandle}'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => _openSocial(
                        context,
                        player.instagramHandle!,
                        instagram: true,
                      ),
                    ),
                  if (player.facebookUrl != null)
                    ListTile(
                      leading: const Icon(Icons.facebook_rounded),
                      title: const Text('Facebook'),
                      subtitle: Text(
                        player.facebookUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => _openSocial(context, player.facebookUrl!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SectionLabel('Shared contact'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final contact in contacts)
                  if (contact.$3 != null && contact.$3!.isNotEmpty)
                    ListTile(
                      leading: Icon(contact.$1),
                      title: Text(contact.$2),
                      subtitle: SelectableText(contact.$3!),
                    ),
                if (contacts.every(
                  (contact) => contact.$3 == null || contact.$3!.isEmpty,
                ))
                  const ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('No contact details shared with you'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Opacity(
            opacity: .65,
            child: Card(
              child: ListTile(
                leading: Icon(Icons.groups_2_outlined),
                title: Text('Team match records'),
                subtitle: Text('Coming soon'),
                trailing: Chip(label: Text('SOON')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
