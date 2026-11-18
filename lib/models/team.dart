import 'package:play_hub/models/parse_utils.dart';

/// A competing side: a team (cricket, football) or a player/pair (badminton).
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorValue,
    this.players = const [],
    this.seed = 0,
  });

  final String id;
  final String name;
  final String shortName;
  final int colorValue;
  final List<String> players;

  /// Position in the entry list. Used for seeding knockout brackets.
  final int seed;

  Team copyWith({
    String? name,
    String? shortName,
    int? colorValue,
    List<String>? players,
    int? seed,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      colorValue: colorValue ?? this.colorValue,
      players: players ?? this.players,
      seed: seed ?? this.seed,
    );
  }

  /// Builds a 2-3 letter code from a team name, e.g. "Royal Strikers" -> "RS",
  /// "Falcons" -> "FAL".
  static String autoShortName(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length <= 3 ? w : w.substring(0, 3)).toUpperCase();
    }
    final initials = words.take(3).map((w) => w[0]).join();
    return initials.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'shortName': shortName,
        'colorValue': colorValue,
        'players': players,
        'seed': seed,
      };

  factory Team.fromMap(String id, Map<String, dynamic> map) {
    final playersRaw = map['players'];
    final name = parseString(map['name'], 'Team');
    return Team(
      id: id,
      name: name,
      shortName: parseString(map['shortName'], autoShortName(name)),
      colorValue: parseInt(map['colorValue'], 0xFF0D9488),
      players: playersRaw is List
          ? playersRaw.whereType<String>().toList()
          : const [],
      seed: parseInt(map['seed']),
    );
  }
}
