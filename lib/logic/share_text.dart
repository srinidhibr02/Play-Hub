import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// Plain-text summaries an organizer can paste into WhatsApp. Pure Dart.
class ShareText {
  const ShareText._();

  /// Result (or current score) of one match.
  static String match({
    required Tournament tournament,
    required TournamentMatch match,
  }) {
    final a = match.teamAName ?? 'Team A';
    final b = match.teamBName ?? 'Team B';
    final score = match.score;
    final sport = tournament.sport;
    final lines = <String>['${tournament.name} | ${match.roundLabel}'];

    if (score == null) {
      lines.add('$a vs $b');
      if (match.scheduledAt != null) {
        final t = match.scheduledAt!;
        lines.add('${_date(t)} at ${_time(t)}');
      }
      if (match.venue.isNotEmpty) lines.add('Venue: ${match.venue}');
      return lines.join('\n');
    }

    final live = match.status == MatchStatus.live;
    switch (sport) {
      case Sport.football:
        lines.add(
          '$a ${score.goalsA} - ${score.goalsB} $b${live ? ' (live)' : ''}',
        );
      case Sport.cricket:
        lines.add(
          '$a ${score.runsA}/${score.wicketsA} '
          '(${MatchRules.oversText(score.ballsA)} ov)',
        );
        lines.add(
          '$b ${score.runsB}/${score.wicketsB} '
          '(${MatchRules.oversText(score.ballsB)} ov)'
          '${live ? ' (live)' : ''}',
        );
      case Sport.badminton:
        final (ga, gb) = MatchRules.gamesWon(score.games);
        lines.add('$a $ga - $gb $b${live ? ' (live)' : ''}');
        if (score.games.isNotEmpty) {
          lines.add(score.games.map((g) => '${g.a}-${g.b}').join(', '));
        }
    }

    if (match.isCompleted) {
      lines.add(
        MatchRules.summary(
          sport: sport,
          score: score,
          teamAName: match.teamAName,
          teamBName: match.teamBName,
          teamAId: match.teamAId,
          winnerId: match.winnerId,
        ),
      );
    }

    if (sport == Sport.football) {
      final scorers = _scorers(match, score);
      if (scorers.isNotEmpty) lines.addAll(scorers);
    }
    return lines.join('\n');
  }

  static List<String> _scorers(TournamentMatch m, MatchScore score) {
    final goals =
        score.events.where((e) => e.type.isGoal).toList()
          ..sort((x, y) => (x.minute ?? 999).compareTo(y.minute ?? 999));
    if (goals.isEmpty) return const [];

    String entry(MatchEvent e) {
      final suffix = switch (e.type) {
        MatchEventType.penaltyGoal => ' (pen)',
        MatchEventType.ownGoal => ' (og)',
        _ => '',
      };
      final minute = e.minute == null ? '' : " ${e.minute}'";
      return '${e.player}$minute$suffix';
    }

    // An own goal belongs in the list of the side it counted for.
    bool forA(MatchEvent e) => e.type == MatchEventType.ownGoal
        ? e.teamId == m.teamBId
        : e.teamId == m.teamAId;

    final a = goals.where(forA).map(entry).toList();
    final b = goals.where((e) => !forA(e)).map(entry).toList();
    return [
      if (a.isNotEmpty) '${m.teamAName ?? 'Team A'}: ${a.join(', ')}',
      if (b.isNotEmpty) '${m.teamBName ?? 'Team B'}: ${b.join(', ')}',
    ];
  }

  /// The league table, one team per line.
  static String table({
    required Tournament tournament,
    required List<Standing> rows,
  }) {
    final lines = <String>[
      '${tournament.name} | Table',
      '${tournament.sport.label} | ${tournament.format.label}',
      '',
    ];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final detail = switch (tournament.sport) {
        Sport.football =>
          'P${r.played} W${r.won} D${r.drawn} L${r.lost} '
              'GD${_signed(r.goalDifference)}',
        Sport.cricket =>
          'P${r.played} W${r.won} L${r.lost} T${r.drawn} '
              'NRR ${r.netRunRate >= 0 ? '+' : ''}'
              '${r.netRunRate.toStringAsFixed(3)}',
        Sport.badminton =>
          'P${r.played} W${r.won} L${r.lost} '
              'PD${_signed(r.pointDifference)}',
      };
      lines.add('${i + 1}. ${r.team.name}: ${r.points} pts ($detail)');
    }
    return lines.join('\n');
  }

  static String _signed(int v) => v > 0 ? '+$v' : '$v';

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
