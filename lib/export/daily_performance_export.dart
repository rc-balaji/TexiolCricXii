import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/avatar_image_repository.dart';
import '../domain/cricket_match.dart';
import '../domain/daily_performance.dart';
import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/singles_scorecard.dart';
import '../domain/team_match.dart';
import '../domain/team_scorecard.dart';
import '../domain/team_scoring_engine.dart';

class DailyReportOptions {
  const DailyReportOptions({
    this.overview = true,
    this.topThree = true,
    this.overallRanking = true,
    this.playerPerformance = true,
    this.matchSummary = true,
    this.matchRankings = true,
    this.matchKeys = const <String>{},
  });

  final bool overview;
  final bool topThree;
  final bool overallRanking;
  final bool playerPerformance;
  final bool matchSummary;
  final bool matchRankings;
  final Set<String> matchKeys;

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
    Set<String>? matchKeys,
  }) =>
      DailyReportOptions(
        overview: overview ?? this.overview,
        topThree: topThree ?? this.topThree,
        overallRanking: overallRanking ?? this.overallRanking,
        playerPerformance: playerPerformance ?? this.playerPerformance,
        matchSummary: matchSummary ?? this.matchSummary,
        matchRankings: matchRankings ?? this.matchRankings,
        matchKeys: matchKeys ?? this.matchKeys,
      );
}

class DailyPerformanceExport {
  const DailyPerformanceExport._();

  static DailyPerformanceSummary selectedSummary(
    DailyPerformanceSummary summary,
    DailyReportOptions options,
  ) {
    if (options.matchKeys.isEmpty) {
      return DailyPerformanceSummary(date: summary.date, matches: const []);
    }
    return summary.selected(options.matchKeys);
  }

