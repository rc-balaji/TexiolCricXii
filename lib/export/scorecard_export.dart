import 'dart:io';

import 'package:flutter/services.dart';
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
    final avatars = <String, pw.MemoryImage?>{};
    for (final stats in rankings) {
      final player = players[stats.playerId];
      if (player != null) avatars[player.id] = await _avatarFor(player);
    }

    final document = pw.Document(
      title: 'CricXii Scorecard ${match.id}',
      author: 'CricXii by Texiol',
      creator: 'CricXii v0.3.0',
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

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 26, 30, 30),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: pw.BoxDecoration(
            color: ink,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CRICXII',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    'OFFICIAL MATCH SCORECARD',
                    style: const pw.TextStyle(
                      color: green,
                      fontSize: 7.5,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'BY TEXIOL',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CricXii • Local cricket, permanent history',
                style: const pw.TextStyle(color: muted, fontSize: 7.5),
              ),
              pw.Text(
                'Page ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 7.5),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      match.title,
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '${_date(match.createdAt)} • Match ID ${match.id}',
                      style: const pw.TextStyle(color: muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: pale,
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  match.scoringMode == ScoringMode.ballByBall
                      ? '${match.ballLimit} BALLS EACH'
                      : 'DIRECT RUNS',
                  style: pw.TextStyle(
                    color: greenDark,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
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
              pw.SizedBox(width: 8),
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
              pw.SizedBox(width: 8),
              _metricTile(
                'STATUS',
                'FINAL',
                icon: '✓',
                ink: ink,
                muted: muted,
                pale: pale,
              ),
            ],
          ),
          if (winner != null && winnerPlayer != null) ...[
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: ink,
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Row(
                children: [
                  _pdfAvatar(
                    winnerPlayer,
                    avatars[winnerPlayer.id],
                    size: 66,
                    background: green,
                    textColor: ink,
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MATCH WINNER',
                          style: const pw.TextStyle(
                            color: green,
                            fontSize: 8,
                            letterSpacing: 1.1,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          winnerPlayer.name,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 21,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Player ID ${winnerPlayer.id}',
                          style: const pw.TextStyle(
                            color: muted,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        match.winnerMetric == MatchWinnerMetric.runs
                            ? '${winner.runs}'
                            : '${winner.points}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 31,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        match.winnerMetric == MatchWinnerMetric.runs
                            ? 'RUNS'
                            : 'POINTS',
                        style: const pw.TextStyle(
                          color: green,
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (rankings.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('PODIUM', ink),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < rankings.length && index < 3; index++) ...[
                  if (index > 0) pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _podiumCard(
                      rank: index + 1,
                      stats: rankings[index],
                      player: players[rankings[index].playerId],
                      avatar: avatars[rankings[index].playerId],
                      accent: index == 0
                          ? gold
                          : index == 1
                          ? silver
                          : bronze,
                      ink: ink,
                      muted: muted,
                    ),
                  ),
                ],
              ],
            ),
          ],
          pw.SizedBox(height: 20),
          _sectionTitle('FINAL RANKING', ink),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line, width: .7),
              borderRadius: pw.BorderRadius.circular(12),
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
                    green: greenDark,
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('MATCH DETAILS', ink),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: pale,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _detail('Scoring', match.scoringMode == ScoringMode.ballByBall
                    ? 'Ball by ball'
                    : 'Quick total', ink, muted),
                _detail('Winner metric', match.winnerMetric == MatchWinnerMetric.runs
                    ? 'Runs'
                    : 'Overall points', ink, muted),
                _detail('Run point', '${match.pointRules.run}', ink, muted),
                _detail('Wicket', '${match.pointRules.wicket}', ink, muted),
                _detail('Catch', '${match.pointRules.catchPoint}', ink, muted),
                _detail('Direct RO', '${match.pointRules.directRunOut}', ink, muted),
                _detail('Stumping', '${match.pointRules.stumping}', ink, muted),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              'Generated from CricXii match data. Player avatar images use the selected CricXii preset or the available profile photo, with an offline fallback when a remote image cannot be loaded.',
              style: const pw.TextStyle(color: muted, fontSize: 7.8),
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

  static pw.Widget _metricTile(
    String label,
    String value, {
    required String icon,
    required PdfColor ink,
    required PdfColor muted,
    required PdfColor pale,
  }) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: pale,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 27,
            height: 27,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              icon,
              style: pw.TextStyle(
                color: ink,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static pw.Widget _sectionTitle(String text, PdfColor ink) => pw.Text(
    text,
    style: pw.TextStyle(
      color: ink,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: .7,
    ),
  );

  static pw.Widget _podiumCard({
    required int rank,
    required PlayerMatchStats stats,
    required Player? player,
    required pw.MemoryImage? avatar,
    required PdfColor accent,
    required PdfColor ink,
    required PdfColor muted,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: accent, width: 1.2),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(999),
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
        pw.SizedBox(height: 8),
        if (player != null)
          _pdfAvatar(
            player,
            avatar,
            size: 44,
            background: accent,
            textColor: ink,
          ),
        pw.SizedBox(height: 7),
        pw.Text(
          player?.name ?? stats.playerId,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${stats.runs} runs • ${stats.points} pts',
          style: pw.TextStyle(color: muted, fontSize: 7.5),
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
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: pw.BoxDecoration(
      color: rank == 1 ? pale : PdfColors.white,
      border: showDivider
          ? pw.Border(bottom: pw.BorderSide(color: line, width: .6))
          : null,
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 24,
          alignment: pw.Alignment.center,
          child: pw.Text(
            '$rank',
            style: pw.TextStyle(
              color: rank == 1 ? green : ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (player != null) ...[
          _pdfAvatar(
            player,
            avatar,
            size: 34,
            background: pale,
            textColor: ink,
          ),
          pw.SizedBox(width: 9),
        ],
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                player?.name ?? stats.playerId,
                style: pw.TextStyle(
                  color: ink,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ID ${player?.id ?? stats.playerId}',
                style: pw.TextStyle(color: muted, fontSize: 6.8),
              ),
            ],
          ),
        ),
        _tinyStat('RUNS', '${stats.runs}', ink, muted),
        pw.SizedBox(width: 12),
        _tinyStat('WKTS', '${stats.wickets}', ink, muted),
        pw.SizedBox(width: 12),
        _tinyStat('PTS', '${stats.points}', ink, muted),
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
      pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 6)),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: ink,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );

  static pw.Widget _detail(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) => pw.Container(
    width: 115,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 6.5)),
        pw.SizedBox(height: 2),
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
      borderRadius: pw.BorderRadius.circular(size * .24),
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
    final url = player.resolvedAvatarUrl;
    if (url != null && Uri.tryParse(url)?.isScheme('https') == true) {
      final remote = await _downloadImage(url);
      if (remote != null) return pw.MemoryImage(remote);
    }
    try {
      final preset = player.avatarPreset.clamp(1, 5);
      final data = await rootBundle.load('assets/avatars/avatar_$preset.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } on Object {
      return null;
    }
  }

  static Future<Uint8List?> _downloadImage(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024) return null;
      }
      return Uint8List.fromList(bytes);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
