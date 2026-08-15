import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/enums.dart';
import '../domain/player.dart';
import '../domain/team_match.dart';
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
        '${side.name}: ${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)} '
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
    final stats = TeamScoringEngine.appearanceStats(match);
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
          pw.Row(
            children: [
              for (var index = 0; index < match.innings.length; index++) ...[
                if (index > 0) pw.SizedBox(width: 8),
                pw.Expanded(child: _inningsTile(match, match.innings[index], pale, ink, muted)),
              ],
              if (match.innings.length == 1) ...[
                pw.SizedBox(width: 8),
                pw.Expanded(child: _metricTile('INNINGS', 'In progress', pale, ink, muted)),
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          _section('MATCH DETAILS', ink),
          pw.SizedBox(height: 5),
          _details(match, pale, ink, muted),
          for (final innings in match.innings) ...[
            pw.SizedBox(height: 18),
            _inningsSection(
              match,
              innings,
              players,
              stats,
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
      side.name.toUpperCase(),
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
    return switch (toss.mode) {
      TeamTossMode.inApp => toss.winnerTeamId == null
          ? 'In-app toss • $battingName batting'
          : '${match.side(toss.winnerTeamId!).name} won • $battingName batting',
      TeamTossMode.manual => toss.winnerTeamId == null
          ? 'Manual toss • $battingName batting'
          : 'Manual • ${match.side(toss.winnerTeamId!).name} won • $battingName batting',
      TeamTossMode.skipped => 'No toss • $battingName batting',
      TeamTossMode.previousWinnerChoice =>
        'Previous winner chose • $battingName batting',
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

  static pw.Widget _inningsSection(
    TeamMatch match,
    TeamInnings innings,
    Map<String, Player> players,
    Map<String, TeamPlayerMatchStats> allStats, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor muted,
    required PdfColor pale,
    required PdfColor line,
  }) {
    final batting = match.side(innings.battingTeamId);
    final bowling = match.side(innings.bowlingTeamId);
    TeamPlayerMatchStats stat(String teamId, String playerId) =>
        allStats['$teamId:$playerId'] ?? TeamPlayerMatchStats(playerId: playerId, teamId: teamId);
    final battingRows = batting.battingOrder.map((id) {
      final value = stat(batting.id, id);
      final status = value.dismissed
          ? 'out'
          : value.balls == 0 && value.runs == 0
              ? 'did not bat'
              : 'not out';
      return [
        '${players[id]?.name ?? id}${id == match.commonJokerPlayerId ? ' (J)' : ''}',
        status,
        '${value.runs}',
        '${value.balls}',
        '${value.fours}',
        '${value.sixes}',
        value.strikeRate.toStringAsFixed(1),
      ];
    }).toList();
    final bowlingRows = bowling.playerIds
        .map((id) => stat(bowling.id, id))
        .where((value) => value.ballsBowled > 0)
        .map(
          (value) => [
            '${players[value.playerId]?.name ?? value.playerId}${value.playerId == match.commonJokerPlayerId ? ' (J)' : ''}',
            '${value.ballsBowled ~/ match.rules.ballsPerOver}.${value.ballsBowled % match.rules.ballsPerOver}',
            '${value.runsConceded}',
            '${value.wickets}',
            value.economy.toStringAsFixed(2),
            '${value.wides}',
            '${value.noBalls}',
          ],
        )
        .toList();
    var running = 0;
    final falls = <String>[];
    for (final event in innings.events) {
      running += event.totalRuns;
      if (event.isWicket) {
        falls.add('$running-${TeamScoringEngine.wicketsBefore(innings, event.sequence) + 1} (${players[event.dismissedPlayerId]?.name ?? event.dismissedPlayerId})');
      }
    }
    final extraBreakdown = <ExtraType, int>{};
    for (final event in innings.events) {
      if (event.extraType != ExtraType.none) {
        extraBreakdown[event.extraType] = (extraBreakdown[event.extraType] ?? 0) + event.extraRuns;
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _section(
          '${innings.index + 1}${innings.index == 0 ? 'ST' : 'ND'} INNINGS | ${batting.name.toUpperCase()} '
          '${TeamScoringEngine.total(innings)}/${TeamScoringEngine.wickets(innings)}',
          ink,
        ),
        pw.SizedBox(height: 6),
        _table(
          const ['BATTER', 'STATUS', 'R', 'B', '4', '6', 'SR'],
          battingRows,
          ink: ink,
          green: green,
          pale: pale,
          line: line,
          firstFlex: 2.5,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Extras ${TeamScoringEngine.extras(innings)} '
          '${extraBreakdown.entries.map((entry) => '${_extraShort(entry.key)} ${entry.value}').join(', ')}',
          style: pw.TextStyle(color: muted, fontSize: 7.5),
        ),
        if (falls.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text('Fall of wickets: ${falls.join(', ')}', style: pw.TextStyle(color: muted, fontSize: 7.5)),
        ],
        pw.SizedBox(height: 10),
        pw.Text('BOWLING | ${bowling.name.toUpperCase()}', style: pw.TextStyle(color: ink, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        if (bowlingRows.isEmpty)
          pw.Text('No bowling figures yet.', style: pw.TextStyle(color: muted, fontSize: 8))
        else
          _table(
            const ['BOWLER', 'O', 'R', 'W', 'ECO', 'WD', 'NB'],
            bowlingRows,
            ink: ink,
            green: green,
            pale: pale,
            line: line,
            firstFlex: 2.5,
          ),
      ],
    );
  }

  static pw.Widget _table(
    List<String> headers,
    List<List<String>> rows, {
    required PdfColor ink,
    required PdfColor green,
    required PdfColor pale,
    required PdfColor line,
    double firstFlex = 2,
  }) => pw.Table(
        border: pw.TableBorder.all(color: line, width: .5),
        columnWidths: {
          0: pw.FlexColumnWidth(firstFlex),
          for (var index = 1; index < headers.length; index++) index: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: pale),
            children: headers
                .map((value) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      child: pw.Text(value, style: pw.TextStyle(color: green, fontSize: 6.6, fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...rows.map(
            (row) => pw.TableRow(
              children: row
                  .map((value) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
                        child: pw.Text(value, style: pw.TextStyle(color: ink, fontSize: 7.1)),
                      ))
                  .toList(),
            ),
          ),
        ],
      );

  static pw.Widget _section(String value, PdfColor ink) => pw.Text(
        value,
        style: pw.TextStyle(color: ink, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: .5),
      );

  static String _extraShort(ExtraType type) => switch (type) {
        ExtraType.wide => 'Wd',
        ExtraType.noBall => 'Nb',
        ExtraType.bye => 'B',
        ExtraType.legBye => 'Lb',
        ExtraType.penalty => 'P',
        ExtraType.none => '',
      };

  static String _on(bool value) => value ? 'ON' : 'OFF';

  static String _date(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
