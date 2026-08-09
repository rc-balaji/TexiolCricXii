import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'profile_edit_screen.dart';
import 'register_player_dialog.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(Player player) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(playerId: player.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${player.name}?'),
        content: const Text(
          'If this player appears in completed match history, CricXii archives the profile instead of breaking the scorecard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await AppScope.read(context).deleteCachedPlayer(player.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted
                  ? 'Player removed.'
                  : player.accountUid != null
                  ? 'Claimed player hidden from this phone. Only that account owner can delete the account.'
                  : 'Player archived because match history uses this ID.',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final players = store.players
        .where((player) => player.id != store.activePlayerId)
        .where(
          (player) =>
              query.isEmpty ||
              player.name.toLowerCase().contains(query) ||
              player.id.contains(query),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Player management')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const ScreenTitle(
            title: 'Known players',
            subtitle:
                'These are independent opponents cached for matches. They are not switchable profiles under your account.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await showProvisionalPlayerRegistration(context);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Register someone without a phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search name or numeric ID',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 390,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E9E4)),
            ),
            child: players.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text(
                        'No cached players match this search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final canEdit = player.isProvisional ||
                          player.createdByPlayerId == store.activePlayerId;
                      return ListTile(
                        leading: PlayerAvatar(
                          player: player,
                          showClaimState: true,
                        ),
                        title: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${player.id} • ${player.archived ? 'Archived' : player.claimed ? 'Claimed' : 'Provisional'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _edit(player);
                            if (value == 'delete') _delete(player);
                          },
                          itemBuilder: (context) => [
                            if (canEdit)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit provisional profile'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Remove / archive'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            '${players.length} visible • Fixed-height scroll list',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
