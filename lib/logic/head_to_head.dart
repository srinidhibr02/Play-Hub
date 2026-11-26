import 'package:play_hub/models/tournament_match.dart';

/// Wins and draws between two teams across their finished matches.
class HeadToHeadRecord {
  const HeadToHeadRecord({
    required this.winsA,
    required this.winsB,
    required this.draws,
  });

  final int winsA;
  final int winsB;
  final int draws;

  int get played => winsA + winsB + draws;
}

/// Earlier meetings of the same two teams in one tournament, for example
/// the second leg of a league or a knockout rematch. Pure Dart.
class HeadToHead {
  const HeadToHead._();

  /// Finished matches between the same two teams as [match], in playing
  /// order, not counting [match] itself. Either side order counts.
  static List<TournamentMatch> otherMeetings(
    TournamentMatch match,
    List<TournamentMatch> all,
  ) {
    final a = match.teamAId;
    final b = match.teamBId;
    if (a == null || b == null) return const [];
    return all
        .where((m) =>
            m.id != match.id &&
            !m.isBye &&
            m.isCompleted &&
            m.score != null &&
            ((m.teamAId == a && m.teamBId == b) ||
                (m.teamAId == b && m.teamBId == a)))
        .toList()
      ..sort((x, y) {
        final c = x.round.compareTo(y.round);
        return c != 0 ? c : x.order.compareTo(y.order);
      });
  }

  /// Wins for [teamAId] and its opponent over [meetings]. A finished match
  /// with no winner counts as a draw.
  static HeadToHeadRecord record(
    String teamAId,
    List<TournamentMatch> meetings,
  ) {
    var winsA = 0, winsB = 0, draws = 0;
    for (final m in meetings) {
      final w = m.winnerId;
      if (w == null) {
        draws++;
      } else if (w == teamAId) {
        winsA++;
      } else {
        winsB++;
      }
    }
    return HeadToHeadRecord(winsA: winsA, winsB: winsB, draws: draws);
  }
}
