import 'package:flutter/material.dart';

import '../domain/player.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';
import 'public_player_profile_screen.dart';

enum _LeaderboardMetric { runs, points, wickets, catches, wins, matches }

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  _LeaderboardMetric _metric = _LeaderboardMetric.runs;
  late Future<List<Player>> _players;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _players = AppScope.read(context).loadLeaderboardPlayers();
  }

  String _label(_LeaderboardMetric metric) => switch (metric) {
    _LeaderboardMetric.runs => 'Runs',
    _LeaderboardMetric.points => 'Points',
    _LeaderboardMetric.wickets => 'Wickets',
    _LeaderboardMetric.catches => 'Catches',
    _LeaderboardMetric.wins => 'Wins',
    _LeaderboardMetric.matches => 'Matches',
  };

  int _value(Player player) {
    final stats = player.stats;
    final team = player.teamStats;
    return switch (_metric) {
      _LeaderboardMetric.runs => stats.runs + team.runs,
      _LeaderboardMetric.points => stats.points + team.points,
      _LeaderboardMetric.wickets => stats.wickets + team.wickets,
      _LeaderboardMetric.catches => stats.catches + team.catches,
      _LeaderboardMetric.wins => stats.wins + team.wins,
      _LeaderboardMetric.matches => stats.matches + team.matches,
    };
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<List<Player>>(
      future: _players,
      builder: (context, snapshot) {
        final players = [...?snapshot.data]
          ..sort((a, b) => _value(b).compareTo(_value(a)));
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _players = AppScope.read(context).loadLeaderboardPlayers();
            });
            await _players;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
            children: [
              const ScreenTitle(
                title: 'Leaderboard',
                subtitle: 'Every public player, ranked across Singles and Team Match.',
              ),
              const SizedBox(height: 16),
              SegmentedButton<_LeaderboardMetric>(
                segments: _LeaderboardMetric.values
                    .map(
                      (metric) => ButtonSegment(
                        value: metric,
                        label: Text(_label(metric)),
                      ),
                    )
                    .toList(),
                selected: {_metric},
                onSelectionChanged: (selected) =>
                    setState(() => _metric = selected.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Leaderboard is unavailable. Pull down to retry.'),
                  ),
                )
              else if (players.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No public players yet.'),
                  ),
                )
              else
                ...players.asMap().entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${entry.key + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PlayerAvatar(player: entry.value, radius: 21),
                        ],
                      ),
                      title: Text(
                        entry.value.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${_value(entry.value)} ${_label(_metric)}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicPlayerProfileScreen(
                            playerId: entry.value.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
