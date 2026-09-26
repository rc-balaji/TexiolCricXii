import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/team_match.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'team_toss_screen.dart';

class CreateTeamMatchScreen extends StatefulWidget {
  const CreateTeamMatchScreen({
    this.templateMatchId,
    this.quickRematch = false,
    super.key,
  });

  final String? templateMatchId;
  final bool quickRematch;

  @override
  State<CreateTeamMatchScreen> createState() => _CreateTeamMatchScreenState();
}

class _CreateTeamMatchScreenState extends State<CreateTeamMatchScreen> {
  final _title = TextEditingController();
  final _search = TextEditingController();
  final _overs = TextEditingController(text: '4');
  final _limitOvers = TextEditingController(text: '2');
  final _extraBowlers = TextEditingController(text: '1');
  final _teamAName = TextEditingController(text: 'Team A');
  final _teamBName = TextEditingController(text: 'Team B');
  final _teamA = <String>[];
  final _teamB = <String>[];
  bool _seeded = false;
  bool _saving = false;
  bool _wide = true;
  bool _noBall = true;
  bool _bye = true;
  bool _legBye = true;
  bool _penalty = true;
  bool _freeHit = false;
  bool _allowConsecutiveOvers = true;
  bool _limitEnabled = false;
  bool _extraOverEnabled = false;
  bool _jokerEnabled = false;
  bool _customOvers = false;
  bool _practiceMatch = false;
  PointRules _pointRules = const PointRules();
  String? _jokerId;
  String? _captainA;
  String? _captainB;
  String? _keeperA;
  String? _keeperB;
  String? _trackerId;

