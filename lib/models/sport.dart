import 'package:flutter/material.dart';

import 'package:play_hub/models/parse_utils.dart';

/// The sports supported by the app.
enum Sport {
  badminton,
  cricket,
  football;

  String get label => switch (this) {
        Sport.badminton => 'Badminton',
        Sport.cricket => 'Cricket',
        Sport.football => 'Football',
      };

  IconData get icon => switch (this) {
        Sport.badminton => Icons.sports_tennis_rounded,
        Sport.cricket => Icons.sports_cricket_rounded,
        Sport.football => Icons.sports_soccer_rounded,
      };

  /// Primary accent colour for the sport.
  Color get color => switch (this) {
        Sport.badminton => const Color(0xFF0D9488),
        Sport.cricket => const Color(0xFF2563EB),
        Sport.football => const Color(0xFFEA580C),
      };

  /// Darker companion colour, used for gradients.
  Color get colorDark => switch (this) {
        Sport.badminton => const Color(0xFF115E59),
        Sport.cricket => const Color(0xFF1E3A8A),
        Sport.football => const Color(0xFF9A3412),
      };

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, colorDark],
      );

  String get tagline => switch (this) {
        Sport.badminton => 'Singles, doubles & club leagues',
        Sport.cricket => 'Overs, wickets & net run rate',
        Sport.football => 'Goals, points & knockouts',
      };

  /// What a competitor is called in this sport.
  String get participantNoun => switch (this) {
        Sport.badminton => 'Player / Pair',
        Sport.cricket => 'Team',
        Sport.football => 'Team',
      };

  String get participantNounPlural => switch (this) {
        Sport.badminton => 'Players / Pairs',
        Sport.cricket => 'Teams',
        Sport.football => 'Teams',
      };

  String get playersHint => switch (this) {
        Sport.badminton => 'Partner name (for doubles)',
        Sport.cricket => 'Squad (one player per line)',
        Sport.football => 'Squad (one player per line)',
      };

  static Sport fromName(Object? name) =>
      parseEnum(Sport.values, name, Sport.football);
}
