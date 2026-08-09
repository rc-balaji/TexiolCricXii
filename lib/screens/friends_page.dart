import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'public_player_profile_screen.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).refreshSocialGraph();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find by Player ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Example: 100245',
            helperText: 'Numeric ID only',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (id == null || !mounted) return;
    try {
      await AppScope.read(context).sendFriendRequestTo(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _removeFriend(Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${player.name}?'),
        content: const Text(
          'Both players will stop seeing friend-only contact details. Match history is unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove friend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.read(context).removeFriend(player.id);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activePlayer!;
    final query = _search.text.trim().toLowerCase();
    final friends = active.friendIds
        .map(store.playerById)
        .whereType<Player>()
        .where(
          (player) =>
              query.isEmpty ||
              player.name.toLowerCase().contains(query) ||
              player.id.contains(query),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final requests = store.incomingFriendRequests;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Friends',
            subtitle:
                'Requests must be accepted. Both players then see each other and shared stats.',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _addFriend,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Send request with Player ID'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: store.refreshSocialGraph,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh social'),
            ),
          ),
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionLabel('Requests • ${requests.length}'),
            const SizedBox(height: 8),
            ...requests.map((request) {
              final sender = store.playerById(request.fromPlayerId);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: sender == null
                            ? const CircleAvatar(child: Icon(Icons.person))
                            : PlayerAvatar(player: sender),
                        title: Text(
                          sender?.name ?? request.fromPlayerId,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(request.fromPlayerId),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => store.respondToFriendRequest(
                                request.id,
                                accept: false,
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => store.respondToFriendRequest(
                                request.id,
                                accept: true,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 22),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search friends',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 390,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E9E4)),
            ),
            child: friends.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 40,
                            color: AppColors.greenDark,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No accepted friends yet',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final player = friends[index];
                      return ListTile(
                        leading: PlayerAvatar(player: player),
                        title: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${player.id} • ${player.stats.runs} runs • ${player.stats.points} pts',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'view') {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PublicPlayerProfileScreen(
                                    playerId: player.id,
                                  ),
                                ),
                              );
                            }
                            if (value == 'remove') _removeFriend(player);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'view',
                              child: Text('View profile'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove friend'),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicPlayerProfileScreen(
                              playerId: player.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
