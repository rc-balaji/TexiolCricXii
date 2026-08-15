import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/player.dart';
import '../domain/team_match.dart';
import '../domain/team_scorecard.dart';
import '../domain/team_scoring_engine.dart';

class TeamScorecardExport {
  const TeamScorecardExport._();

  static String summaryText(TeamMatch match, Map<String, Player> players) {
    final result = TeamScoringEngine.result(match);
    final buffer = StringBuffer()
      ..writeln('CRICXII TEAM MATCH')
      ..writeln(match.title)
      ..writeln('${match.teamA.name} vs ${match.teamB.name}')
      ..writeln('Series match ${match.seriesMatchNumber}')
      ..writeln('Match ID: ${match.id}')
      ..writeln();
    for (final innings in match.innings) {
      final side = match.side(innings.battingTeamId);
      buffer.writeln(
        '${TeamScoringEngine.inningsLabel(innings)} • ${side.name}: '
        '${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)} '
        '(${TeamScoringEngine.overLabel(match, innings)} ov)',
      );
    }
    buffer
      ..writeln(result.summary)
      ..writeln()
      ..write('Scored with CricXii by Texiol');
    return buffer.toString();
  }

  static Future<File> createPdf(
    TeamMatch match,
    Map<String, Player> players, {
    Directory? outputDirectory,
  }) async {
    final logoData = await rootBundle.load('assets/branding/cricxii_app_icon.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final result = TeamScoringEngine.result(match);
    final pomId = TeamScoringEngine.playerOfMatchId(match);
    final pomPoints = pomId == null
        ? 0
        : TeamScoringEngine.pointsForPlayer([match], pomId);
    const ink = PdfColor.fromInt(0xFF071A13);
    const green = PdfColor.fromInt(0xFF19C37D);
    const greenDark = PdfColor.fromInt(0xFF087A4B);
    const muted = PdfColor.fromInt(0xFF64756D);
    const pale = PdfColor.fromInt(0xFFF0F7F3);
    const line = PdfColor.fromInt(0xFFDCE8E1);

    final document = pw.Document(
      title: 'CricXii Team Scorecard ${match.id}',
      author: 'CricXii by Texiol',
      creator: 'CricXii Team Match',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 24),
        header: (_) => _header(logo, ink, green),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('CricXii | Official Team Match scorecard', style: const pw.TextStyle(color: muted, fontSize: 7)),
              pw.Text('${match.id} | Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(color: muted, fontSize: 7)),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Text(
            match.title,
            style: pw.TextStyle(color: ink, fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${_date(match.createdAt)}  |  Series match ${match.seriesMatchNumber}  |  Match ID ${match.id}',
            style: const pw.TextStyle(color: muted, fontSize: 8.5),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: ink, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${match.teamA.name}  vs  ${match.teamB.name}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  result.summary,
                  style: pw.TextStyle(color: green, fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                if (pomId != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Player of the Match: ${players[pomId]?.name ?? pomId} • $pomPoints pts',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final innings in match.innings)
                pw.SizedBox(
                  width: 165,
                  child: _inningsTile(match, innings, pale, ink, muted),
                ),
              if (match.innings.length == 1)
                pw.SizedBox(
                  width: 165,
                  child: _metricTile('INNINGS', 'In progress', pale, ink, muted),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          _section('MATCH DETAILS', ink),
          pw.SizedBox(height: 5),
          _details(match, pale, ink, muted),
          for (final innings in match.innings) ...[
            pw.SizedBox(height: 18),
            ..._inningsSection(
              match,
              innings,
              players,
              ink: ink,
              green: greenDark,
              muted: muted,
              pale: pale,
              line: line,
            ),
          ],
          pw.SizedBox(height: 18),
          _section('LOCAL MATCH RULES', ink),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: pale, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text(
              '${match.rules.ballLimit ~/ match.rules.ballsPerOver} overs per innings | '
              'Wide ${_on(match.rules.wideEnabled)} | No-ball ${_on(match.rules.noBallEnabled)} | '
              'Bye ${_on(match.rules.byeEnabled)} | Leg bye ${_on(match.rules.legByeEnabled)} | '
              'Penalty ${_on(match.rules.penaltyExtrasEnabled)} | Free hit ${_on(match.rules.freeHitEnabled)} | '
              'Last Player Standing ${_on(match.rules.askLastPlayerStanding)}',
              style: const pw.TextStyle(color: ink, fontSize: 8.2),
            ),
          ),
        ],
      ),
    );

    final directory = outputDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File('${directory.path}/CricXii_${match.id}_Team_Scorecard.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  static Future<File> savePdf(TeamMatch match, Map<String, Player> players) async {
    Directory directory;
    try {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } on Object {
      directory = await getApplicationDocumentsDirectory();
    }
    return createPdf(match, players, outputDirectory: directory);
  }

  static Future<void> sharePdf(TeamMatch match, Map<String, Player> players) async {
    final file = await createPdf(match, players);
    await SharePlus.instance.share(
      ShareParams(
        subject: 'CricXii Team scorecard - ${match.title}',
        text: summaryText(match, players),
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.Widget _header(pw.MemoryImage logo, PdfColor ink, PdfColor green) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: pw.BoxDecoration(color: ink, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Row(
          children: [
            pw.Container(width: 30, height: 30, child: pw.Image(logo, fit: pw.BoxFit.cover)),
            pw.SizedBox(width: 9),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CRICXII', style: pw.TextStyle(color: PdfColors.white, fontSize: 17, fontWeight: pw.FontWeight.bold)),
                pw.Text('TEAM MATCH SCORECARD', style: pw.TextStyle(color: green, fontSize: 6.8, letterSpacing: 1)),
              ],
            ),
            pw.Spacer(),
            pw.Text('BY TEXIOL', style: const pw.TextStyle(color: PdfColors.white, fontSize: 7)),
          ],
        ),
      );

  static pw.Widget _inningsTile(TeamMatch match, TeamInnings innings, PdfColor pale, PdfColor ink, PdfColor muted) {
    final side = match.side(innings.battingTeamId);
    return _metricTile(
      '${TeamScoringEngine.inningsLabel(innings).toUpperCase()} • ${side.name.toUpperCase()}',
      '${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)}  (${TeamScoringEngine.overLabel(match, innings)} ov)',
      pale,
      ink,
      muted,
    );
  }

  static pw.Widget _metricTile(String label, String value, PdfColor pale, PdfColor ink, PdfColor muted) => pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(color: pale, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(value, style: pw.TextStyle(color: ink, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
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
          ? 'In-app toss • $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} won the toss and ${decisionLabel()}',
      TeamTossMode.manual => toss.winnerTeamId == null
          ? 'Manual toss • $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} won the toss and ${decisionLabel()}',
      TeamTossMode.skipped => 'No toss • $battingName batting first',
      TeamTossMode.previousWinnerChoice => toss.winnerTeamId == null
          ? 'Previous winner choice • $battingName batting first'
          : '${match.side(toss.winnerTeamId!).name} had the choice and ${decisionLabel()}',
    };
  }

  static pw.Widget _details(TeamMatch match, PdfColor pale, PdfColor ink, PdfColor muted) {
    final joker = match.commonJokerPlayerId;
    return pw.Row(
      children: [
        pw.Expanded(
          child: _metricTile(
            'TOSS',
            _tossLabel(match),
            pale,
            ink,
            muted,
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Expanded(
          child: _metricTile(
            'JOKER',
            joker == null ? 'Not used' : 'Shared player $joker',
            pale,
            ink,
            muted,
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Expanded(
          child: _metricTile(
            'FORMAT',
            '${match.rules.ballLimit ~/ match.rules.ballsPerOver} overs a side',
            pale,
            ink,
            muted,
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _inningsSection(
    TeamMatch match,
    TeamInnings innings,
    Map<String, Player> players, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
    required PdfColor pale,
    required PdfColor line,
  }) {
    final batting = match.side(innings.battingTeamId);
    final data = TeamScorecardBuilder.build(match, innings);
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

    final battingRows = data.batters
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
        .toList(growable: false);
    final bowlingRows = data.bowlers
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
        .toList(growable: false);
    final fallRows = data.falls
        .map(
          (fall) => [name(fall.playerId), fall.scoreLabel, fall.overLabel],
        )
        .toList(growable: false);

    return [
        pw.Container(
          width: double.infinity,
          color: green,
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${batting.name} ${TeamScoringEngine.inningsLabel(innings)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${data.total}-${data.wickets} (${data.overs} Ov)',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: pw.Text(
              'Target ${innings.target}${innings.completionReason == null ? '' : ' | ${innings.completionReason}'}',
              style: pw.TextStyle(
                color: green,
                fontSize: 7.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        _scorecardTable(
          const ['BATTER', '', 'R', 'B', '4s', '6s', 'SR'],
          battingRows,
          ink: ink,
          muted: muted,
          line: line,
          columnWidths: const {
            0: pw.FlexColumnWidth(2.4),
            1: pw.FlexColumnWidth(2.8),
            2: pw.FlexColumnWidth(.65),
            3: pw.FlexColumnWidth(.65),
            4: pw.FlexColumnWidth(.65),
            5: pw.FlexColumnWidth(.65),
            6: pw.FlexColumnWidth(.95),
          },
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
        if (bowlingRows.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _scorecardTable(
            const ['BOWLER', 'O', 'M', 'R', 'W', 'NB', 'WD', 'ECO'],
            bowlingRows,
            ink: ink,
            muted: muted,
            line: line,
            columnWidths: const {
              0: pw.FlexColumnWidth(2.7),
              1: pw.FlexColumnWidth(.72),
              2: pw.FlexColumnWidth(.65),
              3: pw.FlexColumnWidth(.65),
              4: pw.FlexColumnWidth(.65),
              5: pw.FlexColumnWidth(.7),
              6: pw.FlexColumnWidth(.7),
              7: pw.FlexColumnWidth(.92),
            },
          ),
        ],
        if (fallRows.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _scorecardTable(
            const ['FALL OF WICKETS', 'SCORE', 'OVER'],
            fallRows,
            ink: ink,
            muted: muted,
            line: line,
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.1),
            },
          ),
        ],
        if (data.partnerships.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            color: const PdfColor.fromInt(0xFFE9E7E7),
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: pw.Text(
              'PARTNERSHIPS',
              style: pw.TextStyle(
                color: ink,
                fontSize: 7.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          ...data.partnerships.map(
            (partnership) => pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line, width: .5)),
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
                          .join('  |  '),
                      style: pw.TextStyle(color: green, fontSize: 6.8),
                    ),
                  ),
                  pw.Text(
                    '${partnership.runs}(${partnership.balls})',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    ];
  }

  static pw.Widget _scorecardTable(
    List<String> headers,
    List<List<String>> rows, {
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor line,
    required Map<int, pw.TableColumnWidth> columnWidths,
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
      ...rows.map(
        (row) => pw.TableRow(
          children: row.asMap().entries
              .map(
                (entry) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: pw.Text(
                    entry.value,
                    textAlign: entry.key < 2 ? pw.TextAlign.left : pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: entry.key == 0
                          ? greenForScorecard
                          : entry.key == 1
                              ? muted
                              : ink,
                      fontSize: 6.9,
                      fontWeight: entry.key == 2 || entry.key == 4
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  static const PdfColor greenForScorecard = PdfColor.fromInt(0xFF0B5FFF);

  static pw.Widget _scoreSummaryRow(
    String label,
    String value, {
    required PdfColor ink,
    required PdfColor line,
    bool bold = false,
    PdfColor? valueColor,
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
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 88,
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
              color: valueColor ?? ink,
              fontSize: 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _section(String value, PdfColor ink) => pw.Text(
        value,
        style: pw.TextStyle(color: ink, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: .5),
      );

  static String _on(bool value) => value ? 'ON' : 'OFF';

  static String _date(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
