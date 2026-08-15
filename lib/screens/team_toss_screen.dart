import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/team_match.dart';
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
  late final AnimationController _coin;
  String? _callerTeamId;
  TeamTossCall _call = TeamTossCall.heads;
  TeamTossCall? _result;
  TeamTossDecision _decision = TeamTossDecision.bat;
  String? _openingBowlerId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _coin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void dispose() {
    _coin.dispose();
    super.dispose();
  }

  void _flip(TeamMatch match) {
    if (_coin.isAnimating) return;
    final caller = _callerTeamId ?? match.teamA.id;
    setState(() {
      _callerTeamId = caller;
      _result = Random.secure().nextBool()
          ? TeamTossCall.heads
          : TeamTossCall.tails;
      _openingBowlerId = null;
    });
    _coin.forward(from: 0);
  }

  String _winnerId(TeamMatch match) {
    final caller = _callerTeamId ?? match.teamA.id;
    return _result == _call ? caller : match.otherSide(caller).id;
  }

  TeamSide _battingSide(TeamMatch match) {
    final winner = match.side(_winnerId(match));
    return _decision == TeamTossDecision.bat
        ? winner
        : match.otherSide(winner.id);
  }

  TeamSide _bowlingSide(TeamMatch match) =>
      match.otherSide(_battingSide(match).id);

  List<String> _availableOpeningBowlers(TeamMatch match) {
    if (_result == null) return const [];
    final batting = _battingSide(match);
    final bowling = _bowlingSide(match);
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
    final bowler = _openingBowlerId;
    if (_result == null || bowler == null || _starting) return;
    setState(() => _starting = true);
    final caller = _callerTeamId ?? match.teamA.id;
    final winner = _winnerId(match);
    try {
      await AppScope.read(context).startTeamMatchAfterToss(
        match.id,
        toss: TeamToss(
          callerTeamId: caller,
          call: _call,
          result: _result!,
          winnerTeamId: winner,
          decision: _decision,
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
    _callerTeamId ??= match.teamA.id;
    final revealed = _result != null && !_coin.isAnimating;
    final winner = _result == null ? null : match.side(_winnerId(match));
    final bowlers = _availableOpeningBowlers(match);
    if (_openingBowlerId != null && !bowlers.contains(_openingBowlerId)) {
      _openingBowlerId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Match Toss'),
        actions: [TeamMatchSyncIndicator(matchId: match.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            match.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${match.teamA.name} vs ${match.teamB.name} • ${match.rules.ballLimit ~/ match.rules.ballsPerOver} overs',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Center(
            child: AnimatedBuilder(
              animation: _coin,
              builder: (context, _) {
                final halfTurns = 10 + (_result == TeamTossCall.tails ? 1 : 0);
                final angle =
                    Curves.easeOutCubic.transform(_coin.value) * halfTurns * pi;
                final showingHeads = cos(angle) >= 0;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .002)
                    ..rotateY(angle),
                  child: Container(
                    width: 154,
                    height: 154,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE49A), AppColors.gold, Color(0xFFC77B00)],
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
                            showingHeads
                                ? Icons.sports_cricket_rounded
                                : Icons.emoji_events_rounded,
                            size: 48,
                            color: AppColors.ink,
                          ),
                          Text(
                            showingHeads ? 'HEADS' : 'TAILS',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          DropdownButtonFormField<String>(
            initialValue: _callerTeamId,
            decoration: const InputDecoration(labelText: 'Team calling the toss'),
            items: [match.teamA, match.teamB]
                .map(
                  (side) => DropdownMenuItem(
                    value: side.id,
                    child: Text(side.name),
                  ),
                )
                .toList(),
            onChanged: _coin.isAnimating
                ? null
                : (value) => setState(() {
                    _callerTeamId = value;
                    _result = null;
                    _openingBowlerId = null;
                  }),
          ),
          const SizedBox(height: 14),
          SegmentedButton<TeamTossCall>(
            segments: const [
              ButtonSegment(value: TeamTossCall.heads, label: Text('Heads')),
              ButtonSegment(value: TeamTossCall.tails, label: Text('Tails')),
            ],
            selected: {_call},
            onSelectionChanged: _coin.isAnimating
                ? null
                : (value) => setState(() {
                    _call = value.single;
                    _result = null;
                    _openingBowlerId = null;
                  }),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _coin.isAnimating ? null : () => _flip(match),
            icon: const Icon(Icons.casino_rounded),
            label: Text(_result == null ? 'Flip coin' : 'Flip again'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _coin,
              builder: (context, _) => AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: revealed ? 1 : 0,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(
                          '${_result!.name.toUpperCase()} • ${winner?.name ?? ''} won the toss',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<TeamTossDecision>(
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
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _openingBowlerId,
                          decoration: InputDecoration(
                            labelText: '${_bowlingSide(match).name} opening bowler',
                            helperText: 'Quota and Joker self-bowling rules are applied.',
                          ),
                          items: bowlers.map((id) {
                            final player = store.playerById(id);
                            final quota = _bowlingSide(match).bowlingQuotaBalls[id] ?? 0;
                            return DropdownMenuItem(
                              value: id,
                              child: Row(
                                children: [
                                  if (player != null) PlayerAvatar(player: player, radius: 14),
                                  if (player != null) const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${player?.name ?? id} • ${quota ~/ match.rules.ballsPerOver} ov',
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
                        FilledButton.icon(
                          onPressed: _openingBowlerId == null || _starting
                              ? null
                              : () => _start(match),
                          icon: _starting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            'Start • ${_battingSide(match).name} batting',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