  Set<String> get _selectedIds => {..._teamA, ..._teamB};
  int? get _oversValue => int.tryParse(_overs.text.trim());
  int? get _limitValue => int.tryParse(_limitOvers.text.trim());
  int get _extraCount =>
      _limitEnabled && _extraOverEnabled
          ? int.tryParse(_extraBowlers.text.trim()) ?? 0
          : 0;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _search,
      _overs,
      _limitOvers,
      _extraBowlers,
      _teamAName,
      _teamBName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final store = AppScope.read(context);
    _title.text = store.suggestTeamMatchTitle();
    _pointRules = store.defaultPointPreset.rules;
    final template =
        widget.templateMatchId == null
            ? null
            : store.teamMatchById(widget.templateMatchId!);
    if (template == null) return;
    final rules = template.rules;
    _overs.text = '${rules.ballLimit ~/ rules.ballsPerOver}';
    _customOvers =
        !const [4, 6, 8].contains(rules.ballLimit ~/ rules.ballsPerOver);
    _teamAName.text = template.teamA.name;
    _teamBName.text = template.teamB.name;
    _teamA.addAll(template.teamA.playerIds);
    _teamB.addAll(template.teamB.playerIds);
    _wide = rules.wideEnabled;
    _noBall = rules.noBallEnabled;
    _bye = rules.byeEnabled;
    _legBye = rules.legByeEnabled;
    _penalty = rules.penaltyExtrasEnabled;
    _freeHit = rules.freeHitEnabled;
    _allowConsecutiveOvers = rules.allowConsecutiveOvers;
    _limitEnabled = rules.maxOversPerBowler != null;
    _limitOvers.text = '${rules.maxOversPerBowler ?? 2}';
    _extraOverEnabled = rules.extraOverBowlerCount > 0;
    _extraBowlers.text = '${max(1, rules.extraOverBowlerCount)}';
    _pointRules = rules.pointRules;
    _jokerId = template.commonJokerPlayerId;
    _jokerEnabled = _jokerId != null;
    _captainA = template.teamA.captainPlayerId;
    _captainB = template.teamB.captainPlayerId;
    _keeperA = template.teamA.wicketkeeperPlayerId;
    _keeperB = template.teamB.wicketkeeperPlayerId;
    _trackerId = template.trackerPlayerId;
  }

  void _assign(String playerId, String? assignment) {
    setState(() {
      final formerJoker = _jokerId;
      _teamA.remove(playerId);
      _teamB.remove(playerId);
      if (_jokerId == playerId) _jokerId = null;
      if (assignment == 'J' && formerJoker != null && formerJoker != playerId) {
        _teamA.remove(formerJoker);
        _teamB.remove(formerJoker);
        (_teamA.length <= _teamB.length ? _teamA : _teamB).add(formerJoker);
      }
      if (assignment == 'A' || assignment == 'J') _teamA.add(playerId);
      if (assignment == 'B' || assignment == 'J') _teamB.add(playerId);
      if (assignment == 'J') _jokerId = playerId;
      _repairRoles();
    });
  }

  void _repairRoles() {
    if (!_teamA.contains(_captainA)) _captainA = null;
    if (!_teamB.contains(_captainB)) _captainB = null;
    if (!_teamA.contains(_keeperA)) _keeperA = null;
    if (!_teamB.contains(_keeperB)) _keeperB = null;
    if (!_selectedIds.contains(_trackerId)) _trackerId = null;
  }

  void _setJoker(bool enabled) {
    setState(() {
      _jokerEnabled = enabled;
      if (!enabled && _jokerId != null) {
        final former = _jokerId!;
        _teamA.remove(former);
        _teamB.remove(former);
        (_teamA.length <= _teamB.length ? _teamA : _teamB).add(former);
        _jokerId = null;
        _repairRoles();
      }
    });
  }

  String? _assignment(String id) =>
      _jokerId == id
          ? 'J'
          : _teamA.contains(id)
          ? 'A'
          : _teamB.contains(id)
          ? 'B'
          : null;

  Future<void> _editTeamName(
    String team,
    TextEditingController controller,
  ) async {
    final editor = TextEditingController(text: controller.text);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Team $team name'),
            content: TextField(
              controller: editor,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Team name'),
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, editor.text.trim()),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
    editor.dispose();
    if (!mounted || result == null || result.trim().isEmpty) return;
    setState(() => controller.text = result.trim());
  }

  Future<void> _showTeamPreview() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final store = AppScope.read(context);
    await showDialog<void>(
      context: context,
      builder:
          (context) => Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: const Color(0xFF10151C),
              appBar: AppBar(
                backgroundColor: const Color(0xFF10151C),
                foregroundColor: Colors.white,
                title: const Text(
                  'TEAM PREVIEW',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final teams = [
                      _previewPanel(
                        '1',
                        _teamAName.text,
                        _teamA,
                        store,
                        const Color(0xFF1E596D),
                      ),
                      _previewPanel(
                        '2',
                        _teamBName.text,
                        _teamB,
                        store,
                        const Color(0xFF686B16),
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
                        children: [
                          teams[0],
                          const SizedBox(height: 12),
                          teams[1],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: teams[0]),
                        const SizedBox(width: 10),
                        Expanded(child: teams[1]),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
    );
    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Widget _previewPanel(
    String serial,
    String name,
    List<String> ids,
    AppStore store,
    Color headerColor,
  ) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1B202A),
      border: Border.all(color: const Color(0xFF343B47)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          color: headerColor,
          child: Text(
            '$serial  ${name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
        if (ids.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'No players selected',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          for (var index = 0; index < ids.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color:
                    index.isEven
                        ? const Color(0xFF292D38)
                        : const Color(0xFF232731),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF11151B)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      store.playerById(ids[index])?.name ?? ids[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );

  Future<void> _easyCreatePlayer() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Easy create player'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Player name'),
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(context, nameController.text.trim()),
                child: const Text('Create'),
              ),
            ],
          ),
    );
    nameController.dispose();
    if (!mounted || name == null || name.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      final slug = name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final email =
          '$slug.${DateTime.now().millisecondsSinceEpoch}@cricxii.app';
      final created = await AppScope.read(context).registerManagedPlayerAccount(
        name: name.trim(),
        email: email,
        password: '12345678',
        battingStyle: BattingStyle.rightHanded,
        avatarPreset: 1,
      );
      if (!mounted) return;
      _assign(created.player.id, 'A');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${created.player.name} created and added to Team A'),
        ),
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

  String? _validate() {
    if (_teamA.length < 2 || _teamB.length < 2)
      return 'Add at least two players to each team. A shared Joker can play for both.';
    if (_teamAName.text.trim().isEmpty || _teamBName.text.trim().isEmpty)
      return 'Enter both team names.';
    if (_oversValue == null || _oversValue! < 1 || _oversValue! > 100)
      return 'Enter match overs from 1 to 100.';
    if (_jokerEnabled && _jokerId == null)
      return 'Choose the shared Joker, or turn off the Joker option.';
    if (_limitEnabled &&
        (_limitValue == null || _limitValue! < 1 || _limitValue! > 100))
      return 'Enter a bowler limit from 1 to 100 overs.';
    if (_limitEnabled &&
        _extraOverEnabled &&
        (_extraCount < 1 || _extraCount > min(_teamA.length, _teamB.length))) {
      return 'Extra-over bowlers must be between 1 and ${min(_teamA.length, _teamB.length)} for each team.';
    }
    if (_limitEnabled) {
      for (final entry in [
        (_teamAName.text, _teamA),
        (_teamBName.text, _teamB),
      ]) {
        final capacity =
            entry.$2.length * _limitValue! + min(_extraCount, entry.$2.length);
        if (capacity < _oversValue!)
          return '${entry.$1} can bowl only $capacity overs with these limits. Add players or increase the limit.';
      }
    }
    return null;
  }

  Future<void> _create() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      final match = await AppScope.read(context).createTeamMatch(
        title: _title.text,
        teamA: TeamSide(
          id: 'A',
          name: _teamAName.text.trim(),
          colorValue: 0xFF19C37D,
          playerIds: List.from(_teamA),
          captainPlayerId: _captainA,
          wicketkeeperPlayerId: _keeperA,
        ),
        teamB: TeamSide(
          id: 'B',
          name: _teamBName.text.trim(),
          colorValue: 0xFF7C5CFC,
          playerIds: List.from(_teamB),
          captainPlayerId: _captainB,
          wicketkeeperPlayerId: _keeperB,
        ),
        rules: TeamMatchRules(
          ballLimit: _oversValue! * 6,
          wideEnabled: _wide,
          noBallEnabled: _noBall,
          byeEnabled: _bye,
          legByeEnabled: _legBye,
          penaltyExtrasEnabled: _penalty,
          freeHitEnabled: _noBall && _freeHit,
          askLastPlayerStanding: true,
          allowConsecutiveOvers: _allowConsecutiveOvers,
          maxOversPerBowler: _limitEnabled ? _limitValue : null,
          extraOverBowlerCount: _extraCount,
          pointRules: _pointRules,
        ),
        commonJokerPlayerId: _jokerEnabled ? _jokerId : null,
        trackerPlayerId: _trackerId,
        previousMatchId: widget.templateMatchId,
        isPractice: _practiceMatch,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TeamTossScreen(matchId: match.id)),
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final players = <Player>[...store.visiblePlayers];
    for (final id in _selectedIds) {
      final player = store.playerById(id);
      if (player != null && !players.any((item) => item.id == id))
        players.add(player);
    }
    final query = _search.text.trim().toLowerCase();
    final filtered =
        players
            .where(
              (player) =>
                  query.isEmpty ||
                  player.name.toLowerCase().contains(query) ||
                  player.id.toLowerCase().contains(query),
            )
            .toList();
    final selectedPlayers =
        players.where((player) => _selectedIds.contains(player.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.templateMatchId == null
              ? 'Create Team Match'
              : 'Next Team Match',
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: const Border(top: BorderSide(color: Color(0xFFE3EAE6))),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon:
                _saving
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.sports_cricket_rounded),
            label: Text(
              _saving
                  ? 'Creating match…'
                  : 'Continue to toss • ${_teamA.length} vs ${_teamB.length}',
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _fixedTeamSummary(),
          Expanded(
            child: ListView(
              key: const ValueKey('team-match-setup-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              children: [
                Text(
                  'Your match, all in one place',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Build both teams below. Choose the opening batters after the toss.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _title,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: const InputDecoration(labelText: 'Match title'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Overs per innings',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in [4, 6, 8])
                      ChoiceChip(
                        label: Text('$value overs'),
                        selected: !_customOvers && _oversValue == value,
                        onSelected:
                            (_) => setState(() {
                              _customOvers = false;
                              _overs.text = '$value';
                            }),
                      ),
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: _customOvers,
                      onSelected: (_) => setState(() => _customOvers = true),
                    ),
                  ],
                ),
                if (_customOvers) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _overs,
                    keyboardType: TextInputType.number,
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Custom overs',
                      suffixText: 'ov',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${_selectedIds.length} players selected\n${_jokerId == null ? 'Two teams' : 'Shared Joker active'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Warm-up match',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Practice only. It will not sync or appear in saved history.',
                  ),
                  value: _practiceMatch,
                  onChanged:
                      _saving
                          ? null
                          : (value) => setState(() => _practiceMatch = value),
                ),
                _sectionTitle(
                  'Choose players',
                  '${_teamA.length} in A · ${_teamB.length} in B',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap A or B to add or move a player. Tap the selected team again to remove.',
                  style: TextStyle(color: AppColors.muted),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Shared Joker',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Optional player who plays for both teams',
                  ),
                  value: _jokerEnabled,
                  onChanged: _setJoker,
                ),
                TextField(
                  controller: _search,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search players',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _easyCreatePlayer,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Easy create player'),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No players found. Try another search, or add a player from your Gang.',
                    ),
                  )
                else
                  ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final player = filtered[index];
                      final assignment = _assignment(player.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PlayerAvatar(player: player, radius: 16),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      player.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 5,
                                children: [
                                  for (final team in [
                                    'A',
                                    'B',
                                    if (_jokerEnabled) 'J',
                                  ])
                                    ChoiceChip(
                                      key: ValueKey(
                                        'assign-${player.id}-$team',
                                      ),
                                      label: Text(team == 'J' ? 'Joker' : team),
                                      showCheckmark: false,
                                      selected: assignment == team,
                                      onSelected:
                                          (selected) => _assign(
                                            player.id,
                                            selected ? team : null,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                _bowlingRules(),
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Extras & match rules',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_wide ? 'Wides' : 'No wides'} · ${_noBall ? 'No-balls' : 'No no-balls'}',
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _rule('Wide', _wide, (v) => _wide = v),
                      _rule('No-ball', _noBall, (v) => _noBall = v),
                      if (_noBall)
                        _rule(
                          'Free hit after no-ball',
                          _freeHit,
                          (v) => _freeHit = v,
                        ),
                      _rule('Bye', _bye, (v) => _bye = v),
                      _rule('Leg bye', _legBye, (v) => _legBye = v),
                      _rule(
                        'Manual penalty extras',
                        _penalty,
                        (v) => _penalty = v,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Points and awards are enabled. When one batter remains, choose to continue solo or end the innings.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Roles & scorer',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Optional captain, keeper and scorer'),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      _roleSelectors(
                        _teamAName.text,
                        _teamA,
                        _captainA,
                        _keeperA,
                        (v) => _captainA = v,
                        (v) => _keeperA = v,
                      ),
                      const SizedBox(height: 18),
                      _roleSelectors(
                        _teamBName.text,
                        _teamB,
                        _captainB,
                        _keeperB,
                        (v) => _captainB = v,
                        (v) => _keeperB = v,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'scorer-$_trackerId-${_selectedIds.join(',')}',
                        ),
                        initialValue: _trackerId ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Scorer / tracker',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Host scores'),
                          ),
                          ...selectedPlayers.map(
                            (player) => DropdownMenuItem(
                              value: player.id,
                              child: Text(
                                player.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (v) =>
                                setState(() => _trackerId = v == '' ? null : v),
                      ),
                    ],
                  ),
                ),
                if (widget.templateMatchId != null)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'This match continues the same series and its awards.',
                      style: TextStyle(color: AppColors.greenDark),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fixedTeamSummary() => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _teamSummary('A', _teamAName.text, _teamA.length),
                      _teamSummary('B', _teamBName.text, _teamB.length),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Team A',
                  onPressed: () => _editTeamName('A', _teamAName),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Edit Team B',
                  onPressed: () => _editTeamName('B', _teamBName),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Preview teams',
                  onPressed: _showTeamPreview,
                  icon: const Icon(Icons.preview_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _teamSummary(String team, String name, int count) => Text(
    '$team: $name ($count)',
    style: const TextStyle(fontWeight: FontWeight.w900),
  );

  Widget _sectionTitle(String title, String detail) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 14,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      Text(detail, style: const TextStyle(color: AppColors.muted)),
    ],
  );

  Widget _rule(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
      );

  Widget _bowlingRules() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bowling',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose any available bowler at the start of each over.',
            style: TextStyle(color: AppColors.muted),
          ),
          _rule(
            'Limit overs per bowler',
            _limitEnabled,
            (v) => _limitEnabled = v,
          ),
          if (!_limitEnabled)
            const Text(
              'No per-bowler limit',
              style: TextStyle(color: AppColors.greenDark),
            ),
          if (_limitEnabled) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final value in [2, 3])
                  ChoiceChip(
                    label: Text('$value overs'),
                    selected: _limitValue == value,
                    onSelected:
                        (_) => setState(() => _limitOvers.text = '$value'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _limitOvers,
              keyboardType: TextInputType.number,
              onTapOutside:
                  (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Maximum overs per bowler',
                helperText: 'Use 2, 3 or your own limit',
                suffixText: 'ov',
              ),
            ),
            _rule(
              'Allow an extra over',
              _extraOverEnabled,
              (v) => _extraOverEnabled = v,
            ),
            if (_extraOverEnabled) ...[
              TextField(
                controller: _extraBowlers,
                keyboardType: TextInputType.number,
                onTapOutside:
                    (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'How many bowlers per team?',
                  helperText: 'Each can bowl one over above the limit',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose them during the match. Up to $_extraCount bowler${_extraCount == 1 ? '' : 's'} per team can bowl ${(_limitValue ?? 0) + 1} overs.',
                style: const TextStyle(color: AppColors.greenDark),
              ),
            ],
          ],
          _rule(
            'Allow consecutive overs',
            _allowConsecutiveOvers,
            (v) => _allowConsecutiveOvers = v,
          ),
        ],
      ),
    ),
  );

  Widget _roleSelectors(
    String title,
    List<String> ids,
    String? captain,
    String? keeper,
    ValueChanged<String?> onCaptain,
    ValueChanged<String?> onKeeper,
  ) {
    final store = AppScope.read(context);
    Widget selector(
      String label,
      String? value,
      ValueChanged<String?> onChanged,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('$title-$label-$value-${ids.join(',')}'),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Choose later')),
        ...ids.map(
          (id) => DropdownMenuItem(
            value: id,
            child: Text(
              store.playerById(id)?.name ?? id,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => onChanged(v == '' ? null : v)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        selector('Captain', captain, onCaptain),
        const SizedBox(height: 10),
        selector('Keeper', keeper, onKeeper),
      ],
    );
  }
}
