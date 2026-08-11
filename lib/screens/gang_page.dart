import 'package:flutter/material.dart';
import 'public_player_profile_screen.dart';

import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'register_player_dialog.dart';

class GangPage extends StatelessWidget {
  const GangPage({super.key});

  Future<void> _createGang(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create your gang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Gang name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.length < 2 || !context.mounted) return;
    try {
      await AppScope.read(context).createGang(name);
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addPlayer(BuildContext context, String gangId) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add gang member'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'existing'),
            child: const ListTile(
              leading: Icon(Icons.badge_outlined),
              title: Text('Use existing Player ID'),
              subtitle: Text('For a profile already available on this phone.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'create'),
            child: const ListTile(
              leading: Icon(Icons.person_add_alt_1_rounded),
              title: Text('Create player account'),
              subtitle: Text('Create a new Player ID with email and password.'),
            ),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'existing') {
      final controller = TextEditingController();
      final playerId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Existing Player ID'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Numeric Player ID',
              hintText: '18450231',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (playerId == null || !context.mounted) return;
      final store = AppScope.read(context);
      final player = await store.findPlayer(playerId);
      if (!context.mounted) return;
      if (player == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No player found with that numeric Player ID.'),
          ),
        );
        return;
      }
      try {
        await store.addPlayerToGang(gangId, player.id);
      } on StateError catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
      return;
    }

    final created = await showPlayerAccountRegistration(context);
    if (created == null || !context.mounted) return;
    await AppScope.read(context).addPlayerToGang(gangId, created.player.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activePlayer!;
    final gang = store.gangById(active.gangId);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Your gang',
            subtitle:
                'One home gang per player. You can still play with anyone.',
          ),
          const SizedBox(height: 22),
          if (gang == null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: AppColors.green,
                    size: 38,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Build your local\ncricket identity.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The creator becomes Leader. Add co-leaders and members after creation.',
                    style: TextStyle(color: Color(0xFFB8CCC2), height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: () => _createGang(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create gang'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.ink,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gang.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          gang.id,
                          style: const TextStyle(
                            color: Color(0xFFB8CCC2),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active.gangRole?.label.toUpperCase() ?? 'MEMBER',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionLabel(
              '${gang.members.length} members',
              trailing: TextButton.icon(
                onPressed: active.gangRole == GangRole.member
                    ? null
                    : () => _addPlayer(context, gang.id),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: 10),
            ...gang.members.entries.map((entry) {
              final player = store.playerById(entry.key);
              if (player == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    leading: PlayerAvatar(player: player),
                    title: Text(
                      player.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text('${player.id} • ${entry.value.label}'),
                    onTap: () => openPlayerProfile(context, player.id),
                    trailing:
                        active.gangRole == GangRole.leader &&
                            player.id != active.id
                        ? PopupMenuButton<GangRole>(
                            onSelected: (role) =>
                                store.setGangRole(gang.id, player.id, role),
                            itemBuilder: (context) => [
                              if (entry.value == GangRole.member)
                                const PopupMenuItem(
                                  value: GangRole.coLeader,
                                  child: Text('Promote to co-leader'),
                                ),
                              if (entry.value == GangRole.coLeader) ...[
                                const PopupMenuItem(
                                  value: GangRole.member,
                                  child: Text('Change to member'),
                                ),
                                const PopupMenuItem(
                                  value: GangRole.leader,
                                  child: Text('Transfer leadership'),
                                ),
                              ],
                            ],
                          )
                        : null,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
