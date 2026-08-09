import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  Future<void> _addFriend(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add by Player ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'TXP-XXXXXX'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().toUpperCase()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (id == null || !context.mounted) return;
    final store = AppScope.read(context);
    try {
      await store.addFriend(store.activePlayer!.id, id);
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activePlayer!;
    final friends = active.friendIds
        .map(store.playerById)
        .whereType<Player>()
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Friends',
            subtitle: 'Keep regular opponents ready without changing gangs.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _addFriend(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add with Player ID'),
          ),
          const SizedBox(height: 22),
          if (friends.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE1E9E4)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 40,
                    color: AppColors.greenDark,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No friends added yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Ask for their TXP Player ID.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            )
          else
            ...friends.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    leading: PlayerAvatar(player: player, showClaimState: true),
                    title: Text(
                      player.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text('${player.id} • ${player.stats.runs} runs'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
