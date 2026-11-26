import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:play_hub/logic/badminton_stats.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/logic/player_stats.dart';
import 'package:play_hub/logic/scorecard.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// A printable summary of a tournament: table, fixtures with results and
/// player leaders. Built from data already loaded, so it works offline.
///
/// The built-in PDF font covers Latin text only. Other characters (for
/// example Indian-language names) are replaced with "?" rather than failing.
class PdfExport {
  const PdfExport._();

  static Future<Uint8List> build({
    required Tournament tournament,
    required List<Team> teams,
    required List<TournamentMatch> matches,
    DateTime? generatedAt,
  }) async {
    final t = tournament;
    final accent = PdfColor.fromInt(t.sport.color.toARGB32());
    final visible = matches.where((m) => !m.isBye).toList()
      ..sort((x, y) {
        final c = x.round.compareTo(y.round);
        return c != 0 ? c : x.order.compareTo(y.order);
      });
    final now = generatedAt ?? DateTime.now();

    final doc = pw.Document(title: _safe(t.name), author: 'Play Hub');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Play Hub | ${_date(now)} | page ${context.pageNumber} of '
            '${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _header(t, accent, teams.length, visible),
          if (t.format != TournamentFormat.knockout && visible.isNotEmpty)
            ..._table(t, teams, matches, accent),
          if (visible.isNotEmpty) ..._fixtures(t, visible, accent),
          ..._leaders(t, teams, matches, accent),
        ],
      ),
    );
    return doc.save();
  }

  // ------------------------------------------------------------------ parts

  static pw.Widget _header(
    Tournament t,
    PdfColor accent,
    int teamCount,
    List<TournamentMatch> matches,
  ) {
    final played = matches.where((m) => m.isCompleted).length;
    final info = <String>[
      '${t.sport.label} | ${t.format.label}',
      'Starts ${_date(t.startDate)}',
      if (t.venue.isNotEmpty) t.venue,
      '$teamCount ${t.sport.participantNounPlural.toLowerCase()}',
      if (matches.isNotEmpty) '$played of ${matches.length} matches played',
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _safe(t.name),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _safe(info.join('  |  ')),
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
          if (t.description.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              _safe(t.description),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _table(
    Tournament t,
    List<Team> teams,
    List<TournamentMatch> matches,
    PdfColor accent,
  ) {
    final rows = Standings.compute(
      sport: t.sport,
      settings: t.settings,
      teams: teams,
      matches: matches,
    );
    String signed(int v) => v > 0 ? '+$v' : '$v';

    final headers = switch (t.sport) {
      Sport.football => ['#', 'Team', 'P', 'W', 'D', 'L', 'GD', 'Pts'],
      Sport.cricket => ['#', 'Team', 'P', 'W', 'L', 'T', 'NRR', 'Pts'],
      Sport.badminton => ['#', 'Team', 'P', 'W', 'L', 'GD', 'PD', 'Pts'],
    };
    List<String> cells(int i, Standing r) => switch (t.sport) {
          Sport.football => [
              '${i + 1}', _safe(r.team.name), '${r.played}', '${r.won}',
              '${r.drawn}', '${r.lost}', signed(r.goalDifference),
              '${r.points}',
            ],
          Sport.cricket => [
              '${i + 1}', _safe(r.team.name), '${r.played}', '${r.won}',
              '${r.lost}', '${r.drawn}',
              '${r.netRunRate >= 0 ? '+' : ''}'
                  '${r.netRunRate.toStringAsFixed(3)}',
              '${r.points}',
            ],
          Sport.badminton => [
              '${i + 1}', _safe(r.team.name), '${r.played}', '${r.won}',
              '${r.lost}', signed(r.gameDifference),
              signed(r.pointDifference), '${r.points}',
            ],
        };

    return [
      _title('Table', accent),
      pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300),
          bottom: pw.BorderSide(color: PdfColors.grey400),
        ),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FlexColumnWidth(),
          for (var i = 2; i < headers.length; i++)
            i: const pw.FixedColumnWidth(40),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              for (var i = 0; i < headers.length; i++)
                _cell(headers[i], bold: true, left: i < 2),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            pw.TableRow(
              children: [
                for (var c = 0; c < headers.length; c++)
                  _cell(
                    cells(i, rows[i])[c],
                    bold: c == headers.length - 1,
                    left: c < 2,
                  ),
              ],
            ),
        ],
      ),
    ];
  }

  static List<pw.Widget> _fixtures(
    Tournament t,
    List<TournamentMatch> matches,
    PdfColor accent,
  ) {
    final widgets = <pw.Widget>[_title('Fixtures and results', accent)];
    int? round;
    for (final m in matches) {
      if (m.round != round) {
        round = m.round;
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              _safe(m.roundLabel),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        );
      }
      widgets.add(_matchRow(t, m));
    }
    return widgets;
  }

  static pw.Widget _matchRow(Tournament t, TournamentMatch m) {
    final score = m.score;
    final a = _safe(m.teamAName ?? 'To be decided');
    final b = _safe(m.teamBName ?? 'To be decided');
    final started = score != null && m.status != MatchStatus.scheduled;

    final middle = started
        ? '${MatchRules.sideScore(sport: t.sport, score: score, sideA: true)}'
            ' - '
            '${MatchRules.sideScore(sport: t.sport, score: score, sideA: false)}'
        : 'vs';

    final details = <String>[
      if (m.isCompleted && score != null)
        MatchRules.summary(
          sport: t.sport,
          score: score,
          teamAName: m.teamAName,
          teamBName: m.teamBName,
          teamAId: m.teamAId,
          winnerId: m.winnerId,
        ),
      if (m.status == MatchStatus.live) 'Live',
      if (m.scheduledAt != null)
        '${_date(m.scheduledAt!)} ${_time(m.scheduledAt!)}',
      if (m.venue.isNotEmpty) m.venue,
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  a,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: m.winnerId != null && m.winnerId == m.teamAId
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 64,
                child: pw.Text(
                  middle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  b,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: m.winnerId != null && m.winnerId == m.teamBId
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty)
            pw.Center(
              child: pw.Text(
                _safe(details.join('  |  ')),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static List<pw.Widget> _leaders(
    Tournament t,
    List<Team> teams,
    List<TournamentMatch> matches,
    PdfColor accent,
  ) {
    final sections = <(String, List<String>)>[];
    switch (t.sport) {
      case Sport.football:
        final all = PlayerStats.compute(matches: matches, teams: teams);
        sections.add((
          'Top scorers',
          [
            for (final p in PlayerStats.topScorers(all))
              '${p.name} (${p.teamName}): ${p.goals}',
          ],
        ));
        sections.add((
          'Most assists',
          [
            for (final p in PlayerStats.topAssists(all))
              '${p.name} (${p.teamName}): ${p.assists}',
          ],
        ));
      case Sport.cricket:
        final all = CricketStats.compute(matches: matches, teams: teams);
        sections.add((
          'Most runs',
          [
            for (final p in CricketStats.topBatters(all))
              '${p.name} (${p.teamName}): ${p.runs}, highest ${p.highestText}',
          ],
        ));
        sections.add((
          'Most wickets',
          [
            for (final p in CricketStats.topBowlers(all))
              '${p.name} (${p.teamName}): ${p.wickets}, best ${p.bestFigures}',
          ],
        ));
      case Sport.badminton:
        final all = BadmintonStats.compute(matches: matches, teams: teams);
        sections.add((
          'Most wins',
          [
            for (final p in BadmintonStats.mostWins(all))
              '${p.name}: ${p.won} of ${p.played}',
          ],
        ));
    }

    final filled = sections.where((s) => s.$2.isNotEmpty).toList();
    if (filled.isEmpty) return const [];
    return [
      _title('Player leaders', accent),
      for (final s in filled) ...[
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.Text(
            s.$1,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        for (var i = 0; i < s.$2.length; i++)
          pw.Text(
            _safe('${i + 1}. ${s.$2[i]}'),
            style: const pw.TextStyle(fontSize: 9),
          ),
      ],
    ];
  }

  // ---------------------------------------------------------------- helpers

  static pw.Widget _title(String text, PdfColor accent) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
      );

  static pw.Widget _cell(String text, {bool bold = false, bool left = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        child: pw.Text(
          text,
          textAlign: left ? pw.TextAlign.left : pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  /// Replaces characters the built-in font cannot draw.
  static String _safe(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      out.write(rune < 256 ? String.fromCharCode(rune) : '?');
    }
    return out.toString();
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}
