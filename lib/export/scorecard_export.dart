import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/cricket_match.dart';
import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/scoring_engine.dart';

class ScorecardExport {
  const ScorecardExport._();

  static String summaryText(CricketMatch match, Map<String, Player> players) {
    final rankings = ScoringEngine.rankings(match);
    final buffer = StringBuffer()
      ..writeln('CRICXII • ${match.title}')
      ..writeln('Match ID: ${match.id}')
      ..writeln(
        'Official ranking: ${match.winnerMetric == MatchWinnerMetric.runs ? 'Runs' : 'Overall points'}',
      )
      ..writeln();
    for (var index = 0; index < rankings.length; index++) {
      final stats = rankings[index];
      final player = players[stats.playerId];
      buffer.writeln(
        '${index + 1}. ${player?.name ?? stats.playerId} — '
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
    final document = pw.Document(
      title: 'CricXii Scorecard ${match.id}',
      author: 'CricXii by Texiol',
    );
    const ink = PdfColor.fromInt(0xFF071A13);
    const green = PdfColor.fromInt(0xFF19C37D);
    const muted = PdfColor.fromInt(0xFF64756D);
    const pale = PdfColor.fromInt(0xFFF0F7F3);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: ink,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CRICXII',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'BY TEXIOL',
                style: const pw.TextStyle(color: green, fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'CricXii scorecard • Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(color: muted, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            match.title,
            style: pw.TextStyle(
              color: ink,
              fontSize: 27,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${match.id}  •  ${_date(match.createdAt)}  •  '
            '${match.scoringMode == ScoringMode.ballByBall ? '${match.ballLimit} balls each' : 'Direct runs'}',
            style: const pw.TextStyle(color: muted, fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          if (rankings.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: pale,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 38,
                    height: 38,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      color: green,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Text(
                      '1',
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MATCH WINNER',
                          style: const pw.TextStyle(color: muted, fontSize: 8),
                        ),
                        pw.Text(
                          players[rankings.first.playerId]?.name ??
                              rankings.first.playerId,
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    match.winnerMetric == MatchWinnerMetric.runs
                        ? '${rankings.first.runs} RUNS'
                        : '${rankings.first.points} PTS',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 22),
          pw.Text(
            'FINAL RANKING',
            style: pw.TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .6),
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(),
              3: pw.FlexColumnWidth(),
              4: pw.FlexColumnWidth(),
              5: pw.FlexColumnWidth(),
            },
            children: [
              _row(const [
                '#',
                'Player',
                'Runs',
                'Balls',
                'Wkts',
                'Points',
              ], header: true),
              for (var index = 0; index < rankings.length; index++)
                _row([
                  '${index + 1}',
                  players[rankings[index].playerId]?.name ??
                      rankings[index].playerId,
                  '${rankings[index].runs}',
                  match.scoringMode == ScoringMode.quickTotal
                      ? '—'
                      : '${rankings[index].balls}',
                  '${rankings[index].wickets}',
                  '${rankings[index].points}',
                ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'FIELDING',
            style: pw.TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...rankings
              .where((stats) {
                return stats.catches > 0 ||
                    stats.directRunOuts > 0 ||
                    stats.assistedRunOuts > 0 ||
                    stats.stumpings > 0;
              })
              .map(
                (stats) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(
                    '${players[stats.playerId]?.name ?? stats.playerId}: '
                    '${stats.catches} catches, ${stats.directRunOuts} direct RO, '
                    '${stats.assistedRunOuts} assisted RO, ${stats.stumpings} stumpings',
                    style: const pw.TextStyle(color: muted, fontSize: 10),
                  ),
                ),
              ),
          if (!rankings.any(
            (stats) =>
                stats.catches > 0 ||
                stats.directRunOuts > 0 ||
                stats.assistedRunOuts > 0 ||
                stats.stumpings > 0,
          ))
            pw.Text(
              'No fielding dismissals recorded.',
              style: const pw.TextStyle(color: muted, fontSize: 10),
            ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              'Official winner metric: '
              '${match.winnerMetric == MatchWinnerMetric.runs ? 'Runs only' : 'Overall points'}. '
              'Points: run ${match.pointRules.run}, wicket ${match.pointRules.wicket}, '
              'catch ${match.pointRules.catchPoint}, direct run-out ${match.pointRules.directRunOut}, '
              'assisted run-out ${match.pointRules.assistedRunOut}, stumping ${match.pointRules.stumping}, '
              'not-out bonus ${match.pointRules.notOutBonus}.',
              style: const pw.TextStyle(color: muted, fontSize: 8.5),
            ),
          ),
        ],
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
        subject: 'CricXii scorecard • ${match.title}',
        text: summaryText(match, players),
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.TableRow _row(List<String> values, {bool header = false}) {
    return pw.TableRow(
      decoration: header ? const pw.BoxDecoration(color: paleGrey) : null,
      children: values
          .map(
            (value) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 8,
              ),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0xFF071A13),
                  fontSize: 9,
                  fontWeight: header
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

const paleGrey = PdfColor.fromInt(0xFFF0F3F1);
