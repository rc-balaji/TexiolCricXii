import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/cricket_match.dart';
import '../domain/daily_performance.dart';
import '../domain/match_planning.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';

class DailyReportOptions {
  const DailyReportOptions({
    this.overview = true,
    this.topThree = true,
    this.overallRanking = true,
    this.playerPerformance = true,
    this.matchSummary = true,
    this.matchRankings = true,
    this.matchIds = const <String>{},
  });

  final bool overview;
  final bool topThree;
  final bool overallRanking;
  final bool playerPerformance;
  final bool matchSummary;
  final bool matchRankings;
  final Set<String> matchIds;

  bool get hasAnySection =>
      overview ||
      topThree ||
      overallRanking ||
      playerPerformance ||
      matchSummary ||
      matchRankings;

  DailyReportOptions copyWith({
    bool? overview,
    bool? topThree,
    bool? overallRanking,
    bool? playerPerformance,
    bool? matchSummary,
    bool? matchRankings,
    Set<String>? matchIds,
  }) => DailyReportOptions(
    overview: overview ?? this.overview,
    topThree: topThree ?? this.topThree,
    overallRanking: overallRanking ?? this.overallRanking,
    playerPerformance: playerPerformance ?? this.playerPerformance,
    matchSummary: matchSummary ?? this.matchSummary,
    matchRankings: matchRankings ?? this.matchRankings,
    matchIds: matchIds ?? this.matchIds,
  );
}

class DailyPerformanceExport {
  const DailyPerformanceExport._();

  static DailyPerformanceSummary selectedSummary(
    DailyPerformanceSummary source,
    DailyReportOptions options,
  ) {
    final selected = source.matches
        .where(
          (match) => options.matchIds.isEmpty || options.matchIds.contains(match.id),
        )
        .toList();
    return DailyPerformanceSummary.build(source.date, selected);
  }

