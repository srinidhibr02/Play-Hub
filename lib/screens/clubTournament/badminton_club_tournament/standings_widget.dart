import 'package:flutter/material.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';

/// Advanced Standings Widget with auto-calculations
class StandingsWidget extends StatefulWidget {
  final String tournamentId;
  final String categoryId;
  final Color categoryColor;

  const StandingsWidget({
    super.key,
    required this.tournamentId,
    required this.categoryId,
    required this.categoryColor,
  });

  @override
  State<StandingsWidget> createState() => _StandingsWidgetState();
}

class _StandingsWidgetState extends State<StandingsWidget> {
  final _service = ClubTournamentService();
  late Future<List<Map<String, dynamic>>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _standingsFuture = _calculateStandings();
  }

  /// Calculate standings from teams with auto-calculations
  Future<List<Map<String, dynamic>>> _calculateStandings() async {
    try {
      final teams = await _service.getTeams(
        widget.tournamentId,
        widget.categoryId,
      );

      // Sort teams by:
      // 1. Points (descending)
      // 2. Net Result (descending) - tiebreaker
      // 3. Points For (descending) - second tiebreaker
      teams.sort((a, b) {
        final statsA = a['stats'] as Map<String, dynamic>;
        final statsB = b['stats'] as Map<String, dynamic>;

        final pointsA = (statsA['points'] as int?) ?? 0;
        final pointsB = (statsB['points'] as int?) ?? 0;

        if (pointsA != pointsB) {
          return pointsB.compareTo(pointsA);
        }

        // Tiebreaker 1: Net Result
        final netA = (statsA['netResult'] as int?) ?? 0;
        final netB = (statsB['netResult'] as int?) ?? 0;

        if (netA != netB) {
          return netB.compareTo(netA);
        }

        // Tiebreaker 2: Points For
        final ptsForA = (statsA['pointsFor'] as int?) ?? 0;
        final ptsForB = (statsB['pointsFor'] as int?) ?? 0;

        return ptsForB.compareTo(ptsForA);
      });

      return teams;
    } catch (e) {
      debugPrint('❌ Error calculating standings: $e');
      return [];
    }
  }

  /// Refresh standings
  void _refreshStandings() {
    setState(() {
      _standingsFuture = _calculateStandings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: widget.categoryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error loading standings',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final standings = snapshot.data ?? [];

        if (standings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.leaderboard_rounded,
                  size: 56,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'No standings yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshStandings(),
          color: widget.categoryColor,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Standings Header
              _buildStandingsHeader(),
              const SizedBox(height: 12),

              // Standings List
              ...standings.asMap().entries.map((entry) {
                final position = entry.key + 1;
                final team = entry.value;
                return _buildStandingRow(team, position);
              }),

              const SizedBox(height: 16),

              // Legend
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandingsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.categoryColor.withOpacity(0.1),
            widget.categoryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.categoryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'Pos',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.categoryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Team',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.categoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              'W-L-D',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.categoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              'Net',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.categoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'Pts',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.categoryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow(Map<String, dynamic> team, int position) {
    final stats = team['stats'] as Map<String, dynamic>;
    final teamName = team['name'] as String;
    final points = (stats['points'] as int?) ?? 0;
    final won = (stats['won'] as int?) ?? 0;
    final lost = (stats['lost'] as int?) ?? 0;
    final drawn = (stats['drawn'] as int?) ?? 0;
    final netResult = (stats['netResult'] as int?) ?? 0;
    final matchesPlayed = (stats['matchesPlayed'] as int?) ?? 0;

    // Determine position badge color
    Color positionColor;
    if (position == 1) {
      positionColor = Colors.amber;
    } else if (position == 2) {
      positionColor = Colors.grey.shade500;
    } else if (position == 3) {
      positionColor = Colors.orange.shade700;
    } else {
      positionColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: position <= 3
              ? widget.categoryColor.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: position <= 3
            ? [
                BoxShadow(
                  color: widget.categoryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Position
          Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [positionColor.withOpacity(0.8), positionColor],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                position.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Team Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$matchesPlayed MP',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // W-L-D
          Container(
            width: 45,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$won-$lost-$drawn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Net Result with color coding
          Container(
            width: 45,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: netResult > 0
                  ? Colors.green.shade100
                  : netResult < 0
                  ? Colors.red.shade100
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: netResult > 0
                    ? Colors.green.shade300
                    : netResult < 0
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: Text(
              '${netResult > 0 ? '+' : ''}$netResult',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: netResult > 0
                    ? Colors.green.shade700
                    : netResult < 0
                    ? Colors.red.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Points
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.categoryColor.withOpacity(0.2),
                  widget.categoryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.categoryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  points.toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: widget.categoryColor,
                  ),
                ),
                Text(
                  'pts',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: widget.categoryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scoring System',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem('🏆 Win', '+2 Points', Colors.green),
          _buildLegendItem('🤝 Draw', '+1 Point', Colors.amber),
          _buildLegendItem('❌ Loss', '+0 Points', Colors.red),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Result (Tiebreaker)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Point difference from all matches. Example: If A scores 21 and B scores 15, Net Result = +6 for A, -6 for B',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
