import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/match_planning.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'public_player_profile_screen.dart';
import 'register_player_dialog.dart';
import 'secret_draw_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _title = TextEditingController();
  final _playerSearch = TextEditingController();
  final Set<String> _selected = <String>{};
  ScoringMode _mode = ScoringMode.ballByBall;
  MatchWinnerMetric _winnerMetric = MatchWinnerMetric.overallPoints;
  int _ballLimit = 9;
  String? _trackerPlayerId;
  PointRules _pointRules = const PointRules();
  String _pointPresetName = 'Balanced';
  String _pointPresetId = 'balanced';
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _playerSearch.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two players.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final match = await AppScope.read(context).createMatch(
        title: _title.text,
        scoringMode: _mode,
        ballLimit: _ballLimit,
        participantIds: _selected.toList(),
        winnerMetric: _winnerMetric,
        trackerPlayerId: _mode == ScoringMode.ballByBall
            ? _trackerPlayerId
            : null,
        pointRules: _pointRules,
        pointPresetName: _pointPresetName,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SecretDrawScreen(matchId: match.id)),
      );
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

  Future<void> _customOvers() async {
    final controller = TextEditingController(
      text: _ballLimit % 3 == 0
          ? (_ballLimit / 6).toString().replaceFirst(RegExp(r'\.0$'), '')
          : '',
    );
    String? validation;
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Overs per player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Overs',
                  hintText: '1.5',
                  errorText: validation,
                  helperText: 'CricXii setup: 1.5 overs = 9 legal balls.',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Use whole or half overs: 1, 1.5, 2, 2.5 ...',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final balls = OversFormat.setupOversToBalls(controller.text);
                if (balls == null) {
                  setDialogState(
                    () => validation = 'Enter whole or half overs only.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, balls);
              },
              child: const Text('Use overs'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (mounted && value != null && value > 0) {
      setState(() => _ballLimit = value);
    }
  }

  Future<void> _addPlayer() async {
    final created = await showPlayerAccountRegistration(context);
    if (created == null || !mounted) return;
    final addToMatch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${created.player.name} to this match?'),
        content: const Text(
          'The account is ready. Add this player to today’s match now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to match'),
          ),
        ],
      ),
    );
    if (addToMatch == true && mounted) {
      setState(() => _selected.add(created.player.id));
    }
  }

  Future<void> _editPoints() async {
    final run = TextEditingController(text: '${_pointRules.run}');
    final wicket = TextEditingController(text: '${_pointRules.wicket}');
    final catchPoint = TextEditingController(text: '${_pointRules.catchPoint}');
    final direct = TextEditingController(text: '${_pointRules.directRunOut}');
    final assist = TextEditingController(text: '${_pointRules.assistedRunOut}');
    final stumping = TextEditingController(text: '${_pointRules.stumping}');
    final notOut = TextEditingController(text: '${_pointRules.notOutBonus}');
    final presetName = TextEditingController();
    var makeDefault = false;
    final result = await showModalBottomSheet<_PointEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                  'Points rules',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Balanced default: wicket 5, catch 2, direct run-out 3. Match rules lock when play starts.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                _NumberField(controller: run, label: 'Per run'),
                _NumberField(controller: wicket, label: 'Wicket'),
                _NumberField(controller: catchPoint, label: 'Catch'),
                _NumberField(controller: direct, label: 'Direct run out'),
                _NumberField(
                  controller: assist,
                  label: 'Assisted run out (each)',
                ),
                _NumberField(controller: stumping, label: 'Stumping'),
                _NumberField(controller: notOut, label: 'Not-out bonus'),
                const Divider(height: 26),
                TextField(
                  controller: presetName,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Save as preset (optional)',
                    hintText: 'Weekend Ground Rules',
                    prefixIcon: Icon(Icons.bookmark_add_outlined),
                  ),
                ),
                if (presetName.text.trim().isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: makeDefault,
                    onChanged: (value) =>
                        setSheetState(() => makeDefault = value),
                    title: const Text(
                      'Use as default for new matches',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    int value(TextEditingController controller, int fallback) =>
                        int.tryParse(controller.text) ?? fallback;
                    Navigator.pop(
                      context,
                      _PointEditResult(
                        rules: PointRules(
                          run: value(run, _pointRules.run),
                          wicket: value(wicket, _pointRules.wicket),
                          catchPoint: value(catchPoint, _pointRules.catchPoint),
                          directRunOut: value(direct, _pointRules.directRunOut),
                          assistedRunOut: value(
                            assist,
                            _pointRules.assistedRunOut,
                          ),
                          stumping: value(stumping, _pointRules.stumping),
                          notOutBonus: value(notOut, _pointRules.notOutBonus),
                        ),
                        presetName: presetName.text.trim(),
                        makeDefault: makeDefault,
                      ),
                    );
                  },
                  child: const Text('Use these points'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final controller in [
      run,
      wicket,
      catchPoint,
      direct,
      assist,
      stumping,
      notOut,
      presetName,
    ]) {
      controller.dispose();
    }
    if (result == null || !mounted) return;

    var presetId = 'custom';
    var presetLabel = 'Custom';
    if (result.presetName.isNotEmpty) {
      try {
        final preset = await AppScope.read(context).savePointPreset(
          name: result.presetName,
          rules: result.rules,
          makeDefault: result.makeDefault,
        );
        presetId = preset.id;
        presetLabel = preset.name;
      } on StateError catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
    if (mounted) {
      setState(() {
        _pointRules = result.rules;
        _pointPresetId = presetId;
        _pointPresetName = presetLabel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!_initialized) {
      _selected.add(store.activePlayer!.id);
      _title.text = store.suggestMatchTitle();
      final preset = store.defaultPointPreset;
      _pointRules = preset.rules;
      _pointPresetId = preset.id;
      _pointPresetName = preset.name;
      _initialized = true;
    }
    final selectedPlayers = store.visiblePlayers
        .where((player) => _selected.contains(player.id))
        .toList();
    final query = _playerSearch.text.trim().toLowerCase();
    final visiblePlayers = store.visiblePlayers.where((player) {
      if (query.isEmpty) return true;
      final gang = store.gangById(player.gangId);
      return player.name.toLowerCase().contains(query) ||
          player.id.toLowerCase().contains(query) ||
          (gang?.name.toLowerCase().contains(query) ?? false) ||
          (gang?.id.toLowerCase().contains(query) ?? false);
    }).toList();
    if (_trackerPlayerId != null && !_selected.contains(_trackerPlayerId)) {
      _trackerPlayerId = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create singles match')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
        children: [
          const ScreenTitle(
            title: 'Match setup',
            subtitle:
                'Set overs, players and points. The secret draw randomises both pass order and hidden card numbers.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Match name',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Default name is generated from today’s match number and time of day. You can edit it.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Scoring method'),
          const SizedBox(height: 10),
          SegmentedButton<ScoringMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ScoringMode.ballByBall,
                icon: Icon(Icons.linear_scale_rounded),
                label: Text('Ball tracker'),
              ),
              ButtonSegment(
                value: ScoringMode.quickTotal,
                icon: Icon(Icons.flash_on_rounded),
                label: Text('Direct runs'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.single),
          ),
          const SizedBox(height: 10),
          Text(
            _mode == ScoringMode.ballByBall
                ? 'Every delivery is stored with time, bowler, runs, extras and wicket details.'
                : 'Fast entry: save each batter’s final total and dismissal. The fixed bowling plan is still visible.',
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Overs per player'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in const <int>[6, 9, 12, 15, 18, 24])
                ChoiceChip(
                  label: Text(OversFormat.setupOversLabel(preset)),
                  selected: _ballLimit == preset,
                  onSelected: (_) => setState(() => _ballLimit = preset),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  const <int>[6, 9, 12, 15, 18, 24].contains(_ballLimit)
                      ? 'Custom'
                      : OversFormat.setupOversLabel(_ballLimit),
                ),
                onPressed: _customOvers,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${OversFormat.setupOversLabel(_ballLimit)} = $_ballLimit legal balls for each batting turn.',
            style: const TextStyle(
              color: AppColors.greenDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(
            'Players • ${_selected.length} selected',
            trailing: TextButton.icon(
              onPressed: _addPlayer,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('New'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _playerSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search name, Player ID or Gang ID',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E9E4)),
            ),
            child: visiblePlayers.isEmpty
                ? const Center(
                    child: Text(
                      'No player matches this search.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    itemCount: visiblePlayers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final player = visiblePlayers[index];
                      return CheckboxListTile(
                        value: _selected.contains(player.id),
                        onChanged: player.id == store.activePlayerId
                            ? null
                            : (value) => setState(() {
                                if (value ?? false) {
                                  _selected.add(player.id);
                                } else {
                                  _selected.remove(player.id);
                                }
                              }),
                        secondary: GestureDetector(
                          onTap: () => openPlayerProfile(context, player.id),
                          child: PlayerAvatar(player: player),
                        ),
                        title: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${player.id}${player.id == store.activePlayerId ? ' • Creator' : ''}',
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
          ),
          if (_mode == ScoringMode.ballByBall &&
              selectedPlayers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('Optional tracker'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              key: ValueKey(_selected.join('-')),
              initialValue: _trackerPlayerId,
              decoration: const InputDecoration(
                labelText: 'Who enters each ball?',
                prefixIcon: Icon(Icons.track_changes_rounded),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Match creator / shared phone'),
                ),
                ...selectedPlayers.map(
                  (player) => DropdownMenuItem(
                    value: player.id,
                    child: Text(player.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _trackerPlayerId = value),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Official winner'),
          const SizedBox(height: 10),
          SegmentedButton<MatchWinnerMetric>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MatchWinnerMetric.overallPoints,
                icon: Icon(Icons.bolt_rounded),
                label: Text('Points'),
              ),
              ButtonSegment(
                value: MatchWinnerMetric.runs,
                icon: Icon(Icons.show_chart_rounded),
                label: Text('Runs'),
              ),
            ],
            selected: {_winnerMetric},
            onSelectionChanged: (value) =>
                setState(() => _winnerMetric = value.single),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: store.pointPresets.any(
              (preset) => preset.id == _pointPresetId,
            )
                ? _pointPresetId
                : null,
            decoration: const InputDecoration(
              labelText: 'Points preset',
              prefixIcon: Icon(Icons.bookmarks_outlined),
            ),
            items: store.pointPresets
                .map(
                  (preset) => DropdownMenuItem(
                    value: preset.id,
                    child: Text(
                      '${preset.name}${preset.id == store.defaultPointPresetId ? ' • Default' : ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final preset = store.pointPresets.firstWhere(
                (item) => item.id == value,
              );
              setState(() {
                _pointPresetId = preset.id;
                _pointPresetName = preset.name;
                _pointRules = preset.rules;
              });
            },
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calculate_outlined,
                color: AppColors.greenDark,
              ),
              title: Text(
                '$_pointPresetName points',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${_pointRules.run}/run • ${_pointRules.wicket}/wicket • ${_pointRules.catchPoint}/catch • ${_pointRules.directRunOut}/direct RO',
              ),
              trailing: TextButton(
                onPressed: _editPoints,
                child: const Text('Edit / Save'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: _busy ? null : _create,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.casino_rounded),
          label: const Text('Create match & secret draw'),
        ),
      ),
    );
  }
}

class _PointEditResult {
  const _PointEditResult({
    required this.rules,
    required this.presetName,
    required this.makeDefault,
  });

  final PointRules rules;
  final String presetName;
  final bool makeDefault;
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
