import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/daily_performance.dart';
import '../domain/player.dart';

class DailyPerformanceExport {
  const DailyPerformanceExport._();

  static Future<File> createPdf(
    DailyPerformanceSummary summary,
    Map<String, Player> players, {
    Directory? outputDirectory,
  }) async {
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
    final document = pw.Document(
      title: 'CricXii Daily Performance ${_date(summary.date)}',
      author: 'CricXii by Texiol',
      creator: 'CricXii v1.0.0',
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
                    'DAILY PERFORMANCE REPORT',
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
              pw.Text(
                _date(summary.date),
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                'CricXii by Texiol | Daily cricket performance',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
              pw.Text(
                'Page ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 6.8),
              ),
            ],
          ),
        ),
        build: (context) => [
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
                        'TODAY\'S PERFORMANCE',
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
                            ? 'No completed matches'
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
                          'Overall leader: ${players[summary.rankings.first.playerId]?.name ?? summary.rankings.first.playerId}',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFB8CCC2),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (summary.rankings.isNotEmpty)
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
                          '${summary.rankings.first.points}',
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'PTS',
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
            ],
          ),
          pw.SizedBox(height: 16),
          _section('OVERALL RANKING', ink),
          pw.SizedBox(height: 7),
          if (summary.rankings.isEmpty)
            pw.Text(
              'Complete a match on this date to generate the daily ranking.',
              style: const pw.TextStyle(color: muted, fontSize: 9),
            )
          else
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
                  final rank = entry.key + 1;
                  final row = entry.value;
                  final player = players[row.playerId];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: rank == 1 ? pale : PdfColors.white,
                    ),
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
            ),
          if (summary.rankings.isNotEmpty) ...[
            pw.SizedBox(height: 18),
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
                                style: const pw.TextStyle(
                                  color: muted,
                                  fontSize: 7,
                                ),
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
                                style: const pw.TextStyle(
                                  color: muted,
                                  fontSize: 6.5,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (summary.matches.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _section('MATCH TIMELINE', ink),
            pw.SizedBox(height: 7),
            ...summary.matches.asMap().entries.map((entry) {
              final match = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: entry.key.isEven ? pale : PdfColors.white,
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
                        '${entry.key + 1}',
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
                        '${match.title} | ${match.id}',
                        style: pw.TextStyle(
                          color: ink,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      _time(match.completedAt ?? match.createdAt),
                      style: const pw.TextStyle(color: muted, fontSize: 7),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
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
    return createPdf(summary, players, outputDirectory: directory);
  }

  static Future<void> sharePdf(
    DailyPerformanceSummary summary,
    Map<String, Player> players,
  ) async {
    final file = await createPdf(summary, players);
    await SharePlus.instance.share(
      ShareParams(
        subject: 'CricXii daily performance - ${_date(summary.date)}',
        text:
            'CricXii daily performance: ${summary.matches.length} matches, ${summary.totalRuns} runs, ${summary.totalWickets} wickets.',
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.Widget _metric(
    String label,
    String value,
    PdfColor background,
    PdfColor ink,
    PdfColor muted,
  ) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 6)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: ink,
              fontSize: 14,
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
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 6,
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
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: color,
        fontSize: 7.5,
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
