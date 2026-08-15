import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/player.dart';
import '../domain/team_match.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'team_toss_screen.dart';

class CreateTeamMatchScreen extends StatefulWidget {
  const CreateTeamMatchScreen({super.key});

  @override
  State<CreateTeamMatchScreen> createState() => _CreateTeamMatchScreenState();
}

class _CreateTeamMatchScreenState extends State<CreateTeamMatchScreen> {
  final _title = TextEditingController();
  final _overs = TextEditingController(text: '5');
  final _teamAName = TextEditingController(text: 'Team A');
  final _teamBName = TextEditingController(text: 'Team B');
  final _teamA = <String>[];
  final _teamB = <String>[];
  final _quotaA = <String, int>{};
  final _quotaB = <String, int>{};
  int _step = 0;
  bool _saving = false;
  bool _wide = true;
  bool _noBall = true;
  bool _bye = true;
  bool _legBye = true;
  bool _penalty = true;
  bool _freeHit = false;
  bool _allowConsecutiveOvers = false;
  String? _jokerId;
  String? _captainA;
  String? _captainB;
  String? _keeperA;
  String? _keeperB;
  String? _trackerId;

  @override
  void dispose() {
    _title.dispose();
    _overs.dispose();
    _teamAName.dispose();
    _teamBName.dispose();
    super.dispose();
  }

  int? get _oversValue => int.tryParse(_overs.text.trim());

  int get _ballLimit => (_oversValue ?? 0) * 6;

  void _assign(Player player, String assignment) {
    setState(() {
      final previousJoker = _jokerId;
      _teamA.remove(player.id);
      _teamB.remove(player.id);
      if (_jokerId == player.id) _jokerId = null;
      if (assignment == 'J' &&
          previousJoker != null &&
          previousJoker != player.id) {
        // Keep the previous Joker in Team A when a new shared player is picked.
        _teamB.remove(previousJoker);
      }
      switch (assignment) {
        case 'A':
          _teamA.add(player.id);
          break;
        case 'B':
          _teamB.add(player.id);
          break;
        case 'J':
          _teamA.add(player.id);
          _teamB.add(player.id);
          _jokerId = player.id;
          break;
      }
      _captainA = _validOrFirst(_captainA, _teamA);
      _captainB = _validOrFirst(_captainB, _teamB);
      _keeperA = _validOrFirst(_keeperA, _teamA);
      _keeperB = _validOrFirst(_keeperB, _teamB);
      _seedQuotas();
    });
  }

  String? _validOrFirst(String? selected, List<String> ids) {
    if (selected != null && ids.contains(selected)) return selected;
    return ids.isEmpty ? null : ids.first;
  }

  String _assignment(String playerId) {
    if (_jokerId == playerId) return 'J';
    if (_teamA.contains(playerId)) return 'A';
    if (_teamB.contains(playerId)) return 'B';
    return 'N';
  }

  void _seedQuotas() {
    void seed(List<String> ids, Map<String, int> quota) {
      quota.removeWhere((key, _) => !ids.contains(key));
      if (_ballLimit <= 0 || ids.isEmpty) return;
      final totalOvers = _oversValue ?? 0;
      final base = totalOvers ~/ ids.length;
      final remainder = totalOvers % ids.length;
      for (var index = 0; index < ids.length; index++) {
        quota.putIfAbsent(
          ids[index],
          () => (base + (index < remainder ? 1 : 0)) * 6,
        );
      }
    }

    seed(_teamA, _quotaA);
    seed(_teamB, _quotaB);
  }

