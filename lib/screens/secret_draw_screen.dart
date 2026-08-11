import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'public_player_profile_screen.dart';
import 'quick_score_screen.dart';
import 'tracker_screen.dart';

class SecretDrawScreen extends StatefulWidget {
  const SecretDrawScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<SecretDrawScreen> createState() => _SecretDrawScreenState();
}

class _SecretDrawScreenState extends State<SecretDrawScreen> {
  bool _readyToChoose = false;
  bool _busy = false;

  Future<void> _choose(String playerId, String cardId) async {
    setState(() => _busy = true);
    final store = AppScope.read(context);
    try {
      final assignment = await store.chooseDrawCard(
        widget.matchId,
        playerId,
        cardId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Color(assignment.card.colorValue),
          title: const Text(
            'Your secret draw',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_off_rounded,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 18),
              Text(
                '#${assignment.card.order}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Remember it. Do not show the next player.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Hide & pass phone'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _readyToChoose = false);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset every selection?'),
        content: const Text(
          'All chosen cards will be cleared and a new draw will be generated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset draw'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await AppScope.read(context).resetDraw(widget.matchId);
      if (mounted) setState(() => _readyToChoose = false);
    }
  }

  Future<void> _start() async {
    final store = AppScope.read(context);
    await store.startMatch(widget.matchId);
    final match = store.matchById(widget.matchId)!;
    if (!mounted) return;
    final page = match.scoringMode == ScoringMode.ballByBall
        ? TrackerScreen(matchId: match.id)
        : QuickScoreScreen(matchId: match.id);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.matchById(widget.matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Match not found')));
    }
    final nextId = store.nextDrawPlayerId(match);
    final nextPlayer = store.playerById(nextId);
    final available = store.availableDrawCards(match);
    final drawComplete =
        match.battingOrder.length == match.participantIds.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(match.id),
        actions: [
          if (!drawComplete)
            IconButton(
              tooltip: 'Reset draw',
              onPressed: match.drawAssignments.isEmpty ? null : _reset,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: drawComplete
          ? _DrawResult(matchId: match.id, onStart: _start)
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                children: [
                  const ScreenTitle(
                    title: 'Secret order draw',
                    subtitle:
                        'Each player privately chooses one face-down card. The last card is assigned automatically.',
                  ),
                  const SizedBox(height: 22),
                  if (nextPlayer != null)
                    GestureDetector(
                      onTap: () => openPlayerProfile(context, nextPlayer.id),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          PlayerAvatar(
                            player: nextPlayer,
                            radius: 34,
                                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'PASS THE PHONE TO',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            nextPlayer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${match.drawAssignments.length + 1} of ${match.participantIds.length}',
                            style: const TextStyle(color: Color(0xFFB8CCC2)),
                          ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (!_readyToChoose)
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _readyToChoose = true),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('I am ready to choose'),
                    )
                  else ...[
                    const Center(
                      child: Text(
                        'Choose one card',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .72,
                          ),
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final card = available[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _busy || nextId == null
                              ? null
                              : () => _choose(nextId, card.id),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF163B2D), Color(0xFF071A13)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF3A6654),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sports_cricket,
                                  color: AppColors.green,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF8A5A00),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Previous colours and positions stay hidden until everyone finishes.',
                            style: TextStyle(
                              color: Color(0xFF6D4B0F),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DrawResult extends StatelessWidget {
  const _DrawResult({required this.matchId, required this.onStart});

  final String matchId;
  final VoidCallback onStart;

  Future<void> _adjustOrder(BuildContext context) async {
    final store = AppScope.read(context);
    final match = store.matchById(matchId)!;
    final order = List<String>.from(match.battingOrder);
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'Adjust batting order',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Drag players only when the ground situation requires it.',
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: order.length,
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = order.removeAt(oldIndex);
                        order.insert(newIndex, id);
                      });
                    },
                    itemBuilder: (context, index) {
                      final player = store.playerById(order[index])!;
                      return Card(
                        key: ValueKey(player.id),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(player.id),
                          trailing: const Icon(Icons.drag_handle_rounded),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, order),
                    child: const Text('Use this order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (updated != null && context.mounted) {
      await store.setBattingOrder(matchId, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.matchById(matchId)!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        children: [
          const ScreenTitle(
            title: 'Batting order',
            subtitle:
                'The secret draw is complete. Review the order before starting.',
          ),
          const SizedBox(height: 22),
          ...match.battingOrder.asMap().entries.map((entry) {
            final player = store.playerById(entry.value)!;
            final assignment = match.drawAssignments[player.id]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Color(assignment.card.colorValue),
                    foregroundColor: Colors.white,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  title: Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(player.id),
                  trailing: PlayerAvatar(player: player, radius: 20),
                  onTap: () => openPlayerProfile(context, player.id),
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _adjustOrder(context),
            icon: const Icon(Icons.swap_vert_rounded),
            label: const Text('Adjust order if needed'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Start ${match.ballLimit}-ball match'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => AppScope.read(context).resetDraw(matchId),
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Reset and draw again'),
          ),
        ],
      ),
    );
  }
}