  static Future<File> createPdf(
    DailyPerformanceSummary source,
    Map<String, Player> players, {
    DailyReportOptions options = const DailyReportOptions(),
    Directory? outputDirectory,
  }) async {
    final summary = selectedSummary(source, options);
    if (summary.matches.isEmpty) {
      throw StateError('Select at least one completed match.');
    }
    if (!options.hasAnySection) {
      throw StateError('Select at least one report section.');
    }

    final logoData = await rootBundle.load('assets/branding/cricxii_app_icon.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final avatarIds = summary.matches
        .expand((match) => match.rankings.map((row) => row.playerId))
        .toSet();
    final avatarEntries = await Future.wait(
      avatarIds.map((id) async {
        final player = players[id];
        if (player == null) return null;
        return MapEntry<String, pw.MemoryImage?>(id, await _avatarFor(player));
      }),
    );
    final avatars = <String, pw.MemoryImage?>{
      for (final entry in avatarEntries)
        if (entry != null) entry.key: entry.value,
    };
    const ink = PdfColor.fromInt(0xFF071A13);
    const green = PdfColor.fromInt(0xFF087A4B);
    const accent = PdfColor.fromInt(0xFF19C37D);
    const muted = PdfColor.fromInt(0xFF64756D);
    const pale = PdfColor.fromInt(0xFFF0F7F3);
    const goldPale = PdfColor.fromInt(0xFFFFF4D8);
    const line = PdfColor.fromInt(0xFFDCE8E1);

    final document = pw.Document(
      title: 'CricXii ${summary.reportTitle} ${_isoDate(summary.date)}',
      author: 'CricXii by Texiol',
      creator: 'CricXii Daily Performance',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 24),
        header: (_) => pw.Row(
          children: [
            pw.Container(
              width: 28,
              height: 28,
              child: pw.Image(logo, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CRICXII',
                  style: pw.TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'TODAY PERFORMANCE',
                  style: const pw.TextStyle(color: muted, fontSize: 6.5),
                ),
              ],
            ),
          ],
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CricXii | Selected completed matches only',
                style: const pw.TextStyle(color: muted, fontSize: 7),
              ),
              pw.Text(
                '${_isoDate(summary.date)} | Page ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 7),
              ),
            ],
          ),
        ),
        build: (_) {
          final widgets = <pw.Widget>[];
          if (options.overview) {
            widgets.addAll([
              pw.SizedBox(height: 12),
              pw.Text(
                summary.reportTitle,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '${_date(summary.date)} | ${summary.matches.length} selected | ${summary.singlesCount} Singles | ${summary.teamCount} Team Match',
                style: const pw.TextStyle(color: muted, fontSize: 8.5),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: ink,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${summary.totalPoints} DAY POINTS',
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${summary.totalRuns} runs | ${summary.totalWickets} wickets | ${summary.totalCatches} catches | ${summary.rankings.length} players',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(child: _metric('MATCHES', '${summary.matches.length}', pale, ink, muted)),
                  pw.SizedBox(width: 7),
                  pw.Expanded(child: _metric('SINGLES', '${summary.singlesCount}', pale, ink, muted)),
                  pw.SizedBox(width: 7),
                  pw.Expanded(child: _metric('TEAM', '${summary.teamCount}', goldPale, ink, muted)),
                  pw.SizedBox(width: 7),
                  pw.Expanded(child: _metric('PLAYERS', '${summary.rankings.length}', pale, ink, muted)),
                ],
              ),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.topThree && summary.rankings.isNotEmpty) {
            widgets.addAll([
              _section('TOP 3', ink),
              pw.SizedBox(height: 7),
              ...summary.rankings.take(3).toList().asMap().entries.map((entry) {
                final row = entry.value;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(9),
                  decoration: pw.BoxDecoration(
                    color: entry.key == 0 ? goldPale : pale,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 24,
                        height: 24,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: ink,
                          borderRadius: pw.BorderRadius.circular(7),
                        ),
                        child: pw.Text(
                          '#${entry.key + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Text(
                          players[row.playerId]?.name ?? row.playerId,
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${row.runs}R | ${row.wickets}W | ${row.points} PTS',
                        style: pw.TextStyle(
                          color: green,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 12),
            ]);
          }

          if (options.overallRanking && summary.rankings.isNotEmpty) {
            widgets.addAll([
              _section('OVERALL RANKINGS', ink),
              pw.SizedBox(height: 7),
              _overallRankingTable(summary, players, ink, green, pale, line),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.playerPerformance && summary.rankings.isNotEmpty) {
            widgets.addAll([
              _section('PLAYER PERFORMANCE', ink),
              pw.SizedBox(height: 7),
              ...summary.rankings.map((row) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 7),
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: line, width: .6),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                players[row.playerId]?.name ?? row.playerId,
                                style: pw.TextStyle(
                                  color: ink,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '${row.points} PTS',
                              style: pw.TextStyle(
                                color: green,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${row.matches} matches | ${row.wins} wins | ${row.runs} runs | ${row.wickets} wickets | ${row.catches} catches | Avg ${row.averagePoints.toStringAsFixed(1)} pts',
                          style: const pw.TextStyle(color: muted, fontSize: 7),
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
                                    color: match.type == DailyMatchType.team
                                        ? goldPale
                                        : pale,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                  child: pw.Text(
                                    '${match.type == DailyMatchType.team ? 'TEAM' : 'SINGLES'} | ${match.title}: ${match.runs}R / ${match.wickets}W / ${match.points}P',
                                    style: const pw.TextStyle(
                                      color: muted,
                                      fontSize: 6.2,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 12),
            ]);
          }

          if (options.matchSummary && summary.matches.isNotEmpty) {
            widgets.addAll([
              _section('MATCH-WISE RESULTS', ink),
              pw.SizedBox(height: 7),
              _matchSummaryTable(summary.matches, players, ink, green, pale, goldPale, line),
              pw.SizedBox(height: 16),
            ]);
          }

          if (options.matchRankings && summary.matches.isNotEmpty) {
            widgets.addAll([
              _section('FULL SCORECARDS + RANKINGS', ink),
              pw.SizedBox(height: 7),
            ]);
            for (var index = 0; index < summary.matches.length; index++) {
              final match = summary.matches[index];
              widgets.addAll(
                _fullMatchSection(
                  index + 1,
                  match,
                  players,
                  avatars,
                  ink: ink,
                  green: green,
                  muted: muted,
                  pale: pale,
                  goldPale: goldPale,
                  line: line,
                ),
              );
              widgets.add(pw.SizedBox(height: 16));
            }
          }
          return widgets;
        },
      ),
    );

    final directory = outputDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    final kind = summary.singlesCount > 0 && summary.teamCount > 0
        ? 'Overall'
        : summary.teamCount > 0
            ? 'Team'
            : 'Singles';
    final file = File(
      '${directory.path}/CricXii-Today-$kind-${_isoDate(summary.date)}.pdf',
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
        subject: 'CricXii ${selected.reportTitle} - ${_date(selected.date)}',
        text:
            '${selected.reportTitle}: ${selected.matches.length} matches (${selected.singlesCount} Singles, ${selected.teamCount} Team), ${selected.totalRuns} runs, ${selected.totalWickets} wickets, ${selected.totalPoints} points.',
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static List<pw.Widget> _fullMatchSection(
    int number,
    DailyMatchEntry entry,
    Map<String, Player> players,
    Map<String, pw.MemoryImage?> avatars, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
    required PdfColor pale,
    required PdfColor goldPale,
    required PdfColor line,
  }) {
    final widgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: entry.isTeam ? goldPale : pale,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 24,
              height: 24,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: ink,
                borderRadius: pw.BorderRadius.circular(7),
              ),
              child: pw.Text(
                '$number',
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
                    entry.title,
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${entry.isTeam ? 'TEAM MATCH' : 'SINGLES'} | ${_time(entry.startedAt)} - ${_time(entry.completedAt)} | ${entry.id}',
                    style: pw.TextStyle(color: muted, fontSize: 6.5),
                  ),
                ],
              ),
            ),
            pw.SizedBox(
              width: 145,
              child: pw.Text(
                _resultLabel(entry, players),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  color: green,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 7),
    ];

    if (entry.teamMatch != null) {
      widgets.addAll(
        _teamMatchDetails(
          entry.teamMatch!,
          entry,
          players,
          avatars,
          ink: ink,
          green: green,
          muted: muted,
          pale: pale,
          line: line,
        ),
      );
    } else if (entry.singlesMatch != null) {
      widgets.addAll(
        _singlesMatchDetails(
          entry.singlesMatch!,
          entry,
          players,
          avatars,
          ink: ink,
          green: green,
          muted: muted,
          pale: pale,
          line: line,
        ),
      );
    } else {
      widgets.add(
        _rankingTable(entry.rankings, players, ink, green, pale, line),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _singlesMatchDetails(
    CricketMatch match,
    DailyMatchEntry entry,
    Map<String, Player> players,
    Map<String, pw.MemoryImage?> avatars, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
    required PdfColor pale,
    required PdfColor line,
  }) {
    final data = SinglesScorecardBuilder.build(match);
    String name(String id) => players[id]?.name ?? id;
    final widgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        color: green,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'SINGLES MATCH SCORECARD',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.4,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              '${data.batters.length} players',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 7),
            ),
          ],
        ),
      ),
      _scorecardTable(
        const ['', 'BATTER', '', 'R', 'B', '4s', '6s', 'SR'],
        data.batters
            .map(
              (row) => [
                name(row.playerId),
                row.dismissal.text(name),
                '${row.runs}',
                row.ballDataAvailable ? '${row.balls}' : '-',
                row.ballDataAvailable ? '${row.fours}' : '-',
                row.ballDataAvailable ? '${row.sixes}' : '-',
                row.ballDataAvailable && row.balls > 0
                    ? row.strikeRate.toStringAsFixed(2)
                    : '-',
              ],
            )
            .toList(growable: false),
        ink: ink,
        muted: muted,
        line: line,
        columnWidths: const {
          0: pw.FixedColumnWidth(23),
          1: pw.FlexColumnWidth(2.2),
          2: pw.FlexColumnWidth(2.6),
          3: pw.FlexColumnWidth(.65),
          4: pw.FlexColumnWidth(.65),
          5: pw.FlexColumnWidth(.65),
          6: pw.FlexColumnWidth(.65),
          7: pw.FlexColumnWidth(.95),
        },
        playerIds: data.batters.map((row) => row.playerId).toList(growable: false),
        players: players,
        avatars: avatars,
      ),
      _scoreSummaryRow(
        'Extras',
        '${data.extras} (${data.extrasBreakdown})',
        ink: ink,
        line: line,
      ),
      _scoreSummaryRow(
        'Recorded Runs',
        '${data.aggregateRuns} batter runs across all turns',
        ink: ink,
        line: line,
        bold: true,
      ),
    ];

    if (data.bowlers.isNotEmpty && match.scoringMode == ScoringMode.ballByBall) {
      widgets.addAll([
        pw.SizedBox(height: 7),
        _scorecardTable(
          const ['', 'BOWLER', 'O', 'R', 'W', 'NB', 'WD', 'ECO'],
          data.bowlers
              .map(
                (row) => [
                  name(row.playerId),
                  row.overs,
                  '${row.runs}',
                  '${row.wickets}',
                  '${row.noBalls}',
                  '${row.wides}',
                  row.economy.toStringAsFixed(2),
                ],
              )
              .toList(growable: false),
          ink: ink,
          muted: muted,
          line: line,
          columnWidths: const {
            0: pw.FixedColumnWidth(23),
            1: pw.FlexColumnWidth(2.45),
            2: pw.FlexColumnWidth(.72),
            3: pw.FlexColumnWidth(.72),
            4: pw.FlexColumnWidth(.72),
            5: pw.FlexColumnWidth(.72),
            6: pw.FlexColumnWidth(.72),
            7: pw.FlexColumnWidth(.95),
          },
          playerIds: data.bowlers.map((row) => row.playerId).toList(growable: false),
          players: players,
          avatars: avatars,
        ),
      ]);
    }

    widgets.addAll([
      pw.SizedBox(height: 8),
      pw.Text(
        'FINAL RANKING',
        style: pw.TextStyle(
          color: ink,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 5),
      _rankingTable(entry.rankings, players, ink, green, pale, line),
    ]);
    return widgets;
  }

  static List<pw.Widget> _teamMatchDetails(
    TeamMatch match,
    DailyMatchEntry entry,
    Map<String, Player> players,
    Map<String, pw.MemoryImage?> avatars, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
    required PdfColor pale,
    required PdfColor line,
  }) {
    final pomId = TeamScoringEngine.playerOfMatchId(match);
    final widgets = <pw.Widget>[
      pw.Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          _smallInfo('RESULT', TeamScoringEngine.result(match).summary, pale, ink, muted),
          _smallInfo('TOSS / START', _tossLabel(match), pale, ink, muted),
          _smallInfo(
            'JOKER',
            match.commonJokerPlayerId == null
                ? 'Not used'
                : players[match.commonJokerPlayerId]?.name ?? match.commonJokerPlayerId!,
            pale,
            ink,
            muted,
          ),
          _smallInfo(
            'PLAYER OF MATCH',
            pomId == null ? 'Not available' : players[pomId]?.name ?? pomId,
            pale,
            ink,
            muted,
          ),
        ],
      ),
      pw.SizedBox(height: 8),
    ];

    String name(String id) {
      final value = players[id]?.name ?? id;
      final side = match.teamA.playerIds.contains(id) ? match.teamA : match.teamB;
      final tags = <String>[
        if (side.captainPlayerId == id) 'c',
        if (side.wicketkeeperPlayerId == id) 'wk',
        if (id == match.commonJokerPlayerId) 'J',
      ];
      return tags.isEmpty ? value : '$value (${tags.join(', ')})';
    }

    for (final innings in match.innings) {
      final batting = match.side(innings.battingTeamId);
      final data = TeamScorecardBuilder.build(match, innings);
      widgets.addAll([
        pw.Container(
          width: double.infinity,
          color: green,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${batting.name} ${TeamScoringEngine.inningsLabel(innings)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.4,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${data.total}-${data.wickets} (${data.overs} Ov)',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.4,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (innings.target != null)
          pw.Container(
            width: double.infinity,
            color: pale,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              'Target ${innings.target}${innings.completionReason == null ? '' : ' | ${innings.completionReason}'}',
              style: pw.TextStyle(color: green, fontSize: 6.6),
            ),
          ),
        _scorecardTable(
          const ['', 'BATTER', '', 'R', 'B', '4s', '6s', 'SR'],
          data.batters
              .map(
                (row) => [
                  name(row.playerId),
                  row.dismissal.text(name),
                  '${row.runs}',
                  '${row.balls}',
                  '${row.fours}',
                  '${row.sixes}',
                  row.strikeRate.toStringAsFixed(2),
                ],
              )
              .toList(growable: false),
          ink: ink,
          muted: muted,
          line: line,
          columnWidths: const {
            0: pw.FixedColumnWidth(23),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(2.6),
            3: pw.FlexColumnWidth(.65),
            4: pw.FlexColumnWidth(.65),
            5: pw.FlexColumnWidth(.65),
            6: pw.FlexColumnWidth(.65),
            7: pw.FlexColumnWidth(.95),
          },
          playerIds: data.batters.map((row) => row.playerId).toList(growable: false),
          players: players,
          avatars: avatars,
        ),
        _scoreSummaryRow(
          'Extras',
          '${data.extras} (${data.extrasBreakdown})',
          ink: ink,
          line: line,
        ),
        _scoreSummaryRow(
          'Total',
          '${data.total}-${data.wickets} (${data.overs} Overs, RR: ${data.runRate.toStringAsFixed(2)})',
          ink: ink,
          line: line,
          bold: true,
        ),
        if (data.yetToBat.isNotEmpty)
          _scoreSummaryRow(
            'Yet to Bat',
            data.yetToBat.map(name).join(', '),
            ink: ink,
            line: line,
            valueColor: green,
          ),
      ]);

      if (data.bowlers.isNotEmpty) {
        widgets.addAll([
          pw.SizedBox(height: 6),
          _scorecardTable(
            const ['', 'BOWLER', 'O', 'M', 'R', 'W', 'NB', 'WD', 'ECO'],
            data.bowlers
                .map(
                  (row) => [
                    name(row.playerId),
                    row.overs,
                    '${row.maidens}',
                    '${row.runs}',
                    '${row.wickets}',
                    '${row.noBalls}',
                    '${row.wides}',
                    row.economy.toStringAsFixed(2),
                  ],
                )
                .toList(growable: false),
            ink: ink,
            muted: muted,
            line: line,
            columnWidths: const {
              0: pw.FixedColumnWidth(23),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(.72),
              3: pw.FlexColumnWidth(.65),
              4: pw.FlexColumnWidth(.65),
              5: pw.FlexColumnWidth(.65),
              6: pw.FlexColumnWidth(.7),
              7: pw.FlexColumnWidth(.7),
              8: pw.FlexColumnWidth(.92),
            },
            playerIds: data.bowlers.map((row) => row.playerId).toList(growable: false),
            players: players,
            avatars: avatars,
          ),
        ]);
      }

      if (data.falls.isNotEmpty) {
        widgets.addAll([
          pw.SizedBox(height: 6),
          _scorecardTable(
            const ['FALL OF WICKETS', 'SCORE', 'OVER'],
            data.falls
                .map((fall) => [name(fall.playerId), fall.scoreLabel, fall.overLabel])
                .toList(growable: false),
            ink: ink,
            muted: muted,
            line: line,
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.1),
            },
          ),
        ]);
      }

      if (data.partnerships.isNotEmpty) {
        widgets.addAll([
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            color: const PdfColor.fromInt(0xFFE9E7E7),
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: pw.Text(
              'PARTNERSHIPS',
              style: pw.TextStyle(
                color: ink,
                fontSize: 6.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          ...data.partnerships.map(
            (partnership) => pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line, width: .45)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      partnership.playerIds
                          .map(
                            (id) =>
                                '${name(id)} ${partnership.runsByPlayer[id] ?? 0}(${partnership.ballsByPlayer[id] ?? 0})',
                          )
                          .join(' | '),
                      style: pw.TextStyle(color: green, fontSize: 6.4),
                    ),
                  ),
                  pw.Text(
                    '${partnership.runs}(${partnership.balls})',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]);
      }
      widgets.add(pw.SizedBox(height: 9));
    }

    widgets.addAll([
      pw.Text(
        'TEAM MATCH PLAYER RANKING',
        style: pw.TextStyle(
          color: ink,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 5),
      _rankingTable(entry.rankings, players, ink, green, pale, line),
    ]);
    return widgets;
  }

  static pw.Widget _scorecardTable(
    List<String> headers,
    List<List<String>> rows, {
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required Map<int, pw.TableColumnWidth> columnWidths,
    List<String>? playerIds,
    Map<String, Player>? players,
    Map<String, pw.MemoryImage?>? avatars,
  }) => pw.Table(
    border: pw.TableBorder.all(color: line, width: .45),
    columnWidths: columnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFE9E7E7),
        ),
        children: headers
            .map(
              (value) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    color: ink,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...rows.asMap().entries.map((rowEntry) {
        final row = rowEntry.value;
        final playerId = playerIds == null || rowEntry.key >= playerIds.length
            ? null
            : playerIds[rowEntry.key];
        final player = playerId == null ? null : players?[playerId];
        return pw.TableRow(
          children: [
            if (playerIds != null)
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: player == null
                    ? pw.SizedBox(width: 17, height: 17)
                    : _pdfAvatar(player, avatars?[player.id], size: 17),
              ),
            ...row.asMap().entries.map(
              (cell) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
                child: pw.Text(
                  cell.value,
                  textAlign: cell.key < 2 ? pw.TextAlign.left : pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: cell.key == 0
                        ? const PdfColor.fromInt(0xFF0B5FFF)
                        : cell.key == 1
                            ? muted
                            : ink,
                    fontSize: 6.6,
                    fontWeight: cell.key == 2 || cell.key == 4
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    ],
  );

  static pw.Widget _scoreSummaryRow(
    String label,
    String value, {
    required PdfColor ink,
    required PdfColor line,
    bool bold = false,
    PdfColor? valueColor,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: line, width: .45),
        right: pw.BorderSide(color: line, width: .45),
        bottom: pw.BorderSide(color: line, width: .45),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 84,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              color: ink,
              fontSize: 6.7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor ?? ink,
              fontSize: 6.7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _rankingTable(
    List<DailyMatchStanding> rankings,
    Map<String, Player> players,
    PdfColor ink,
    PdfColor green,
    PdfColor pale,
    PdfColor line,
  ) =>
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
            final row = entry.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: entry.key == 0 ? pale : PdfColors.white,
              ),
              children: [
                _cell('${entry.key + 1}', bold: true, color: ink),
                _cell(players[row.playerId]?.name ?? row.playerId, bold: true, color: ink),
                _cell('${row.runs}', color: ink),
                _cell('${row.balls}', color: ink),
                _cell('${row.wickets}', color: ink),
                _cell('${row.points}', bold: true, color: green),
              ],
            );
          }),
        ],
      );

  static pw.Widget _overallRankingTable(
    DailyPerformanceSummary summary,
    Map<String, Player> players,
    PdfColor ink,
    PdfColor green,
    PdfColor pale,
    PdfColor line,
  ) =>
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
          _tableHeader(['#', 'PLAYER', 'MATCH', 'RUNS', 'WKTS', 'PTS'], ink),
          ...summary.rankings.asMap().entries.map((entry) {
            final row = entry.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: entry.key == 0 ? pale : PdfColors.white,
              ),
              children: [
                _cell('${entry.key + 1}', bold: true, color: ink),
                _cell(players[row.playerId]?.name ?? row.playerId, bold: true, color: ink),
                _cell('${row.matches}', color: ink),
                _cell('${row.runs}', color: ink),
                _cell('${row.wickets}', color: ink),
                _cell('${row.points}', bold: true, color: green),
              ],
            );
          }),
        ],
      );

  static String _resultLabel(
    DailyMatchEntry entry,
    Map<String, Player> players,
  ) {
    if (!entry.isSingles || entry.rankings.isEmpty) return entry.resultLabel;
    final winner = entry.rankings.first;
    final name = players[winner.playerId]?.name ?? winner.playerId;
    return '$name won | ${winner.points} PTS';
  }

  static pw.Widget _pdfAvatar(
    Player player,
    pw.MemoryImage? image, {
    required double size,
  }) => pw.Container(
    width: size,
    height: size,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(player.avatarColor),
      borderRadius: pw.BorderRadius.circular(size * .24),
    ),
    child: image != null
        ? pw.Image(image, width: size, height: size, fit: pw.BoxFit.cover)
        : pw.Text(
            player.initials,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: size * .28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
  );

  static Future<pw.MemoryImage?> _avatarFor(Player player) async {
    if (player.avatarSource == AvatarSource.customUrl) {
      final exact = await AvatarImageRepository.loadCustomBytes(player);
      if (exact != null && exact.isNotEmpty) {
        try {
          return pw.MemoryImage(exact);
        } on Object {
          // Unsupported image encodings fall back to the preset in PDFs.
        }
      }
    }
    try {
      final preset = player.avatarPreset.clamp(1, 5);
      final data = await rootBundle.load('assets/avatars/avatar_$preset.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } on Object {
      return null;
    }
  }

  static pw.Widget _matchSummaryTable(
    List<DailyMatchEntry> matches,
    Map<String, Player> players,
    PdfColor ink,
    PdfColor green,
    PdfColor pale,
    PdfColor goldPale,
    PdfColor line,
  ) =>
      pw.Table(
        border: pw.TableBorder.all(color: line, width: .5),
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(2.2),
          2: pw.FlexColumnWidth(.9),
          3: pw.FlexColumnWidth(2.3),
          4: pw.FlexColumnWidth(.8),
        },
        children: [
          _tableHeader(['#', 'MATCH', 'TYPE', 'RESULT', 'PLAYERS'], ink),
          ...matches.asMap().entries.map((entry) {
            final match = entry.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: match.isTeam ? goldPale : (entry.key.isEven ? pale : PdfColors.white),
              ),
              children: [
                _cell('${entry.key + 1}', bold: true, color: ink),
                _cell('${match.title}\n${_time(match.completedAt)}', bold: true, color: ink),
                _cell(match.isTeam ? 'TEAM' : 'SINGLES', bold: true, color: green),
                _cell(_resultLabel(match, players), color: ink),
                _cell('${match.playerCount}', color: ink),
              ],
            );
          }),
        ],
      );

  static pw.TableRow _tableHeader(List<String> values, PdfColor ink) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: ink),
        children: values
            .map(
              (value) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      );

  static pw.Widget _cell(
    String value, {
    required PdfColor color,
    bool bold = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: color,
            fontSize: 7,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static pw.Widget _metric(
    String label,
    String value,
    PdfColor background,
    PdfColor ink,
    PdfColor muted,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: muted,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _smallInfo(
    String label,
    String value,
    PdfColor background,
    PdfColor ink,
    PdfColor muted,
  ) =>
      pw.Container(
        width: 120,
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: muted,
                fontSize: 5.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                color: ink,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _section(String value, PdfColor ink) => pw.Text(
        value,
        style: pw.TextStyle(
          color: ink,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: .5,
        ),
      );

  static String _tossLabel(TeamMatch match) {
    final toss = match.toss;
    if (toss == null) return 'Pending';
    final battingId = toss.firstBattingTeamId ??
        (toss.winnerTeamId == null
            ? null
            : toss.decision == TeamTossDecision.bowl
                ? match.otherSide(toss.winnerTeamId!).id
                : toss.winnerTeamId);
    final battingName = battingId == null ? 'Unknown team' : match.side(battingId).name;
    String decisionLabel() => toss.decision == TeamTossDecision.bowl
        ? 'elected to bowl'
        : 'elected to bat';
    return switch (toss.mode) {
      TeamTossMode.inApp => toss.winnerTeamId == null
          ? 'In-app toss | $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} won the toss and ${decisionLabel()}',
      TeamTossMode.manual => toss.winnerTeamId == null
          ? 'Manual toss | $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} won the toss and ${decisionLabel()}',
      TeamTossMode.skipped => 'No toss | $battingName batting first',
      TeamTossMode.previousWinnerChoice => toss.winnerTeamId == null
          ? 'Previous winner choice | $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} had the choice and ${decisionLabel()}',
    };
  }

  static String _isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}
