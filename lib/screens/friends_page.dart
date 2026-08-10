import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../domain/social.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'notifications_screen.dart';
import 'public_player_profile_screen.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _playerIdSearch = TextEditingController();
  final _friendFilter = TextEditingController();
  Player? _searchResult;
  bool _searching = false;
  bool _sending = false;

  @override
  void dispose() {
    _playerIdSearch.dispose();
    _friendFilter.dispose();
    super.dispose();
  }

  Future<void> _findPlayer() async {
    final id = _playerIdSearch.text.trim();
    if (!RegExp(r'^\d{6,}$').hasMatch(id)) {
      _message('Enter a numeric Player ID with at least 6 digits.');
      return;
    }
    setState(() {
      _searching = true;
      _searchResult = null;
    });
    try {
      final player = await AppScope.read(context).findPublicPlayer(id);
      if (!mounted) return;
      setState(() => _searchResult = player);
      if (player == null) _message('No player found for ID $id.');
    } on Object catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(Player player) async {
    setState(() => _sending = true);
    try {
      await AppScope.read(
        context,
      ).sendFriendRequestTo(player.id, knownPlayer: player);
      if (mounted) {
        setState(() {});
        _message('Friend request sent to ${player.name}.');
      }
    } on Object catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _sending = false);
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
      if (mounted) _message('$error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activePlayer!;
    final filter = _friendFilter.text.trim().toLowerCase();
    final friends = active.friendIds
        .map(store.playerById)
        .whereType<Player>()
        .where(
          (player) =>
              filter.isEmpty ||
              player.name.toLowerCase().contains(filter) ||
              player.id.contains(filter),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final incoming = store.incomingFriendRequests;
    final outgoing = store.outgoingFriendRequests;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Friends',
            subtitle:
                'Search an exact Player ID, send a request, then manage incoming requests from Notifications.',
          ),
          const SizedBox(height: 18),
          _FindPlayerCard(
            controller: _playerIdSearch,
            searching: _searching,
            onSearch: _findPlayer,
          ),
          if (_searchResult != null) ...[
            const SizedBox(height: 10),
            _SearchResultCard(
              player: _searchResult!,
              activePlayerId: active.id,
              areFriends: active.friendIds.contains(_searchResult!.id),
              pendingRequest: store.pendingRequestWith(_searchResult!.id),
              sending: _sending,
              onSend: () => _sendRequest(_searchResult!),
              onView: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PublicPlayerProfileScreen(
                    playerId: _searchResult!.id,
                  ),
                ),
              ),
            ),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Badge(
                  label: Text('${incoming.length}'),
                  child: const Icon(Icons.notifications_active_outlined),
                ),
                title: const Text(
                  'New friend request',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Open Notifications to accept or reject. Use Refresh there when the app is already open.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
            ),
          ],
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionLabel('Sent requests • ${outgoing.length}'),
            const SizedBox(height: 8),
            ...outgoing.map((request) {
              final player = store.playerById(request.toPlayerId);
              return Card(
                child: ListTile(
                  leading: player == null
                      ? const CircleAvatar(child: Icon(Icons.person_outline))
                      : PlayerAvatar(player: player),
                  title: Text(
                    player?.name ?? request.toPlayerId,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('Player ID ${request.toPlayerId}'),
                  trailing: const _PendingPill(),
                ),
              );
            }),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: SectionLabel('Accepted friends')),
              Text(
                '${friends.length}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _friendFilter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Filter accepted friends',
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
                          SizedBox(height: 5),
                          Text(
                            'Search a Player ID above to send your first request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
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

class _FindPlayerCard extends StatelessWidget {
  const _FindPlayerCard({
    required this.controller,
    required this.searching,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.greenDark),
              SizedBox(width: 8),
              Text(
                'Find a player',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Exact Player ID search keeps Firestore reads low.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (!searching) onSearch();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Player ID',
                    hintText: 'Example: 18450231',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: searching ? null : onSearch,
                  child: searching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.player,
    required this.activePlayerId,
    required this.areFriends,
    required this.pendingRequest,
    required this.sending,
    required this.onSend,
    required this.onView,
  });

  final Player player;
  final String activePlayerId;
  final bool areFriends;
  final FriendRequest? pendingRequest;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final isSelf = player.id == activePlayerId;
    final outgoing = pendingRequest != null &&
        pendingRequest.fromPlayerId == activePlayerId;
    final incoming = pendingRequest != null &&
        pendingRequest.toPlayerId == activePlayerId;

    String buttonText = 'Send request';
    IconData buttonIcon = Icons.person_add_alt_1_rounded;
    bool enabled = !sending;
    if (isSelf) {
      buttonText = 'This is you';
      buttonIcon = Icons.person_rounded;
      enabled = false;
    } else if (areFriends) {
      buttonText = 'Friends';
      buttonIcon = Icons.people_rounded;
      enabled = false;
    } else if (outgoing) {
      buttonText = 'Request sent';
      buttonIcon = Icons.schedule_send_rounded;
      enabled = false;
    } else if (incoming) {
      buttonText = 'Request received';
      buttonIcon = Icons.notifications_active_outlined;
      enabled = false;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PlayerAvatar(player: player, radius: 28),
              title: Text(
                player.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Player ID ${player.id}\n${player.stats.runs} runs • ${player.stats.wins} wins',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'View profile',
                onPressed: onView,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onSend : null,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(buttonIcon),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPill extends StatelessWidget {
  const _PendingPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D8),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'Pending',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}
