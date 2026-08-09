import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'match_summary_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  String? _bowlerId;
  bool _busy = false;

  Future<void> _record({
    required int batRuns,
    int extraRuns = 0,
    ExtraType extraType = ExtraType.none,
    bool legalBall = true,
    bool isOut = false,
    DismissalType dismissalType = DismissalType.none,
    String? bowlerId,
    List<String> fielderIds = const [],
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = AppScope.read(context);
    final before = store.matchById(widget.matchId)!;
    final previousBatter = ScoringEngine.currentBatterId(before);
    try {
      await store.recordDelivery(
        widget.matchId,
        batRuns: batRuns,
        extraRuns: extraRuns,
        extraType: extraType,
        legalBall: legalBall,
        isOut: isOut,
        dismissalType: dismissalType,
        bowlerId: bowlerId ?? _bowlerId,
        fielderIds: fielderIds,
      );
      if (!mounted) return;
      final match = store.matchById(widget.matchId)!;
      if (match.status == MatchStatus.completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchSummaryScreen(matchId: match.id),
          ),
        );
        return;
      }
      final next = ScoringEngine.currentBatterId(match);
      if (next != previousBatter) {
        final nextPlayer = store.playerById(next);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turn complete. Next: ${nextPlayer?.name ?? ''}'),
          ),
        );
        _bowlerId = null;
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wicket(CricketMatch match, List<Player> fielders) async {
    final batterId = ScoringEngine.currentBatterId(match);
    if (batterId == null) return;
    final details = await showModalBottomSheet<_DismissalDetails>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _WicketSheet(players: fielders, initialBowlerId: _bowlerId),
    );
    if (details == null || !mounted) return;
    _bowlerId = details.bowlerId;
    await _record(
      batRuns: details.runs,
      isOut: true,
      dismissalType: details.type,
      bowlerId: details.bowlerId,
      fielderIds: details.fielderIds,
    );
  }

  Future<void> _undo() async {
    final changed = await AppScope.read(context).undoLast(widget.matchId);
    if (mounted && !changed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
    }
  }

  Future<void> _resetTurn() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this player’s turn?'),
        content: const Text(
          'Every tracked ball for the current batter will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset turn'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await AppScope.read(context).resetCurrentTurn(widget.matchId);
    }
  }

  Future<void> _sendNextPlayer() async {
    try {
      await AppScope.read(context).moveCurrentBatterToEnd(widget.matchId);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.matchById(widget.matchId);
    if (match == null)
      return const Scaffold(body: Center(child: Text('Match not found')));
    final batterId = ScoringEngine.currentBatterId(match);
    final batter = store.playerById(batterId);
    if (batter == null) {
      return MatchSummaryScreen(matchId: match.id);
    }
    final players = match.participantIds
        .map(store.playerById)
        .whereType<Player>()
        .toList();
    final possibleBowlers = players
        .where((player) => player.id != batter.id)
        .toList();
    final effectiveBowler =
        possibleBowlers.any((player) => player.id == _bowlerId)
        ? _bowlerId
        : possibleBowlers.isEmpty
        ? null
        : possibleBowlers.first.id;
    final turn = ScoringEngine.rebuildTurns(match)[batter.id]!;
    final turnEvents = match.events
        .where((event) => event.batterId == batter.id)
        .toList();
    final playerIndex = match.battingOrder.indexOf(batter.id) + 1;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            Text(
              match.id,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9DB4A9)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Undo last ball',
            onPressed: _busy ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _resetTurn();
              if (value == 'next') _sendNextPlayer();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset current turn')),
              PopupMenuItem(
                value: 'next',
                child: Text('Send next player first'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  PlayerAvatar(player: batter, radius: 31),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BATTER $playerIndex OF ${match.battingOrder.length}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        Text(
                          batter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${turn.runs}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: .95,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${turn.legalBalls}/${match.ballLimit} balls',
                        style: const TextStyle(
                          color: Color(0xFF9DB4A9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  children: [
                    if (possibleBowlers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey('${batter.id}-bowler'),
                        initialValue: effectiveBowler,
                        decoration: const InputDecoration(
                          labelText: 'Current bowler',
                          prefixIcon: Icon(Icons.sports_baseball_rounded),
                        ),
                        items: possibleBowlers
                            .map(
                              (player) => DropdownMenuItem(
                                value: player.id,
                                child: Text(player.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _bowlerId = value),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'RUNS THIS BALL',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: 1.25,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final run in const [0, 1, 2, 3, 4, 5, 6])
                          _ScoreButton(
                            label: '$run',
                            accent: run == 4 || run == 6,
                            onTap: _busy
                                ? null
                                : () => _record(
                                    batRuns: run,
                                    bowlerId: effectiveBowler,
                                  ),
                          ),
                        _ScoreButton(
                          label: 'OUT',
                          danger: true,
                          onTap: _busy
                              ? null
                              : () => _wicket(match, possibleBowlers),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _record(
                                    batRuns: 0,
                                    extraRuns: 1,
                                    extraType: ExtraType.wide,
                                    legalBall: false,
                                    bowlerId: effectiveBowler,
                                  ),
                            child: const Text('Wide +1'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _record(
                                    batRuns: 0,
                                    extraRuns: 1,
                                    extraType: ExtraType.noBall,
                                    legalBall: false,
                                    bowlerId: effectiveBowler,
                                  ),
                            child: const Text('No ball +1'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'THIS TURN',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                        Text(
                          '${turn.extras} extras',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (turnEvents.isEmpty)
                      const Text(
                        'No balls tracked yet.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    else
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: turnEvents.asMap().entries.map((entry) {
                          final event = entry.value;
                          return Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: event.isOut
                                  ? const Color(0xFFFFE5E7)
                                  : event.extraType != ExtraType.none
                                  ? const Color(0xFFFFF1D4)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: const Color(0xFFDCE6E0),
                              ),
                            ),
                            child: Text(
                              _eventLabel(event),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: event.isOut
                                    ? AppColors.danger
                                    : AppColors.ink,
                              ),
                            ),
                          );
                        }).toList(),
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

  String _eventLabel(ScoreEvent event) {
    if (event.isOut) return 'W';
    if (event.extraType == ExtraType.wide) return 'Wd';
    if (event.extraType == ExtraType.noBall) return 'Nb';
    return '${event.batRuns}';
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.label,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
    color: danger
        ? AppColors.danger
        : accent
        ? AppColors.green
        : Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: danger || accent
                ? Colors.transparent
                : const Color(0xFFD8E3DD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: danger ? Colors.white : AppColors.ink,
            fontSize: label == 'OUT' ? 14 : 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _DismissalDetails {
  const _DismissalDetails({
    required this.type,
    required this.runs,
    this.bowlerId,
    this.fielderIds = const [],
  });

  final DismissalType type;
  final int runs;
  final String? bowlerId;
  final List<String> fielderIds;
}

class _WicketSheet extends StatefulWidget {
  const _WicketSheet({required this.players, required this.initialBowlerId});

  final List<Player> players;
  final String? initialBowlerId;

  @override
  State<_WicketSheet> createState() => _WicketSheetState();
}

class _WicketSheetState extends State<_WicketSheet> {
  DismissalType _type = DismissalType.bowled;
  String? _bowlerId;
  String? _fielderOne;
  String? _fielderTwo;
  int _runs = 0;

  @override
  void initState() {
    super.initState();
    _bowlerId =
        widget.initialBowlerId ??
        (widget.players.isEmpty ? null : widget.players.first.id);
  }

  bool get _needsOneFielder => const {
    DismissalType.caught,
    DismissalType.runOutDirect,
    DismissalType.stumped,
  }.contains(_type);

  bool get _needsTwoFielders => _type == DismissalType.runOutAssisted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record wicket',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DismissalType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'How was the player out?',
            ),
            items: DismissalType.values
                .where((value) => value != DismissalType.none)
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _type = value ?? DismissalType.bowled;
              _fielderOne = null;
              _fielderTwo = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _bowlerId,
            decoration: const InputDecoration(labelText: 'Bowler on this ball'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('No bowler selected'),
              ),
              ...widget.players.map(
                (player) => DropdownMenuItem(
                  value: player.id,
                  child: Text(player.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _bowlerId = value),
          ),
          if (_needsOneFielder || _needsTwoFielders) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('${_type.name}-fielder-one'),
              initialValue: _fielderOne,
              decoration: InputDecoration(
                labelText: _type == DismissalType.stumped
                    ? 'Wicketkeeper'
                    : 'Fielder 1',
              ),
              items: widget.players
                  .map(
                    (player) => DropdownMenuItem(
                      value: player.id,
                      child: Text(player.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _fielderOne = value),
            ),
          ],
          if (_needsTwoFielders) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('${_type.name}-$_fielderOne-fielder-two'),
              initialValue: _fielderTwo,
              decoration: const InputDecoration(labelText: 'Fielder 2'),
              items: widget.players
                  .where((player) => player.id != _fielderOne)
                  .map(
                    (player) => DropdownMenuItem(
                      value: player.id,
                      child: Text(player.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _fielderTwo = value),
            ),
          ],
          if (_type == DismissalType.runOutDirect ||
              _type == DismissalType.runOutAssisted) ...[
            const SizedBox(height: 16),
            const Text(
              'Runs completed before run out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('0')),
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_runs},
              onSelectionChanged: (value) =>
                  setState(() => _runs = value.single),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                (_type.creditsBowler && _bowlerId == null) ||
                    (_needsOneFielder && _fielderOne == null) ||
                    (_needsTwoFielders &&
                        (_fielderOne == null || _fielderTwo == null))
                ? null
                : () {
                    final fielders = <String>[
                      if (_type == DismissalType.caughtAndBowled &&
                          _bowlerId != null)
                        _bowlerId!,
                      if (_fielderOne != null) _fielderOne!,
                      if (_fielderTwo != null) _fielderTwo!,
                    ];
                    Navigator.pop(
                      context,
                      _DismissalDetails(
                        type: _type,
                        runs: _runs,
                        bowlerId: _bowlerId,
                        fielderIds: fielders,
                      ),
                    );
                  },
            icon: const Icon(Icons.sports_cricket_rounded),
            label: const Text('Confirm wicket'),
          ),
        ],
      ),
    ),
  );
}
