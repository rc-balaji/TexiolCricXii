import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/avatar_image_repository.dart';
import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/match_planning.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';
import '../domain/singles_scorecard.dart';

class ScorecardExport {
  const ScorecardExport._();

  static String summaryText(CricketMatch match, Map<String, Player> players) {
    final rankings = ScoringEngine.rankings(match);
    final buffer = StringBuffer()
      ..writeln('CRICXII - ${match.title}')
      ..writeln('Match ID: ${match.id}')
      ..writeln(
        'Official ranking: ${match.winnerMetric == MatchWinnerMetric.runs ? 'Runs' : 'Overall points'}',
      )
      ..writeln();
    for (var index = 0; index < rankings.length; index++) {
      final stats = rankings[index];
      final player = players[stats.playerId];
      buffer.writeln(
        '${index + 1}. ${player?.name ?? stats.playerId} - '
        '${stats.runs} runs, ${stats.points} pts, ${stats.wickets} wkts',
      );
    }
    buffer
      ..writeln()
      ..write('Scored with CricXii by Texiol');
    return buffer.toString();
  }

  static Future<File> createPdf(
    CricketMatch match,
    Map<String, Player> players, {
    Directory? outputDirectory,
  }) async {
    final rankings = ScoringEngine.rankings(match);
    final logoData = await rootBundle.load('assets/branding/cricxii_app_icon.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final avatarEntries = await Future.wait(
      rankings.map((stats) async {
        final player = players[stats.playerId];
        if (player == null) return null;
        return MapEntry<String, pw.MemoryImage?>(
          player.id,
          await _avatarFor(player),
        );
      }),
    );
    final avatars = <String, pw.MemoryImage?>{
      for (final entry in avatarEntries)
        if (entry != null) entry.key: entry.value,
    };

    final document = pw.Document(
      title: 'CricXii Scorecard ${match.id}',
      author: 'CricXii by Texiol',
      creator: 'CricXii v1.6.3',
    );

    const ink = PdfColor.fromInt(0xFF071A13);
    const green = PdfColor.fromInt(0xFF19C37D);
    const greenDark = PdfColor.fromInt(0xFF0A6E49);
    const muted = PdfColor.fromInt(0xFF64756D);
    const pale = PdfColor.fromInt(0xFFF0F7F3);
    const line = PdfColor.fromInt(0xFFDCE8E1);
    const gold = PdfColor.fromInt(0xFFF2B84B);
    const silver = PdfColor.fromInt(0xFFB8C4BF);
    const bronze = PdfColor.fromInt(0xFFC98B62);

    final winner = rankings.isEmpty ? null : rankings.first;
    final winnerPlayer = winner == null ? null : players[winner.playerId];
    final podium = rankings.take(3).toList(growable: false);
    final pageContentWidth = PdfPageFormat.a4.width - 44;
    final podiumCardWidth = podium.isEmpty
        ? pageContentWidth
        : (pageContentWidth - ((podium.length - 1) * 8)) / podium.length;
    final compactRanking = rankings.length > 6;
    final shownRankings = rankings.take(12).toList(growable: false);
    final scorecard = SinglesScorecardBuilder.build(match);
    String playerName(String id) => players[id]?.name ?? id;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 18),
        header: (_) => _header(logo: logo, ink: ink, green: green),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CricXii | Singles scorecard',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
              pw.Text(
                'Page ${context.pageNumber}/${context.pagesCount} | ${match.id}',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            match.title,
            style: pw.TextStyle(
              color: ink,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${_date(match.createdAt)} | Match ID ${match.id} | ${match.scoringMode.label}',
            style: const pw.TextStyle(color: muted, fontSize: 8.2),
          ),
          pw.SizedBox(height: 11),
          pw.Container(
            width: double.infinity,
            color: greenDark,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Singles Match Scorecard',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  '${scorecard.batters.length} Players',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _singlesScorecardTable(
            const ['', 'BATTER', '', 'R', 'B', '4s', '6s', 'SR'],
            scorecard.batters
                .map(
                  (row) => [
                    playerName(row.playerId),
                    row.dismissal.text(playerName),
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
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(.65),
              4: pw.FlexColumnWidth(.65),
              5: pw.FlexColumnWidth(.65),
              6: pw.FlexColumnWidth(.65),
              7: pw.FlexColumnWidth(.95),
            },
            playerIds: scorecard.batters.map((row) => row.playerId).toList(growable: false),
            players: players,
            avatars: avatars,
          ),
          _singlesSummaryRow(
            'Extras',
            '${scorecard.extras} (${scorecard.extrasBreakdown})',
            ink: ink,
            line: line,
          ),
          _singlesSummaryRow(
            'Recorded Runs',
            '${scorecard.aggregateRuns} batter runs across all turns',
            ink: ink,
            line: line,
            bold: true,
          ),
          if (scorecard.bowlers.isNotEmpty &&
              match.scoringMode == ScoringMode.ballByBall) ...[
            pw.SizedBox(height: 9),
            _singlesScorecardTable(
              const ['', 'BOWLER', 'O', 'R', 'W', 'NB', 'WD', 'ECO'],
              scorecard.bowlers
                  .map(
                    (row) => [
                      playerName(row.playerId),
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
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(2.45),
                2: pw.FlexColumnWidth(.72),
                3: pw.FlexColumnWidth(.72),
                4: pw.FlexColumnWidth(.72),
                5: pw.FlexColumnWidth(.72),
                6: pw.FlexColumnWidth(.72),
                7: pw.FlexColumnWidth(.95),
              },
              playerIds: scorecard.bowlers.map((row) => row.playerId).toList(growable: false),
              players: players,
              avatars: avatars,
            ),
          ],
          pw.SizedBox(height: 9),
          pw.Container(
            width: double.infinity,
            color: pale,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              'Singles ranking is shown on the next page. It stays separate from this scorecard because the official winner is decided by ${match.winnerMetric == MatchWinnerMetric.runs ? 'runs' : 'overall points'}, not by a team innings total.',
              style: const pw.TextStyle(color: muted, fontSize: 7.2),
            ),
          ),
        ],
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 18),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(logo: logo, ink: ink, green: green),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        match.title,
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        style: pw.TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${_date(match.createdAt)} | Match ID ${match.id}',
                        style: const pw.TextStyle(color: muted, fontSize: 8.2),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: pale,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    match.scoringMode == ScoringMode.ballByBall
                        ? '${OversFormat.setupOversLabel(match.ballLimit).toUpperCase()} EACH'
                        : 'DIRECT RUNS | ${OversFormat.setupOversLabel(match.ballLimit).toUpperCase()}',
                    style: pw.TextStyle(
                      color: greenDark,
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _metricTile(
                  'PLAYERS',
                  '${rankings.length}',
                  icon: 'XI',
                  ink: ink,
                  muted: muted,
                  pale: pale,
                ),
                pw.SizedBox(width: 7),
                _metricTile(
                  'WINNER BY',
                  match.winnerMetric == MatchWinnerMetric.runs
                      ? 'RUNS'
                      : 'POINTS',
                  icon: '#1',
                  ink: ink,
                  muted: muted,
                  pale: pale,
                ),
                pw.SizedBox(width: 7),
                _metricTile(
                  'STATUS',
                  'FINAL',
                  icon: 'OK',
                  ink: ink,
                  muted: muted,
                  pale: pale,
                ),
              ],
            ),
            if (winner != null && winnerPlayer != null) ...[
              pw.SizedBox(height: 10),
              _winnerBanner(
                match: match,
                stats: winner,
                player: winnerPlayer,
                avatar: avatars[winnerPlayer.id],
                ink: ink,
                green: green,
                muted: muted,
              ),
            ],
            if (podium.isNotEmpty) ...[
              pw.SizedBox(height: 11),
              _sectionTitle('PODIUM', ink),
              pw.SizedBox(height: 5),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < podium.length; index++) ...[
                    if (index > 0) pw.SizedBox(width: 8),
                    _podiumCard(
                      width: podiumCardWidth,
                      rank: index + 1,
                      stats: podium[index],
                      player: players[podium[index].playerId],
                      avatar: avatars[podium[index].playerId],
                      accent: index == 0
                          ? gold
                          : index == 1
                              ? silver
                              : bronze,
                      ink: ink,
                      muted: muted,
                    ),
                  ],
                ],
              ),
            ],
            pw.SizedBox(height: 11),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('FINAL RANKING', ink),
                if (rankings.length > shownRankings.length)
                  pw.Text(
                    'Top ${shownRankings.length} shown | Full ranking in app',
                    style: const pw.TextStyle(color: muted, fontSize: 6.5),
                  ),
              ],
            ),
            pw.SizedBox(height: 5),
            if (!compactRanking)
              _rankingTable(
                rankings: shownRankings,
                players: players,
                avatars: avatars,
                ink: ink,
                muted: muted,
                line: line,
                pale: pale,
                green: greenDark,
              )
            else
              _compactRankingGrid(
                rankings: shownRankings,
                players: players,
                avatars: avatars,
                ink: ink,
                muted: muted,
                line: line,
                pale: pale,
                green: greenDark,
              ),
            pw.SizedBox(height: 11),
            _sectionTitle('MATCH DETAILS', ink),
            pw.SizedBox(height: 5),
            _matchDetails(match, ink: ink, muted: muted, pale: pale),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 7),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CricXii | Local cricket, permanent history',
                    style: const pw.TextStyle(color: muted, fontSize: 6.8),
                  ),
                  pw.Text(
                    'Official scorecard | ${match.id}',
                    style: const pw.TextStyle(color: muted, fontSize: 6.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final directory = outputDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File('${directory.path}/CricXii_${match.id}_Scorecard.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  static Future<File> savePdf(
    CricketMatch match,
    Map<String, Player> players,
  ) async {
    Directory directory;
    try {
      directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } on Object {
      directory = await getApplicationDocumentsDirectory();
    }
    return createPdf(match, players, outputDirectory: directory);
  }

  static Future<void> sharePdf(
    CricketMatch match,
    Map<String, Player> players,
  ) async {
    final file = await createPdf(match, players);
    await SharePlus.instance.share(
      ShareParams(
        subject: 'CricXii scorecard - ${match.title}',
        text: summaryText(match, players),
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.Widget _header({
    required pw.MemoryImage logo,
    required PdfColor ink,
    required PdfColor green,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: pw.BoxDecoration(
      color: ink,
      borderRadius: pw.BorderRadius.circular(11),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 31,
              height: 31,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Image(logo, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 9),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
              'CRICXII',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 1),
                pw.Text(
                  'OFFICIAL MATCH SCORECARD',
                  style: pw.TextStyle(
                    color: green,
                    fontSize: 6.8,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Text(
          'BY TEXIOL',
          style: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 7.2,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _winnerBanner({
    required CricketMatch match,
    required PlayerMatchStats stats,
    required Player player,
    required pw.MemoryImage? avatar,
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: pw.BoxDecoration(
      color: ink,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Row(
      children: [
        _pdfAvatar(
          player,
          avatar,
          size: 43,
          background: green,
          textColor: ink,
        ),
        pw.SizedBox(width: 11),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MATCH WINNER',
                style: pw.TextStyle(
                  color: green,
                  fontSize: 6.6,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                player.name,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Player ID ${player.id}',
                style: pw.TextStyle(color: muted, fontSize: 6.8),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              match.winnerMetric == MatchWinnerMetric.runs
                  ? '${stats.runs}'
                  : '${stats.points}',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              match.winnerMetric == MatchWinnerMetric.runs ? 'RUNS' : 'POINTS',
              style: pw.TextStyle(
                color: green,
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _metricTile(
    String label,
    String value, {
    required String icon,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor pale,
  }) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: pw.BoxDecoration(
        color: pale,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 23,
            height: 23,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              icon,
              style: pw.TextStyle(
                color: ink,
                fontSize: 6.6,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 5.6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                value,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static pw.Widget _singlesScorecardTable(
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
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    color: ink,
                    fontSize: 6.8,
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
                    ? pw.SizedBox(width: 18, height: 18)
                    : _pdfAvatar(
                        player,
                        avatars?[player.id],
                        size: 18,
                        background: PdfColor.fromInt(player.avatarColor),
                        textColor: PdfColors.white,
                      ),
              ),
            ...row.asMap().entries.map(
              (entry) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(
                  entry.value,
                  textAlign: entry.key < 2 ? pw.TextAlign.left : pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: entry.key == 0
                        ? const PdfColor.fromInt(0xFF0B5FFF)
                        : entry.key == 1
                            ? muted
                            : ink,
                    fontSize: 6.9,
                    fontWeight: entry.key == 2 || entry.key == 3
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

  static pw.Widget _singlesSummaryRow(
    String label,
    String value, {
    required PdfColor ink,
    required PdfColor line,
    bool bold = false,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: line, width: .45),
        right: pw.BorderSide(color: line, width: .45),
        bottom: pw.BorderSide(color: line, width: .45),
      ),
    ),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              color: ink,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: ink,
              fontSize: 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _sectionTitle(String text, PdfColor ink) => pw.Text(
    text,
    style: pw.TextStyle(
      color: ink,
      fontSize: 9.2,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: .7,
    ),
  );

  static pw.Widget _podiumCard({
    required double width,
    required int rank,
    required PlayerMatchStats stats,
    required Player? player,
    required pw.MemoryImage? avatar,
    required PdfColor accent,
    required PdfColor ink,
    required PdfColor muted,
  }) => pw.Container(
    width: width,
    height: 72,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: accent, width: 1),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 28,
          height: 28,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            '#$rank',
            style: pw.TextStyle(
              color: ink,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 7),
        if (player != null) ...[
          _pdfAvatar(
            player,
            avatar,
            size: 34,
            background: accent,
            textColor: ink,
          ),
          pw.SizedBox(width: 7),
        ],
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                player?.name ?? stats.playerId,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${stats.runs} runs | ${stats.points} pts',
                style: pw.TextStyle(color: muted, fontSize: 6.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _rankingTable({
    required List<PlayerMatchStats> rankings,
    required Map<String, Player> players,
    required Map<String, pw.MemoryImage?> avatars,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required PdfColor pale,
    required PdfColor green,
  }) => pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: line, width: .7),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      children: [
        for (var index = 0; index < rankings.length; index++)
          _rankingRow(
            rank: index + 1,
            stats: rankings[index],
            player: players[rankings[index].playerId],
            avatar: avatars[rankings[index].playerId],
            showDivider: index != rankings.length - 1,
            ink: ink,
            muted: muted,
            line: line,
            pale: pale,
            green: green,
          ),
      ],
    ),
  );

  static pw.Widget _rankingRow({
    required int rank,
    required PlayerMatchStats stats,
    required Player? player,
    required pw.MemoryImage? avatar,
    required bool showDivider,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required PdfColor pale,
    required PdfColor green,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: pw.BoxDecoration(
      color: rank == 1 ? pale : PdfColors.white,
      border: showDivider
          ? pw.Border(bottom: pw.BorderSide(color: line, width: .6))
          : null,
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 20,
          alignment: pw.Alignment.center,
          child: pw.Text(
            '$rank',
            style: pw.TextStyle(
              color: rank == 1 ? green : ink,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (player != null) ...[
          _pdfAvatar(
            player,
            avatar,
            size: 27,
            background: pale,
            textColor: ink,
          ),
          pw.SizedBox(width: 7),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                player?.name ?? stats.playerId,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 8.2,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'ID ${player?.id ?? stats.playerId}',
                style: pw.TextStyle(color: muted, fontSize: 5.8),
              ),
            ],
          ),
        ),
        _tinyStat('RUNS', '${stats.runs}', ink, muted),
        pw.SizedBox(width: 10),
        _tinyStat('WKTS', '${stats.wickets}', ink, muted),
        pw.SizedBox(width: 10),
        _tinyStat('PTS', '${stats.points}', ink, muted),
      ],
    ),
  );

  static pw.Widget _compactRankingGrid({
    required List<PlayerMatchStats> rankings,
    required Map<String, Player> players,
    required Map<String, pw.MemoryImage?> avatars,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required PdfColor pale,
    required PdfColor green,
  }) {
    final rows = <pw.Widget>[];
    for (var index = 0; index < rankings.length; index += 2) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _compactRankingCard(
                  rank: index + 1,
                  stats: rankings[index],
                  player: players[rankings[index].playerId],
                  avatar: avatars[rankings[index].playerId],
                  ink: ink,
                  muted: muted,
                  line: line,
                  pale: pale,
                  green: green,
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Expanded(
                child: index + 1 < rankings.length
                    ? _compactRankingCard(
                        rank: index + 2,
                        stats: rankings[index + 1],
                        player: players[rankings[index + 1].playerId],
                        avatar: avatars[rankings[index + 1].playerId],
                        ink: ink,
                        muted: muted,
                        line: line,
                        pale: pale,
                        green: green,
                      )
                    : pw.SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _compactRankingCard({
    required int rank,
    required PlayerMatchStats stats,
    required Player? player,
    required pw.MemoryImage? avatar,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required PdfColor pale,
    required PdfColor green,
  }) => pw.Container(
    height: 43,
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: pw.BoxDecoration(
      color: rank == 1 ? pale : PdfColors.white,
      border: pw.Border.all(color: line, width: .7),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 18,
          alignment: pw.Alignment.center,
          child: pw.Text(
            '$rank',
            style: pw.TextStyle(
              color: rank == 1 ? green : ink,
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (player != null) ...[
          _pdfAvatar(
            player,
            avatar,
            size: 25,
            background: pale,
            textColor: ink,
          ),
          pw.SizedBox(width: 5),
        ],
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                player?.name ?? stats.playerId,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${stats.runs} R | ${stats.points} P | ${stats.wickets} W',
                style: pw.TextStyle(color: muted, fontSize: 5.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _tinyStat(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 5.2)),
      pw.SizedBox(height: 1),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: ink,
          fontSize: 8.4,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );

  static pw.Widget _matchDetails(
    CricketMatch match, {
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor pale,
  }) {
    final values = <(String, String)>[
      (
        'Scoring',
        match.scoringMode == ScoringMode.ballByBall ? 'Ball tracker' : 'Direct runs',
      ),
      ('Format', OversFormat.setupOversLabel(match.ballLimit)),
      ('Preset', match.pointPresetName),
      ('Wicket', '${match.pointRules.wicket} pts'),
      ('Bowled +', '${match.pointRules.bowledBonus} pts'),
      ('Catch', '${match.pointRules.catchPoint} pts'),
      ('Direct RO', '${match.pointRules.directRunOut} pts'),
      ('Started', _time(match.startedAt ?? match.createdAt)),
      ('Finished', match.completedAt == null ? '-' : _time(match.completedAt!)),
    ];
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: pale,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          for (var row = 0; row < 3; row++) ...[
            pw.Row(
              children: [
                for (var column = 0; column < 3; column++)
                  pw.Expanded(
                    child: _detail(
                      values[(row * 3) + column].$1,
                      values[(row * 3) + column].$2,
                      ink,
                      muted,
                    ),
                  ),
              ],
            ),
            if (row < 2) pw.SizedBox(height: 5),
          ],
        ],
      ),
    );
  }

  static pw.Widget _detail(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 5.5)),
      pw.SizedBox(height: 1),
      pw.Text(
        value,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          color: ink,
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );

  static pw.Widget _pdfAvatar(
    Player player,
    pw.MemoryImage? image, {
    required double size,
    required PdfColor background,
    required PdfColor textColor,
  }) => pw.Container(
    width: size,
    height: size,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(size * .22),
    ),
    child: image != null
        ? pw.Image(image, width: size, height: size, fit: pw.BoxFit.cover)
        : pw.Text(
            player.initials,
            style: pw.TextStyle(
              color: textColor,
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

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
