import 'package:play_hub/models/parse_utils.dart';

/// One batter's innings in a cricket scorecard.
class BatterLine {
  const BatterLine({
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.out = false,
    this.dismissal = '',
  });

  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;

  /// False means not out (or did not get to bat the full innings).
  final bool out;

  /// Free text such as "b Kiran", "c Sam b Kiran" or "run out".
  final String dismissal;

  /// Runs per 100 balls, or null before facing a ball.
  double? get strikeRate => balls == 0 ? null : runs * 100 / balls;

  BatterLine copyWith({
    String? name,
    int? runs,
    int? balls,
    int? fours,
    int? sixes,
    bool? out,
    String? dismissal,
  }) =>
      BatterLine(
        name: name ?? this.name,
        runs: runs ?? this.runs,
        balls: balls ?? this.balls,
        fours: fours ?? this.fours,
        sixes: sixes ?? this.sixes,
        out: out ?? this.out,
        dismissal: dismissal ?? this.dismissal,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'out': out,
        'dismissal': dismissal,
      };

  factory BatterLine.fromMap(Map<String, dynamic> map) => BatterLine(
        name: parseString(map['name']),
        runs: parseInt(map['runs']),
        balls: parseInt(map['balls']),
        fours: parseInt(map['fours']),
        sixes: parseInt(map['sixes']),
        out: parseBool(map['out']),
        dismissal: parseString(map['dismissal']),
      );
}

/// One bowler's spell in a cricket scorecard.
class BowlerLine {
  const BowlerLine({
    required this.name,
    this.balls = 0,
    this.runs = 0,
    this.wickets = 0,
    this.maidens = 0,
  });

  final String name;

  /// Legal balls bowled (an over is 6).
  final int balls;
  final int runs;
  final int wickets;
  final int maidens;

  /// Runs conceded per over, or null before bowling a ball.
  double? get economy => balls == 0 ? null : runs * 6 / balls;

  BowlerLine copyWith({
    String? name,
    int? balls,
    int? runs,
    int? wickets,
    int? maidens,
  }) =>
      BowlerLine(
        name: name ?? this.name,
        balls: balls ?? this.balls,
        runs: runs ?? this.runs,
        wickets: wickets ?? this.wickets,
        maidens: maidens ?? this.maidens,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'balls': balls,
        'runs': runs,
        'wickets': wickets,
        'maidens': maidens,
      };

  factory BowlerLine.fromMap(Map<String, dynamic> map) => BowlerLine(
        name: parseString(map['name']),
        balls: parseInt(map['balls']),
        runs: parseInt(map['runs']),
        wickets: parseInt(map['wickets']),
        maidens: parseInt(map['maidens']),
      );
}
