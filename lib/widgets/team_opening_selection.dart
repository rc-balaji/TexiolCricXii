import 'package:flutter/material.dart';

import '../domain/team_match.dart';
import '../domain/team_scoring_engine.dart';
import '../theme/app_theme.dart';
import 'app_scope.dart';

/// Explicit opening choices shared by toss, chase and Super Over setup.
class TeamOpeningSelection extends StatelessWidget {
  const TeamOpeningSelection({
    required this.match,
    required this.battingTeamId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.onStrikerChanged,
    required this.onNonStrikerChanged,
    required this.onBowlerChanged,
    this.isSuperOver = false,
    this.enabled = true,
    super.key,
  });

  final TeamMatch match;
  final String battingTeamId;
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;
  final ValueChanged<String?> onStrikerChanged;
  final ValueChanged<String?> onNonStrikerChanged;
  final ValueChanged<String?> onBowlerChanged;
  final bool isSuperOver;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final batting = match.side(battingTeamId);
    final bowling = match.otherSide(battingTeamId);
    final pairChosen = strikerId != null && nonStrikerId != null;
    final bowlers =
        pairChosen
            ? TeamScoringEngine.openingBowlerIds(
              match,
              battingTeamId: battingTeamId,
              openingStrikerId: strikerId!,
              openingNonStrikerId: nonStrikerId!,
              isSuperOver: isSuperOver,
            )
            : <String>[];
    Widget selector(
      String role,
      String label,
      List<String> ids,
      String? value,
      ValueChanged<String?> onChanged,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('opening-$role-$battingTeamId-$value-${ids.join(',')}'),
      initialValue: ids.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items:
          ids
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(
                    store.playerById(id)?.name ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      onChanged: enabled && ids.isNotEmpty ? onChanged : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose the opening pair',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'The striker faces the first ball.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        selector(
          'striker',
          '${batting.name} striker',
          batting.playerIds,
          strikerId,
          onStrikerChanged,
        ),
        const SizedBox(height: 12),
        selector(
          'non-striker',
          '${batting.name} non-striker',
          batting.playerIds.where((id) => id != strikerId).toList(),
          nonStrikerId,
          onNonStrikerChanged,
        ),
        const SizedBox(height: 12),
        selector(
          'bowler',
          '${bowling.name} opening bowler',
          bowlers,
          bowlerId,
          onBowlerChanged,
        ),
        if (!pairChosen)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Choose both batters to see available bowlers.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if (pairChosen && bowlers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No available bowler for this pair. Change the opening pair if the shared Joker needs to bowl.',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