  void _move(List<String> order, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final value = order.removeAt(oldIndex);
      order.insert(newIndex, value);
    });
  }

  String? _validateStep(int step) {
    if (step == 0) {
      final overs = _oversValue;
      if (overs == null || overs < 1 || overs > 100) {
        return 'Enter match overs from 1 to 100.';
      }
      if (_teamAName.text.trim().isEmpty || _teamBName.text.trim().isEmpty) {
        return 'Enter both team names.';
      }
    }
    if (step >= 2 && (_teamA.length < 2 || _teamB.length < 2)) {
      return 'Select at least two players for each team.';
    }
    if (step >= 4) {
      final coverageA = _quotaA.values.fold<int>(0, (sum, value) => sum + value);
      final coverageB = _quotaB.values.fold<int>(0, (sum, value) => sum + value);
      if (coverageA < _ballLimit || coverageB < _ballLimit) {
        return 'Each team bowling quota must cover all $_ballLimit legal balls.';
      }
    }
    return null;
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    _seedQuotas();
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _create();
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() => _saving = true);
    final store = AppScope.read(context);
    try {
      final balanced = store.defaultPointPreset.rules;
      final match = await store.createTeamMatch(
        title: _title.text,
        teamA: TeamSide(
          id: 'A',
          name: _teamAName.text.trim(),
          colorValue: 0xFF19C37D,
          playerIds: List<String>.from(_teamA),
          battingOrder: List<String>.from(_teamA),
          bowlingQuotaBalls: Map<String, int>.from(_quotaA),
          captainPlayerId: _captainA,
          wicketkeeperPlayerId: _keeperA,
        ),
        teamB: TeamSide(
          id: 'B',
          name: _teamBName.text.trim(),
          colorValue: 0xFF7C5CFC,
          playerIds: List<String>.from(_teamB),
          battingOrder: List<String>.from(_teamB),
          bowlingQuotaBalls: Map<String, int>.from(_quotaB),
          captainPlayerId: _captainB,
          wicketkeeperPlayerId: _keeperB,
        ),
        rules: TeamMatchRules(
          ballLimit: _ballLimit,
          wideEnabled: _wide,
          noBallEnabled: _noBall,
          byeEnabled: _bye,
          legByeEnabled: _legBye,
          penaltyExtrasEnabled: _penalty,
          freeHitEnabled: _freeHit,
          askLastPlayerStanding: true,
          allowConsecutiveOvers: _allowConsecutiveOvers,
          pointRules: PointRules(
            run: balanced.run,
            wicket: balanced.wicket,
            bowledBonus: balanced.bowledBonus,
            catchPoint: balanced.catchPoint,
            directRunOut: balanced.directRunOut,
            assistedRunOut: balanced.assistedRunOut,
            stumping: balanced.stumping,
            notOutBonus: balanced.notOutBonus,
          ),
        ),
        commonJokerPlayerId: _jokerId,
        trackerPlayerId: _trackerId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TeamTossScreen(matchId: match.id)),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final players = store.visiblePlayers;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team Match')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) {
          if (value <= _step) setState(() => _step = value);
        },
        onStepContinue: _saving ? null : _continue,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : details.onStepContinue,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_step == 4 ? Icons.sports_cricket : Icons.arrow_forward),
                  label: Text(_step == 4 ? 'Create & toss' : 'Continue'),
                ),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Match details'),
            subtitle: const Text('Teams and overs'),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Match title',
                    hintText: 'Evening Team Match',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _overs,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_seedQuotas),
                  decoration: const InputDecoration(
                    labelText: 'Overs per innings',
                    suffixText: 'overs',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _teamAName,
                        decoration: const InputDecoration(labelText: 'Team A'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _teamBName,
                        decoration: const InputDecoration(labelText: 'Team B'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Local rules'),
            subtitle: const Text('Extras and over behaviour'),
            isActive: _step >= 1,
            content: Column(
              children: [
                _RuleSwitch(label: 'Wide', value: _wide, onChanged: (v) => setState(() => _wide = v)),
                _RuleSwitch(label: 'No-ball', value: _noBall, onChanged: (v) => setState(() => _noBall = v)),
                _RuleSwitch(label: 'Bye', value: _bye, onChanged: (v) => setState(() => _bye = v)),
                _RuleSwitch(label: 'Leg bye', value: _legBye, onChanged: (v) => setState(() => _legBye = v)),
                _RuleSwitch(label: 'Manual penalty extras', value: _penalty, onChanged: (v) => setState(() => _penalty = v)),
                if (_noBall)
                  _RuleSwitch(label: 'Free hit after no-ball', value: _freeHit, onChanged: (v) => setState(() => _freeHit = v)),
                _RuleSwitch(
                  label: 'Allow same bowler in consecutive overs',
                  value: _allowConsecutiveOvers,
                  onChanged: (v) => setState(() => _allowConsecutiveOvers = v),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.person_rounded, color: AppColors.greenDark),
                    title: Text('Last Player Standing prompt'),
                    subtitle: Text(
                      'When one batter remains, CricXii asks Continue solo or End innings. The solo batter never changes after odd runs or over changes.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Select teams'),
            subtitle: Text('${_teamA.length} vs ${_teamB.length}${_jokerId == null ? '' : ' • Joker active'}'),
            isActive: _step >= 2,
            content: Column(
              children: [
                const Text(
                  'Assign every player to Team A, Team B, or Joker. Joker appears in both teams.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                ...players.map(
                  (player) => Card(
                    child: ListTile(
                      leading: PlayerAvatar(player: player, radius: 22),
                      title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(player.id),
                      trailing: DropdownButton<String>(
                        value: _assignment(player.id),
                        onChanged: (value) => _assign(player, value ?? 'N'),
                        items: const [
                          DropdownMenuItem(value: 'N', child: Text('None')),
                          DropdownMenuItem(value: 'A', child: Text('Team A')),
                          DropdownMenuItem(value: 'B', child: Text('Team B')),
                          DropdownMenuItem(value: 'J', child: Text('🃏 Joker')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Orders and roles'),
            subtitle: const Text('Batting, captain, keeper and scorer'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoleSelectors(
                  title: _teamAName.text,
                  ids: _teamA,
                  captain: _captainA,
                  keeper: _keeperA,
                  players: players,
                  onCaptain: (value) => setState(() => _captainA = value),
                  onKeeper: (value) => setState(() => _keeperA = value),
                ),
                _OrderEditor(
                  title: '${_teamAName.text} batting order',
                  order: _teamA,
                  players: players,
                  jokerId: _jokerId,
                  onReorder: (oldIndex, newIndex) => _move(_teamA, oldIndex, newIndex),
                ),
                const SizedBox(height: 18),
                _RoleSelectors(
                  title: _teamBName.text,
                  ids: _teamB,
                  captain: _captainB,
                  keeper: _keeperB,
                  players: players,
                  onCaptain: (value) => setState(() => _captainB = value),
                  onKeeper: (value) => setState(() => _keeperB = value),
                ),
                _OrderEditor(
                  title: '${_teamBName.text} batting order',
                  order: _teamB,
                  players: players,
                  jokerId: _jokerId,
                  onReorder: (oldIndex, newIndex) => _move(_teamB, oldIndex, newIndex),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _trackerId ?? '',
                  decoration: const InputDecoration(labelText: 'Scorer / tracker'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Host scores')),
                    ...players.map(
                      (player) => DropdownMenuItem(value: player.id, child: Text(player.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _trackerId = value?.isEmpty == true ? null : value),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Bowling limits'),
            subtitle: const Text('Individual quota and final review'),
            isActive: _step >= 4,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuotaEditor(
                  title: '${_teamAName.text} bowling limits',
                  ids: _teamA,
                  quota: _quotaA,
                  players: players,
                  maxOvers: max(1, _oversValue ?? 1),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 18),
                _QuotaEditor(
                  title: '${_teamBName.text} bowling limits',
                  ids: _teamB,
                  quota: _quotaB,
                  players: players,
                  maxOvers: max(1, _oversValue ?? 1),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFFE7F8F0),
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined, color: AppColors.greenDark),
                    title: Text('${_teamA.length} vs ${_teamB.length} • ${_oversValue ?? 0} overs'),
                    subtitle: Text(
                      '${_jokerId == null ? 'No Joker' : 'Joker enabled'} • '
                      '${[_wide ? 'Wide' : null, _noBall ? 'No-ball' : null, _bye ? 'Bye' : null, _legBye ? 'Leg bye' : null].whereType<String>().join(', ')}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    value: value,
    onChanged: onChanged,
  );
}

class _RoleSelectors extends StatelessWidget {
  const _RoleSelectors({
    required this.title,
    required this.ids,
    required this.captain,
    required this.keeper,
    required this.players,
    required this.onCaptain,
    required this.onKeeper,
  });

  final String title;
  final List<String> ids;
  final String? captain;
  final String? keeper;
  final List<Player> players;
  final ValueChanged<String?> onCaptain;
  final ValueChanged<String?> onKeeper;

  String name(String id) => players.firstWhere((player) => player.id == id).name;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: captain,
              decoration: const InputDecoration(labelText: 'Captain'),
              items: ids.map((id) => DropdownMenuItem(value: id, child: Text(name(id)))).toList(),
              onChanged: onCaptain,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: keeper,
              decoration: const InputDecoration(labelText: 'Keeper'),
              items: ids.map((id) => DropdownMenuItem(value: id, child: Text(name(id)))).toList(),
              onChanged: onKeeper,
            ),
          ),
        ],
      ),
    ],
  );
}

class _OrderEditor extends StatelessWidget {
  const _OrderEditor({
    required this.title,
    required this.order,
    required this.players,
    required this.jokerId,
    required this.onReorder,
  });

  final String title;
  final List<String> order;
  final List<Player> players;
  final String? jokerId;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: order.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final id = order[index];
          final player = players.firstWhere((value) => value.id == id);
          return ListTile(
            key: ValueKey('$title-$id'),
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(player.name),
            subtitle: jokerId == id ? const Text('🃏 Joker') : null,
            trailing: const Icon(Icons.drag_handle_rounded),
          );
        },
      ),
    ],
  );
}

class _QuotaEditor extends StatelessWidget {
  const _QuotaEditor({
    required this.title,
    required this.ids,
    required this.quota,
    required this.players,
    required this.maxOvers,
    required this.onChanged,
  });

  final String title;
  final List<String> ids;
  final Map<String, int> quota;
  final List<Player> players;
  final int maxOvers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final coverage = quota.values.fold<int>(0, (sum, value) => sum + value) ~/ 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text('Coverage: $coverage overs', style: const TextStyle(color: AppColors.greenDark)),
        ...ids.map((id) {
          final player = players.firstWhere((value) => value.id == id);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PlayerAvatar(player: player, radius: 20),
            title: Text(player.name),
            trailing: DropdownButton<int>(
              value: (quota[id] ?? 0) ~/ 6,
              items: List.generate(
                maxOvers + 1,
                (value) => DropdownMenuItem(value: value, child: Text('$value ov')),
              ),
              onChanged: (value) {
                quota[id] = (value ?? 0) * 6;
                onChanged();
              },
            ),
          );
        }),
      ],
    );
  }
}