  static Future<File> createPdf(
    DailyPerformanceSummary source,
    Map<String, Player> players, {
    DailyReportOptions options = const DailyReportOptions(),
    Directory? outputDirectory,
  }) async {
    final summary = selectedSummary(source, options);
    final logoData = await rootBundle.load('assets/branding/cricxii_app_icon.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final avatars = <String, pw.MemoryImage?>{};
    for (final row in summary.rankings) {
      final player = players[row.playerId];
      if (player == null) continue;
      try {
        final preset = player.avatarPreset.clamp(1, 5);
        final data = await rootBundle.load('assets/avatars/avatar_$preset.png');
        avatars[player.id] = pw.MemoryImage(data.buffer.asUint8List());
      } on Object {
        avatars[player.id] = null;
      }
    }

    const ink = PdfColor.fromInt(0xFF071A13);
    const green = PdfColor.fromInt(0xFF19C37D);
    const muted = PdfColor.fromInt(0xFF64756D);
    const pale = PdfColor.fromInt(0xFFF0F7F3);
    const line = PdfColor.fromInt(0xFFDCE8E1);
    const gold = PdfColor.fromInt(0xFFF2B84B);
    const silver = PdfColor.fromInt(0xFFE3E8E5);
    const bronze = PdfColor.fromInt(0xFFD7A36D);

    final document = pw.Document(
      title: 'CricXii Daily Performance ${_date(summary.date)}',
      author: 'CricXii by Texiol',
      creator: 'CricXii v1.0.1',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            children: [
              pw.Container(
                width: 34,
                height: 34,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Image(logo, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CRICXII',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'TODAY\'S PERFORMANCE REPORT',
                    style: pw.TextStyle(
                      color: green,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _date(summary.date),
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${summary.matches.length} selected match${summary.matches.length == 1 ? '' : 'es'}',
                    style: const pw.TextStyle(color: muted, fontSize: 6.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CricXii by Texiol | Selected-day performance only',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
              pw.Text(
                'Page ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          if (options.overview) {
            widgets.addAll([
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: ink,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DAY PERFORMANCE',
                            style: pw.TextStyle(
                              color: green,
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            summary.matches.isEmpty
                                ? 'No completed matches selected'
                                : '${summary.matches.length} completed match${summary.matches.length == 1 ? '' : 'es'}',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (summary.rankings.isNotEmpty) ...[
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Leader: ${players[summary.rankings.first.playerId]?.name ?? summary.rankings.first.playerId}',
                              style: const pw.TextStyle(
                                color: PdfColor.fromInt(0xFFB8CCC2),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: pw.BoxDecoration(
                        color: gold,
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${summary.totalPoints}',
                            style: pw.TextStyle(
                              color: ink,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'DAY PTS',
                            style: pw.TextStyle(
                              color: ink,
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  _metric('MATCHES', '${summary.matches.length}', pale, ink, muted),
                  pw.SizedBox(width: 7),
                  _metric('RUNS', '${summary.totalRuns}', pale, ink, muted),
                  pw.SizedBox(width: 7),
                  _metric('WICKETS', '${summary.totalWickets}', pale, ink, muted),
                  pw.SizedBox(width: 7),
                  _metric('CATCHES', '${summary.totalCatches}', pale, ink, muted),
                  pw.SizedBox(width: 7),
                  _metric('POINTS', '${summary.totalPoints}', pale, ink, muted),
                ],
              ),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.topThree && summary.rankings.isNotEmpty) {
            widgets.addAll([
              _section('TOP 3 PLAYERS', ink),
              pw.SizedBox(height: 7),
              pw.Row(
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    if (index < summary.rankings.length)
                      pw.Expanded(
                        child: _podiumCard(
                          rank: index + 1,
                          row: summary.rankings[index],
                          player: players[summary.rankings[index].playerId],
                          image: avatars[summary.rankings[index].playerId],
                          background: index == 0
                              ? gold
                              : index == 1
                              ? silver
                              : bronze,
                          ink: ink,
                          green: green,
                        ),
                      )
                    else
                      pw.Expanded(child: pw.SizedBox()),
                    if (index < 2) pw.SizedBox(width: 7),
                  ],
                ],
              ),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.overallRanking) {
            widgets.addAll([
              _section('OVERALL DAY RANKING', ink),
              pw.SizedBox(height: 7),
              if (summary.rankings.isEmpty)
                pw.Text(
                  'No ranking for the selected matches.',
                  style: const pw.TextStyle(color: muted, fontSize: 9),
                )
              else
                _overallRankingTable(summary, players, avatars, ink, green, pale, line),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.playerPerformance && summary.rankings.isNotEmpty) {
            widgets.addAll([
              _section('PLAYER PERFORMANCE', ink),
              pw.SizedBox(height: 7),
              ...summary.rankings.map((row) {
                final player = players[row.playerId];
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(11),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: line, width: .6),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          _avatar(
                            player,
                            avatars[row.playerId],
                            size: 30,
                            background: green,
                            ink: ink,
                          ),
                          pw.SizedBox(width: 9),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  player?.name ?? row.playerId,
                                  style: pw.TextStyle(
                                    color: ink,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  '${row.matches} matches | ${row.wins} wins | Avg ${row.averagePoints.toStringAsFixed(1)} pts',
                                  style: const pw.TextStyle(color: muted, fontSize: 7),
                                ),
                              ],
                            ),
                          ),
                          pw.Text(
                            '${row.points} PTS',
                            style: pw.TextStyle(
                              color: green,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 7),
                      pw.Text(
                        '${row.runs} runs | ${row.wickets} wickets | ${row.catches} catches | ${row.directRunOuts + row.assistedRunOuts} run-outs | Best ${row.bestPoints} pts',
                        style: pw.TextStyle(
                          color: ink,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: row.matchBreakdown
                            .map(
                              (match) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: pale,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  '${match.title}: ${match.runs}R / ${match.points}P',
                                  style: const pw.TextStyle(color: muted, fontSize: 6.5),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 10),
            ]);
          }

          if (options.matchSummary && summary.matches.isNotEmpty) {
            widgets.addAll([
              _section('MATCH-WISE SUMMARY', ink),
              pw.SizedBox(height: 7),
              _matchSummaryTable(summary.matches, players, ink, green, pale, line),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.matchRankings && summary.matches.isNotEmpty) {
            widgets.addAll([
              _section('FULL MATCH RANKINGS', ink),
              pw.SizedBox(height: 7),
            ]);
            for (var index = 0; index < summary.matches.length; index++) {
              final match = summary.matches[index];
              final rankings = ScoringEngine.rankings(match);
              final winner = rankings.isEmpty ? null : rankings.first;
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4, bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: pale,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 22,
                        height: 22,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: ink,
                          borderRadius: pw.BorderRadius.circular(7),
                        ),
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              match.title,
                              style: pw.TextStyle(
                                color: ink,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '${match.id} | ${_time(match.startedAt ?? match.createdAt)} | ${OversFormat.setupOversLabel(match.ballLimit)} (${match.ballLimit} balls)',
                              style: const pw.TextStyle(color: muted, fontSize: 6.5),
                            ),
                          ],
                        ),
                      ),
                      if (winner != null)
                        pw.Text(
                          'WINNER: ${players[winner.playerId]?.name ?? winner.playerId} | ${winner.points} PTS',
                          style: pw.TextStyle(
                            color: green,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
              widgets.add(
                pw.Table(
                  border: pw.TableBorder.all(color: line, width: .5),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(28),
                    1: pw.FlexColumnWidth(2.4),
                    2: pw.FlexColumnWidth(.9),
                    3: pw.FlexColumnWidth(.9),
                    4: pw.FlexColumnWidth(.9),
                    5: pw.FlexColumnWidth(.9),
                  },
                  children: [
                    _tableHeader(['#', 'PLAYER', 'RUNS', 'BALLS', 'WKTS', 'PTS'], ink),
                    ...rankings.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final row = entry.value;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: rank == 1 ? pale : PdfColors.white,
                        ),
                        children: [
                          _cell('$rank', bold: true, color: ink),
                          _cell(players[row.playerId]?.name ?? row.playerId, bold: true, color: ink),
                          _cell('${row.runs}', color: ink),
                          _cell('${row.balls}', color: ink),
                          _cell('${row.wickets}', color: ink),
                          _cell('${row.points}', bold: true, color: green),
                        ],
                      );
                    }),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 12));
            }
          }

          if (widgets.isEmpty) {
            widgets.add(
              pw.Text(
                'No report sections were selected.',
                style: const pw.TextStyle(color: muted, fontSize: 10),
              ),
            );
          }
          return widgets;
        },
      ),
    );

    final directory = outputDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File(
      '${directory.path}/CricXii_${summary.date.year}-${summary.date.month.toString().padLeft(2, '0')}-${summary.date.day.toString().padLeft(2, '0')}_Performance.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  static Future<File> savePdf(
    DailyPerformanceSummary summary,
    Map<String, Player> players, {
    DailyReportOptions options = const DailyReportOptions(),
  }) async {
    Directory directory;
    try {
      directory =
          await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } on Object {
      directory = await getApplicationDocumentsDirectory();
    }
    return createPdf(
      summary,
      players,
      options: options,
      outputDirectory: directory,
    );
  }

  static Future<void> sharePdf(
    DailyPerformanceSummary summary,
    Map<String, Player> players, {
    DailyReportOptions options = const DailyReportOptions(),
  }) async {
    final selected = selectedSummary(summary, options);
    final file = await createPdf(summary, players, options: options);
    await SharePlus.instance.share(
      ShareParams(
        subject: 'CricXii daily performance - ${_date(selected.date)}',
        text:
            'CricXii daily performance: ${selected.matches.length} matches, ${selected.totalRuns} runs, ${selected.totalWickets} wickets, ${selected.totalPoints} day points.',
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.Widget _overallRankingTable(
    DailyPerformanceSummary summary,
    Map<String, Player> players,
    Map<String, pw.MemoryImage?> avatars,
    PdfColor ink,
    PdfColor green,
    PdfColor pale,
    PdfColor line,
  ) => pw.Table(
    border: pw.TableBorder.all(color: line, width: .5),
    columnWidths: const {
      0: pw.FixedColumnWidth(28),
      1: pw.FlexColumnWidth(2.4),
      2: pw.FlexColumnWidth(.9),
      3: pw.FlexColumnWidth(.9),
      4: pw.FlexColumnWidth(.9),
      5: pw.FlexColumnWidth(.9),
    },
    children: [
      _tableHeader(['#', 'PLAYER', 'MATCH', 'RUNS', 'WKTS', 'PTS'], ink),
      ...summary.rankings.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final row = entry.value;
        final player = players[row.playerId];
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: rank == 1 ? pale : PdfColors.white),
          children: [
            _cell('$rank', bold: true, color: ink),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  _avatar(
                    player,
                    avatars[row.playerId],
                    size: 22,
                    background: green,
                    ink: ink,
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      player?.name ?? row.playerId,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _cell('${row.matches}', color: ink),
            _cell('${row.runs}', bold: true, color: ink),
            _cell('${row.wickets}', bold: true, color: ink),
            _cell('${row.points}', bold: true, color: green),
          ],
        );
      }),
    ],
  );

  static pw.Widget _matchSummaryTable(
    List<CricketMatch> matches,
    Map<String, Player> players,
    PdfColor ink,
    PdfColor green,
    PdfColor pale,
    PdfColor line,
  ) => pw.Table(
    border: pw.TableBorder.all(color: line, width: .5),
    columnWidths: const {
      0: pw.FixedColumnWidth(24),
      1: pw.FlexColumnWidth(2.1),
      2: pw.FlexColumnWidth(1.35),
      3: pw.FlexColumnWidth(1.4),
      4: pw.FlexColumnWidth(1.7),
      5: pw.FlexColumnWidth(.8),
      6: pw.FlexColumnWidth(.75),
    },
    children: [
      _tableHeader(['#', 'MATCH', 'TIME', 'OVERS/BALLS', 'WINNER', 'PTS', 'PLAYERS'], ink),
      ...matches.asMap().entries.map((entry) {
        final match = entry.value;
        final rankings = ScoringEngine.rankings(match);
        final winner = rankings.isEmpty ? null : rankings.first;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: entry.key.isEven ? pale : PdfColors.white,
          ),
          children: [
            _cell('${entry.key + 1}', bold: true, color: ink),
            _cell('${match.title}\n${match.id}', bold: true, color: ink),
            _cell(
              '${_time(match.startedAt ?? match.createdAt)}\n${_time(match.completedAt ?? match.createdAt)}',
              color: ink,
            ),
            _cell('${OversFormat.setupOversLabel(match.ballLimit)}\n${match.ballLimit} balls', color: ink),
            _cell(
              winner == null ? '-' : (players[winner.playerId]?.name ?? winner.playerId),
              bold: true,
              color: ink,
            ),
            _cell(winner == null ? '-' : '${winner.points}', bold: true, color: green),
            _cell('${match.participantIds.length}', color: ink),
          ],
        );
      }),
    ],
  );

  static pw.Widget _podiumCard({
    required int rank,
    required DailyPlayerPerformance row,
    required Player? player,
    required pw.MemoryImage? image,
    required PdfColor background,
    required PdfColor ink,
    required PdfColor green,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            _avatar(player, image, size: 28, background: green, ink: ink),
            pw.Spacer(),
            pw.Text(
              '#$rank',
              style: pw.TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 7),
        pw.Text(
          player?.name ?? row.playerId,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          '${row.points} PTS | ${row.runs} R | ${row.wickets} W',
          style: pw.TextStyle(
            color: ink,
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _metric(
    String label,
    String value,
    PdfColor background,
    PdfColor ink,
    PdfColor muted,
  ) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 5.5)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _section(String label, PdfColor ink) => pw.Text(
    label,
    style: pw.TextStyle(
      color: ink,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: .8,
    ),
  );

  static pw.TableRow _tableHeader(List<String> labels, PdfColor ink) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: ink),
        children: labels
            .map(
              (label) => pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      );

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    required PdfColor color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: color,
        fontSize: 6.7,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  static pw.Widget _avatar(
    Player? player,
    pw.MemoryImage? image, {
    required double size,
    required PdfColor background,
    required PdfColor ink,
  }) {
    if (image != null) {
      return pw.ClipOval(
        child: pw.Image(image, width: size, height: size, fit: pw.BoxFit.cover),
      );
    }
    final letter = player?.name.trim().isEmpty ?? true
        ? 'P'
        : player!.name.trim()[0].toUpperCase();
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(size / 2),
      ),
      child: pw.Text(
        letter,
        style: pw.TextStyle(
          color: ink,
          fontSize: size * .38,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
