import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament_match.dart';

/// One headline number, e.g. label "Total goals", value "23".
class StatLine {
  const StatLine(this.label, this.value, {this.detail = ''});

  final String label;
  final String value;

  /// Optional second line, e.g. "Reds 5-0 Blues".
  final String detail;
}

/// Headline numbers for a tournament, worked out from completed matches.
/// Pure Dart.
class TournamentStats {
  const TournamentStats._();

  /// Empty when nothing has been played yet.
  static List<StatLine> compute({
    required Sport sport,
    required List<TournamentMatch> matches,
  }) {
    final done = matches
        .where((m) => m.isCompleted && !m.isBye && m.score != null)
        .toList();
    if (done.isEmpty) return const [];

    String names(TournamentMatch m) =>
        '${m.teamAName ?? 'TBD'} vs ${m.teamBName ?? 'TBD'}';
    String avg(int total) => (total / done.length).toStringAsFixed(1);

    switch (sport) {
      case Sport.football:
        var total = 0;
        TournamentMatch? biggest;
        var biggestMargin = 0;
        TournamentMatch? highest;
        var highestTotal = -1;
        for (final m in done) {
          final s = m.score!;
          final sum = s.goalsA + s.goalsB;
          total += sum;
          final margin = (s.goalsA - s.goalsB).abs();
          if (margin > biggestMargin) {
            biggestMargin = margin;
            biggest = m;
          }
          if (sum > highestTotal) {
            highestTotal = sum;
            highest = m;
          }
        }
        return [
          StatLine('Total goals', '$total'),
          StatLine('Goals per match', avg(total)),
          if (biggest != null)
            StatLine(
              'Biggest win',
              'by $biggestMargin',
              detail:
                  '${names(biggest)}  (${biggest.score!.goalsA}-${biggest.score!.goalsB})',
            ),
          if (highest != null && highestTotal > 0)
            StatLine(
              'Highest scoring match',
              '$highestTotal goals',
              detail: names(highest),
            ),
        ];

      case Sport.cricket:
        var total = 0;
        TournamentMatch? best;
        var bestRuns = -1;
        var bestIsA = true;
        for (final m in done) {
          final s = m.score!;
          total += s.runsA + s.runsB;
          if (s.runsA > bestRuns) {
            bestRuns = s.runsA;
            best = m;
            bestIsA = true;
          }
          if (s.runsB > bestRuns) {
            bestRuns = s.runsB;
            best = m;
            bestIsA = false;
          }
        }
        return [
          StatLine('Total runs', '$total'),
          StatLine('Runs per match', avg(total)),
          if (best != null)
            StatLine(
              'Highest total',
              MatchRules.sideScore(
                sport: sport,
                score: best.score!,
                sideA: bestIsA,
              ),
              detail: (bestIsA ? best.teamAName : best.teamBName) ?? '',
            ),
        ];

      case Sport.badminton:
        var points = 0;
        var games = 0;
        var deciders = 0;
        for (final m in done) {
          final g = m.score!.games;
          games += g.length;
          for (final x in g) {
            points += x.a + x.b;
          }
          final (a, b) = MatchRules.gamesWon(g);
          // A match that went to the maximum number of games.
          if (a >= 1 && b >= 1 && (a - b).abs() == 1 && g.length >= 3) {
            deciders++;
          }
        }
        return [
          StatLine('Games played', '$games'),
          StatLine('Points scored', '$points'),
          StatLine('Games per match', avg(games)),
          StatLine('Three-game thrillers', '$deciders'),
        ];
    }
  }
}
