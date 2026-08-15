import 'package:flutter/material.dart';

import '../domain/daily_performance.dart';
import '../domain/player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import 'daily_report_builder_screen.dart';
import 'match_summary_screen.dart';
import 'public_player_profile_screen.dart';
import 'team_match_summary_screen.dart';

class DailyPerformanceScreen extends StatefulWidget {
  const DailyPerformanceScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<DailyPerformanceScreen> createState() => _DailyPerformanceScreenState();
}

class _DailyPerformanceScreenState extends State<DailyPerformanceScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final value = widget.initialDate ?? DateTime.now();
    _date = DateTime(value.year, value.month, value.day);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (value != null && mounted) {
      setState(() => _date = DateTime(value.year, value.month, value.day));
    }
  }

  Map<String, Player> _playerMap() {
    final store = AppScope.read(context);
    return <String, Player>{for (final player in store.players) player.id: player};
  }

  void _openReportBuilder() {
    final store = AppScope.read(context);
    final summary = store.performanceForDate(_date);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyReportBuilderScreen(
          summary: summary,
          players: _playerMap(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final summary = store.performanceForDate(_date);
    final rankings = summary.rankings;
    final leader = rankings.isEmpty ? null : store.playerById(rankings.first.playerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            tooltip: 'Choose date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isToday(_date) ? 'Today’s performance' : 'Daily performance',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _dateLabel(_date),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(25),
            ),
            child: rankings.isEmpty
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NO COMPLETED MATCHES',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete a Singles or Team Match to build the day’s performance report.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (leader != null) PlayerAvatar(player: leader, radius: 34),
                      if (leader != null) const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OVERALL LEADER',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              leader?.name ?? rankings.first.playerId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${rankings.first.runs} runs • ${rankings.first.wickets} wickets',
                              style: const TextStyle(
                                color: Color(0xFFB8CCC2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${rankings.first.points}\nPTS',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 21,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 2.2,
            children: [
              _Metric(label: 'Matches', value: '${summary.matches.length}'),
              _Metric(label: 'Runs', value: '${summary.totalRuns}'),
              _Metric(label: 'Wickets', value: '${summary.totalWickets}'),
              _Metric(label: 'Catches', value: '${summary.totalCatches}'),
              _Metric(label: 'Day points', value: '${summary.totalPoints}'),
              _Metric(
                label: 'Players',
                value: '${summary.rankings.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'OVERALL RANKING',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (rankings.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No ranking for this date.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...rankings.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final row = entry.value;
              final player = store.playerById(row.playerId);
              if (player == null) return const SizedBox.shrink();
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => openPlayerProfile(context, player.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: rank == 1
                              ? AppColors.gold
                              : const Color(0xFFE8EFEB),
                          child: Text(
                            '$rank',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PlayerAvatar(player: player, radius: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${row.matches} matches • ${row.runs} runs • ${row.wickets} WKTS • Avg ${row.averagePoints.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${row.points} PTS',
                          style: const TextStyle(
                            color: AppColors.greenDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'MATCHES',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (summary.matches.isEmpty)
            const Text(
              'No completed matches.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...summary.matches.asMap().entries.map((entry) {
              final match = entry.value;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(
                    match.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${match.isSingles ? 'Singles' : 'Team Match'} • ${_time(match.startedAt)} → ${_time(match.completedAt)} • ${match.resultLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => match.type == DailyMatchType.singles
                          ? MatchSummaryScreen(matchId: match.id)
                          : TeamMatchSummaryScreen(matchId: match.id),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: summary.matches.isEmpty ? null : _openReportBuilder,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Build / preview / share PDF'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose report sections and matches first, preview them, then share or download the PDF.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year && now.month == date.month && now.day == date.day;
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E9E4)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
}
