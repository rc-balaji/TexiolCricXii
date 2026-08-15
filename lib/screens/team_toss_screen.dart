import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/team_match.dart';
import '../domain/team_scoring_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/team_match_sync_indicator.dart';
import 'team_live_match_screen.dart';

class TeamTossScreen extends StatefulWidget {
  const TeamTossScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<TeamTossScreen> createState() => _TeamTossScreenState();
}

class _TeamTossScreenState extends State<TeamTossScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tossTimer;
  TeamTossMode? _mode;
  String? _tosserTeamId;
  String? _manualWinnerTeamId;
  String? _firstBattingTeamId;
  TeamTossCall? _call;
  TeamTossCall? _hiddenResult;
  TeamTossDecision _decision = TeamTossDecision.bat;
  String? _openingBowlerId;
  bool _callMissed = false;
  bool _revealed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _tossTimer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener(_onTossStatus);
  }

  @override
  void dispose() {
    _tossTimer
      ..removeStatusListener(_onTossStatus)
      ..dispose();
    super.dispose();
  }

  void _onTossStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      if (_call == null) {
        _callMissed = true;
        _revealed = false;
      } else {
        _callMissed = false;
        _revealed = true;
      }
      _openingBowlerId = null;
    });
  }

  void _clearOutcome() {
    _tossTimer.reset();
    _call = null;
    _hiddenResult = null;
    _callMissed = false;
    _revealed = false;
    _openingBowlerId = null;
  }

  void _selectMode(
    TeamTossMode mode, {
    String? previousWinnerTeamId,
  }) {
    if (_tossTimer.isAnimating) return;
    setState(() {
      _clearOutcome();
      _mode = mode;
      _decision = TeamTossDecision.bat;
      _manualWinnerTeamId = switch (mode) {
        TeamTossMode.manual => null,
        TeamTossMode.previousWinnerChoice => previousWinnerTeamId,
        _ => null,
      };
      _firstBattingTeamId = null;
    });
  }

  void _startToss() {
    if (_tosserTeamId == null || _tossTimer.isAnimating) {
      if (_tosserTeamId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose which team flips the coin.')),
        );
      }
      return;
    }
    setState(() {
      _call = null;
      _hiddenResult = Random.secure().nextBool()
          ? TeamTossCall.heads
          : TeamTossCall.tails;
      _callMissed = false;
      _revealed = false;
      _openingBowlerId = null;
    });
    _tossTimer.forward(from: 0);
  }

  void _selectCall(TeamTossCall call) {
    if (!_tossTimer.isAnimating || _call != null) return;
    setState(() => _call = call);
  }

  void _restartToss() {
    _clearOutcome();
    _startToss();
  }

  void _startOver() {
    if (_tossTimer.isAnimating) return;
    setState(() {
      _clearOutcome();
      _mode = null;
      _tosserTeamId = null;
      _manualWinnerTeamId = null;
      _firstBattingTeamId = null;
      _decision = TeamTossDecision.bat;
    });
  }

  String? _inAppWinnerId(TeamMatch match) {
    if (!_revealed ||
        _tosserTeamId == null ||
        _call == null ||
        _hiddenResult == null) {
      return null;
    }
    final caller = match.otherSide(_tosserTeamId!).id;
    return _call == _hiddenResult ? caller : _tosserTeamId;
  }

  String? _winnerId(TeamMatch match) {
    if (_mode == TeamTossMode.inApp) return _inAppWinnerId(match);
    if (_mode == TeamTossMode.manual ||
        _mode == TeamTossMode.previousWinnerChoice) {
      return _manualWinnerTeamId;
    }
    return null;
  }

  String? _resolvedFirstBattingTeamId(TeamMatch match) {
    if (_mode == TeamTossMode.skipped) return _firstBattingTeamId;
    final winnerId = _winnerId(match);
    if (winnerId == null) return null;
    return _decision == TeamTossDecision.bat
        ? winnerId
        : match.otherSide(winnerId).id;
  }

  List<String> _availableOpeningBowlers(TeamMatch match) {
    final battingId = _resolvedFirstBattingTeamId(match);
    if (battingId == null) return const [];
    final batting = match.side(battingId);
    final bowling = match.otherSide(batting.id);
    final openingBatters = batting.battingOrder.take(2).toSet();
    final required = min(match.rules.ballsPerOver, match.rules.ballLimit);
    return bowling.playerIds
        .where(
          (id) =>
              !openingBatters.contains(id) &&
              (bowling.bowlingQuotaBalls[id] ?? 0) >= required,
        )
        .toList(growable: false);
  }

  Future<void> _start(TeamMatch match) async {
    final mode = _mode;
    final firstBattingTeamId = _resolvedFirstBattingTeamId(match);
    final bowler = _openingBowlerId;
    if (mode == null ||
        firstBattingTeamId == null ||
        bowler == null ||
        _starting) {
      return;
    }
    final winnerId = _winnerId(match);
    final callerId = _tosserTeamId == null
        ? null
        : match.otherSide(_tosserTeamId!).id;
    setState(() => _starting = true);
    try {
      await AppScope.read(context).startTeamMatchAfterToss(
        match.id,
        toss: TeamToss(
          mode: mode,
          tosserTeamId: mode == TeamTossMode.inApp
              ? _tosserTeamId
              : null,
          callerTeamId: mode == TeamTossMode.inApp ? callerId : null,
          call: mode == TeamTossMode.inApp ? _call : null,
          result: mode == TeamTossMode.inApp ? _hiddenResult : null,
          winnerTeamId: winnerId,
          decision: mode == TeamTossMode.skipped ? null : _decision,
          firstBattingTeamId: firstBattingTeamId,
          createdAt: DateTime.now(),
        ),
        openingBowlerId: bowler,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TeamLiveMatchScreen(matchId: match.id),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final match = store.teamMatchById(widget.matchId);
    if (match == null) {
      return const Scaffold(body: Center(child: Text('Team Match not found')));
    }
    if (match.status != TeamMatchStatus.toss) {
      return TeamLiveMatchScreen(matchId: match.id);
    }

    final previous = match.previousMatchId == null
        ? null
        : store.teamMatchById(match.previousMatchId!);
    final previousWinnerId = previous == null
        ? null
        : TeamScoringEngine.result(previous).winnerTeamId;
    final firstBattingId = _resolvedFirstBattingTeamId(match);
    final batting = firstBattingId == null ? null : match.side(firstBattingId);
    final bowling = batting == null ? null : match.otherSide(batting.id);
    final bowlers = _availableOpeningBowlers(match);
    if (_openingBowlerId != null && !bowlers.contains(_openingBowlerId)) {
      _openingBowlerId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Match Start'),
        actions: [TeamMatchSyncIndicator(matchId: match.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          Text(
            match.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${match.teamA.name} vs ${match.teamB.name} • '
            '${match.rules.ballLimit ~/ match.rules.ballsPerOver} overs',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Text(
            'How should this match start?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toss is optional. Choose the method that matches what happened on the ground.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _StartModeTile(
            selected: _mode == TeamTossMode.inApp,
            enabled: !_tossTimer.isAnimating,
            icon: Icons.casino_rounded,
            title: 'In-app timed toss',
            subtitle: 'Choose the flipping team. The other team calls during a 3-second spin.',
            onTap: () => _selectMode(TeamTossMode.inApp),
          ),
          _StartModeTile(
            selected: _mode == TeamTossMode.manual,
            enabled: !_tossTimer.isAnimating,
            icon: Icons.touch_app_rounded,
            title: 'Record a real toss',
            subtitle: 'Use this after tossing a physical coin on the ground.',
            onTap: () => _selectMode(TeamTossMode.manual),
          ),
          _StartModeTile(
            selected: _mode == TeamTossMode.skipped,
            enabled: !_tossTimer.isAnimating,
            icon: Icons.fast_forward_rounded,
            title: 'Skip toss',
            subtitle: 'Directly choose which team bats first.',
            onTap: () => _selectMode(TeamTossMode.skipped),
          ),
          if (previousWinnerId != null)
            _StartModeTile(
              selected: _mode == TeamTossMode.previousWinnerChoice,
              enabled: !_tossTimer.isAnimating,
              icon: Icons.emoji_events_rounded,
              title: 'Previous winner decides',
              subtitle:
                  '${previous!.side(previousWinnerId).name} won the last match and can choose Bat or Bowl.',
              onTap: () => _selectMode(
                TeamTossMode.previousWinnerChoice,
                previousWinnerTeamId: previousWinnerId,
              ),
            ),
          if (_mode == TeamTossMode.inApp) ...[
            const SizedBox(height: 18),
            _buildInAppToss(match),
          ],
          if (_mode == TeamTossMode.manual) ...[
            const SizedBox(height: 18),
            _buildWinnerDecision(
              match,
              title: 'Record real toss result',
              helper: 'Select the team that won the physical coin toss.',
            ),
          ],
          if (_mode == TeamTossMode.previousWinnerChoice &&
              previousWinnerId != null) ...[
            const SizedBox(height: 18),
            _buildPreviousWinnerDecision(match, previous!, previousWinnerId),
          ],
          if (_mode == TeamTossMode.skipped) ...[
            const SizedBox(height: 18),
            _buildFirstBattingChoice(match),
          ],
          if (batting != null && bowling != null) ...[
            const SizedBox(height: 18),
            Card(
              color: const Color(0xFFE7F8F0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${batting.name} bats first',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${bowling.name} bowls first',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'opening-${bowling.id}-${_openingBowlerId ?? 'none'}',
                      ),
                      initialValue: _openingBowlerId,
                      decoration: InputDecoration(
                        labelText: '${bowling.name} opening bowler',
                        helperText:
                            'Quota and Joker self-bowling rules are applied.',
                      ),
                      items: bowlers.map((id) {
                        final player = store.playerById(id);
                        final quota = bowling.bowlingQuotaBalls[id] ?? 0;
                        return DropdownMenuItem(
                          value: id,
                          child: Row(
                            children: [
                              if (player != null)
                                PlayerAvatar(player: player, radius: 14),
                              if (player != null) const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${player?.name ?? id} • '
                                  '${quota ~/ match.rules.ballsPerOver} ov',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _openingBowlerId = value),
                    ),
                    if (bowlers.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'No eligible opening bowler. Check quota or Joker batting position.',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openingBowlerId == null || _starting
                            ? null
                            : () => _start(match),
                        icon: _starting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text('Start • ${batting.name} batting'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInAppToss(TeamMatch match) {
    final caller = _tosserTeamId == null
        ? null
        : match.otherSide(_tosserTeamId!);
    final winnerId = _inAppWinnerId(match);
    final winner = winnerId == null ? null : match.side(winnerId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Timed toss setup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('tosser-${_tosserTeamId ?? 'none'}'),
              initialValue: _tosserTeamId,
              decoration: const InputDecoration(
                labelText: 'Team flipping the coin',
              ),
              items: [match.teamA, match.teamB]
                  .map(
                    (side) => DropdownMenuItem(
                      value: side.id,
                      child: Text(side.name),
                    ),
                  )
                  .toList(),
              onChanged: _tossTimer.isAnimating
                  ? null
                  : (value) => setState(() {
                      _clearOutcome();
                      _tosserTeamId = value;
                    }),
            ),
            if (caller != null) ...[
              const SizedBox(height: 8),
              Text(
                '${caller.name} must call Heads or Tails while the timer runs.',
                style: const TextStyle(
                  color: AppColors.greenDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(child: _buildCoin()),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: _tossTimer,
              builder: (context, _) {
                final remaining = max(
                  0,
                  (3 * (1 - _tossTimer.value)).ceil(),
                );
                return Column(
                  children: [
                    if (_tossTimer.isAnimating)
                      SizedBox.square(
                        dimension: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: 1 - _tossTimer.value,
                              strokeWidth: 7,
                            ),
                            Text(
                              '${remaining}s',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_tossTimer.isAnimating) const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _CallButton(
                            label: 'HEADS',
                            selected: _call == TeamTossCall.heads,
                            enabled:
                                _tossTimer.isAnimating && _call == null,
                            onPressed: () =>
                                _selectCall(TeamTossCall.heads),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CallButton(
                            label: 'TAILS',
                            selected: _call == TeamTossCall.tails,
                            enabled:
                                _tossTimer.isAnimating && _call == null,
                            onPressed: () =>
                                _selectCall(TeamTossCall.tails),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (!_tossTimer.isAnimating && !_revealed && !_callMissed)
              FilledButton.icon(
                onPressed: _tosserTeamId == null
                    ? null
                    : _startToss,
                icon: const Icon(Icons.casino_rounded),
                label: const Text('Start 3-second toss'),
              ),
            if (_callMissed)
              Card(
                color: const Color(0xFFFFF4E8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      const Text(
                        'Call missed before timer ended',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _restartToss,
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('Restart toss'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _startOver,
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text('Start over'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => _selectMode(TeamTossMode.skipped),
                        icon: const Icon(Icons.fast_forward_rounded),
                        label: const Text('Skip toss & choose who bats first'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_revealed && winner != null)
              Card(
                color: const Color(0xFFFFF7E4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(
                        '${_hiddenResult!.name.toUpperCase()} • '
                        '${winner.name} won the toss',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _decisionSelector(),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _restartToss,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Toss again'),
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

  Widget _buildCoin() => AnimatedBuilder(
    animation: _tossTimer,
    builder: (context, _) {
      final started = _hiddenResult != null;
      final halfTurns = 18 + (_hiddenResult == TeamTossCall.tails ? 1 : 0);
      final angle = started
          ? Curves.easeOutCubic.transform(_tossTimer.value) * halfTurns * pi
          : 0.0;
      final showingHeads = cos(angle) >= 0;
      final hideFace = _callMissed && !_tossTimer.isAnimating;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .002)
          ..rotateY(angle),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE49A),
                AppColors.gold,
                Color(0xFFC77B00),
              ],
            ),
            border: Border.all(color: const Color(0xFFFFF1C8), width: 7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44071A13),
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(showingHeads ? 0 : pi),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hideFace
                      ? Icons.question_mark_rounded
                      : !started
                          ? Icons.casino_rounded
                          : showingHeads
                              ? Icons.sports_cricket_rounded
                              : Icons.emoji_events_rounded,
                  size: 46,
                  color: AppColors.ink,
                ),
                Text(
                  hideFace
                      ? 'CALL MISSED'
                      : !started
                          ? 'READY'
                          : showingHeads
                              ? 'HEADS'
                              : 'TAILS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildWinnerDecision(
    TeamMatch match, {
    required String title,
    required String helper,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(helper, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('winner-${_manualWinnerTeamId ?? 'none'}'),
            initialValue: _manualWinnerTeamId,
            decoration: const InputDecoration(labelText: 'Toss winner'),
            items: [match.teamA, match.teamB]
                .map(
                  (side) => DropdownMenuItem(
                    value: side.id,
                    child: Text(side.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _manualWinnerTeamId = value;
              _openingBowlerId = null;
            }),
          ),
          const SizedBox(height: 14),
          _decisionSelector(),
        ],
      ),
    ),
  );

  Widget _buildPreviousWinnerDecision(
    TeamMatch match,
    TeamMatch previous,
    String previousWinnerId,
  ) {
    final previousWinner = previous.side(previousWinnerId);
    final currentSide = match.side(previousWinnerId);
    return Card(
      color: const Color(0xFFFFF7E4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Previous winner’s choice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${previousWinner.name} won the previous match. '
              '${currentSide.name} now chooses Bat or Bowl without another toss.',
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 14),
            _decisionSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstBattingChoice(TeamMatch match) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Who bats first?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'No toss result will be recorded for this match.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'first-batting-${_firstBattingTeamId ?? 'none'}',
            ),
            initialValue: _firstBattingTeamId,
            decoration: const InputDecoration(
              labelText: 'First batting team',
              hintText: 'Choose a team',
            ),
            items: [match.teamA, match.teamB]
                .map(
                  (side) => DropdownMenuItem(
                    value: side.id,
                    child: Text(side.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _firstBattingTeamId = value;
              _openingBowlerId = null;
            }),
          ),
        ],
      ),
    ),
  );

  Widget _decisionSelector() => SegmentedButton<TeamTossDecision>(
    segments: const [
      ButtonSegment(
        value: TeamTossDecision.bat,
        icon: Icon(Icons.sports_cricket_rounded),
        label: Text('Bat'),
      ),
      ButtonSegment(
        value: TeamTossDecision.bowl,
        icon: Icon(Icons.sports_baseball_rounded),
        label: Text('Bowl'),
      ),
    ],
    selected: {_decision},
    onSelectionChanged: (value) => setState(() {
      _decision = value.single;
      _openingBowlerId = null;
    }),
  );
}

class _StartModeTile extends StatelessWidget {
  const _StartModeTile({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      color: selected ? const Color(0xFFE7F8F0) : null,
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: selected ? AppColors.greenDark : AppColors.muted,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? AppColors.greenDark : AppColors.muted,
        ),
        onTap: enabled ? onTap : null,
      ),
    ),
  );
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_rounded),
          label: Text('$label LOCKED'),
        )
      : OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: Text(label),
        );
}
