import 'package:intl/intl.dart';

import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';

String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('EEE d MMM, h:mm a').format(date);

/// Rupee amount with Indian digit grouping, e.g. 150000 -> "₹1,50,000".
String formatRupees(int amount) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(amount)}';

/// One-line summary of a tournament's rules, e.g. "Best of 3 games to 21".
String rulesSummary(Sport sport, TournamentSettings settings) {
  switch (sport) {
    case Sport.football:
      return '${settings.halfMinutes} minute halves';
    case Sport.cricket:
      return '${settings.overs} overs per innings';
    case Sport.badminton:
      return 'Best of ${settings.bestOfGames} games to '
          '${settings.pointsPerGame}';
  }
}

/// "1 team" / "3 teams".
String pluralize(int count, String singular, [String? plural]) {
  final word = count == 1 ? singular : (plural ?? '${singular}s');
  return '$count $word';
}
