import 'package:flutter/material.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'register_player_dialog.dart';
import 'secret_draw_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _title = TextEditingController(text: 'Evening Singles');
  final _playerSearch = TextEditingController();
  final Set<String> _selected = <String>{};
  ScoringMode _mode = ScoringMode.ballByBall;
  MatchWinnerMetric _winnerMetric = MatchWinnerMetric.overallPoints;
  int _ballLimit = 9;
  String? _trackerPlayerId;
  PointRules _pointRules = const PointRules();
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

  Future<void> _customBalls() async {
    final controller = TextEditingController(text: '9');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom legal balls'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Balls per player',
            helperText: 'Example: 1.5 overs = 9 balls in CricXii',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Use balls'),
          ),
        ],
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
          'The account was created separately. Choose whether this player should participate now.',
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
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
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
                'These values lock when the match starts.',
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
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save points'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      int value(TextEditingController controller, int fallback) =>
          int.tryParse(controller.text) ?? fallback;
      setState(() {
        _pointRules = PointRules(
          run: value(run, 1),
          wicket: value(wicket, 20),
          catchPoint: value(catchPoint, 10),
          directRunOut: value(direct, 15),
          assistedRunOut: value(assist, 8),
          stumping: value(stumping, 12),
          notOutBonus: value(notOut, 5),
        );
      });
    }
    for (final controller in [
      run,
      wicket,
      catchPoint,
      direct,
      assist,
      stumping,
      notOut,
    ]) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!_initialized) {
      _selected.add(store.activePlayer!.id);
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
                'One batting turn per player. Out or the selected ball limit ends the turn.',
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
                ? 'Track every ball: 0, 1, 2, 3, 4, 5, 6, extras and wicket.'
                : 'After each player finishes, enter only their total runs and optional out details.',
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Balls per player'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in const [6, 9, 12, 18, 36])
                ChoiceChip(
                  label: Text(preset == 9 ? '9 • 1½ overs' : '$preset balls'),
                  selected: _ballLimit == preset,
                  onSelected: (_) => setState(() => _ballLimit = preset),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  const [6, 9, 12, 18, 36].contains(_ballLimit)
                      ? 'Custom'
                      : '$_ballLimit balls',
                ),
                onPressed: _customBalls,
              ),
            ],
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
                        secondary: PlayerAvatar(
                          player: player,
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
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calculate_outlined,
                color: AppColors.greenDark,
              ),
              title: const Text(
                'Local All-Rounder points',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${_pointRules.run}/run • ${_pointRules.wicket}/wicket • ${_pointRules.catchPoint}/catch',
              ),
              trailing: TextButton(
                onPressed: _editPoints,
                child: const Text('Edit'),
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
