import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/match_planning.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/match_sync_indicator.dart';
import '../widgets/player_avatar.dart';
import 'live_match_screen.dart';
import 'match_summary_screen.dart';
import 'participant_match_watch_screen.dart';
import 'public_player_profile_screen.dart';

class QuickScoreScreen extends StatefulWidget {
  const QuickScoreScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<QuickScoreScreen> createState() => _QuickScoreScreenState();
}

class _QuickScoreScreenState extends State<QuickScoreScreen> {
  final _runs = TextEditingController();
  bool _isOut = false;
  bool _busy = false;
  DismissalType _dismissal = DismissalType.bowled;
  String? _bowlerId;
  String? _fielderOne;
  String? _fielderTwo;

  bool get _needsOneFielder => const {
    DismissalType.caught,
    DismissalType.runOutDirect,
    DismissalType.stumped,
  }.contains(_dismissal);

  bool get _needsTwoFielders => _dismissal == DismissalType.runOutAssisted;

  @override
  void dispose() {
    _runs.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final runs = int.tryParse(_runs.text.trim());
    if (runs == null || runs < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid runs total.')),
      );
      return;
    }
    if (_isOut && _needsOneFielder && _fielderOne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the fielder for this wicket.')),
      );
      return;
    }
    if (_isOut && _dismissal.creditsBowler && _bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the bowler for this dismissal.')),
      );
      return;
    }
    if (_isOut &&
        _needsTwoFielders &&
        (_fielderOne == null || _fielderTwo == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both fielders for the assisted run out.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final store = AppScope.read(context);
    try {
      await store.recordQuickTotal(
        widget.matchId,
        runs: runs,
        isOut: _isOut,
        dismissalType: _isOut ? _dismissal : DismissalType.none,
        bowlerId: _isOut ? _bowlerId : null,
        fielderIds: _isOut
            ? <String>[
                if (_dismissal == DismissalType.caughtAndBowled &&
                    _bowlerId != null)
                  _bowlerId!,
                if (_fielderOne != null) _fielderOne!,
                if (_fielderTwo != null) _fielderTwo!,
              ]
            : const [],
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
      _runs.clear();
      setState(() {
        _isOut = false;
        _dismissal = DismissalType.bowled;
        _bowlerId = null;
        _fielderOne = null;
        _fielderTwo = null;
      });
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

  Future<void> _undo() async {
    final changed = await AppScope.read(context).undoLast(widget.matchId);
    if (mounted && !changed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
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
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Match not found')));
    }
    if (!store.canControlMatch(match) && match.status != MatchStatus.completed) {
      return ParticipantMatchWatchScreen(matchId: match.id);
    }
    final hostControls = store.canHostMatch(match);
    final batterId = ScoringEngine.currentBatterId(match);
    final batter = store.playerById(batterId);
    if (batter == null) return MatchSummaryScreen(matchId: match.id);

    final players = match.participantIds
        .map(store.playerById)
        .whereType<Player>()
        .where((player) => player.id != batter.id)
        .toList();
    final playerIndex = match.battingOrder.indexOf(batter.id) + 1;
    final currentStats = ScoringEngine.calculateStats(match)[batter.id]!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.title),
            Text(
              '${match.id} • Direct runs',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          MatchSyncIndicator(matchId: match.id),
          IconButton(
            tooltip: 'Live ranking & match controls',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveMatchScreen(matchId: match.id),
              ),
            ),
            icon: const Icon(Icons.leaderboard_rounded),
          ),
          IconButton(
            tooltip: 'Undo last entry',
            onPressed: _busy ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'next' && hostControls) _sendNextPlayer();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'next',
                enabled: hostControls,
                child: const Text('Send next player first'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            GestureDetector(
              onTap: () => openPlayerProfile(context, batter.id),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    PlayerAvatar(player: batter, radius: 31),
                    const SizedBox(width: 14),
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
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
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
                          const SizedBox(height: 4),
                          Text(
                            OversFormat.setupOversLabel(match.ballLimit),
                            style: const TextStyle(
                              color: Color(0xFFB8CCC2),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currentStats.points} PTS',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${currentStats.wickets} WKTS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (match.autoBowlingPlan) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FIXED BOWLING PLAN',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...BowlingScheduler.blocksForBatter(match, batter.id)
                          .map((block) {
                            final bowler = store.playerById(block.bowlerId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '${block.legalBalls == 6 ? 'Over ${block.blockIndex + 1}' : 'Final ${block.legalBalls} balls'} • ${bowler?.name ?? block.bowlerId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }),
                      const SizedBox(height: 4),
                      Text(
                        '${OversFormat.setupOversLabel(match.ballLimit)} per batter • Direct runs stores the final total, while this plan helps the ground-side bowling order.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 6),
            TextField(
              controller: _runs,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                labelText: 'Final runs for this player',
                hintText: '0',
                prefixIcon: Icon(Icons.sports_score_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: _isOut,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _isOut = value;
                        _fielderOne = null;
                        _fielderTwo = null;
                      }),
                title: const Text(
                  'Player is out',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Keep this off for Not Out.'),
                secondary: Icon(
                  _isOut ? Icons.cancel_rounded : Icons.check_circle_rounded,
                  color: _isOut ? AppColors.danger : AppColors.greenDark,
                ),
              ),
            ),
            if (_isOut) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<DismissalType>(
                key: ValueKey('${batter.id}-dismissal'),
                initialValue: _dismissal,
                decoration: const InputDecoration(labelText: 'Dismissal'),
                items: DismissalType.values
                    .where((value) => value != DismissalType.none)
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _dismissal = value ?? DismissalType.bowled;
                  _fielderOne = null;
                  _fielderTwo = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('${batter.id}-${_dismissal.name}-bowler'),
                initialValue: _bowlerId,
                decoration: const InputDecoration(
                  labelText: 'Bowler (if applicable)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No bowler'),
                  ),
                  ...players.map(
                    (player) => DropdownMenuItem<String?>(
                      value: player.id,
                      child: Text(player.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _bowlerId = value),
              ),
              if (_needsOneFielder || _needsTwoFielders) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('${batter.id}-${_dismissal.name}-fielder-one'),
                  initialValue: _fielderOne,
                  decoration: InputDecoration(
                    labelText: _dismissal == DismissalType.stumped
                        ? 'Wicketkeeper'
                        : 'Fielder 1',
                  ),
                  items: players
                      .map(
                        (player) => DropdownMenuItem(
                          value: player.id,
                          child: Text(player.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _fielderOne = value;
                    if (_fielderTwo == value) _fielderTwo = null;
                  }),
                ),
              ],
              if (_needsTwoFielders) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${batter.id}-${_dismissal.name}-$_fielderOne-fielder-two',
                  ),
                  initialValue: _fielderTwo,
                  decoration: const InputDecoration(labelText: 'Fielder 2'),
                  items: players
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
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Save & next player'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Direct mode records only the player’s final runs and dismissal. Individual balls are not stored.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
