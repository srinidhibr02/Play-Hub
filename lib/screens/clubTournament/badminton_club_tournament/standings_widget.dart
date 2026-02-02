import 'package:flutter/material.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';

/// Modern Advanced Standings Widget with premium UI/UX design
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

class _StandingsWidgetState extends State<StandingsWidget>
    with SingleTickerProviderStateMixin {
  final _service = ClubTournamentService();
  late Future<List<Map<String, dynamic>>> _standingsFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _standingsFuture = _calculateStandings();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Calculate standings from teams with auto-calculations
  Future<List<Map<String, dynamic>>> _calculateStandings() async {
    try {
      final teams = await _service.getTeams(
        widget.tournamentId,
        widget.categoryId,
      );

      teams.sort((a, b) {
        final statsA = a['stats'] as Map<String, dynamic>;
        final statsB = b['stats'] as Map<String, dynamic>;

        final pointsA = (statsA['points'] as int?) ?? 0;
        final pointsB = (statsB['points'] as int?) ?? 0;

        if (pointsA != pointsB) {
          return pointsB.compareTo(pointsA);
        }

        final netA = (statsA['netResult'] as int?) ?? 0;
        final netB = (statsB['netResult'] as int?) ?? 0;

        if (netA != netB) {
          return netB.compareTo(netA);
        }

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.categoryColor.withOpacity(0.2),
                          widget.categoryColor.withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      color: widget.categoryColor,
                      strokeWidth: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Standings...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Standings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.categoryColor.withOpacity(0.1),
                        widget.categoryColor.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.leaderboard_rounded,
                    size: 64,
                    color: widget.categoryColor.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Standings Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Standings will appear once matches are completed',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // ✅ FIXED: Removed RefreshIndicator - scrolling handled by parent
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ NEW: Full Standings Table
              Text(
                'Complete Standings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),

              _buildStandingsHeader(),
              const SizedBox(height: 8),

              // Standings List
              ...standings.asMap().entries.map((entry) {
                final position = entry.key + 1;
                final team = entry.value;
                return _buildStandingRow(team, position, entry.key);
              }),

              const SizedBox(height: 24),

              // ✅ NEW: Title Section
              _buildTitleSection(),
              const SizedBox(height: 24),

              // ✅ NEW: Stats Overview Cards
              _buildStatsOverview(standings),
              const SizedBox(height: 32),

              // ✅ NEW: Enhanced Legend
              _buildEnhancedLegend(),

              const SizedBox(height: 16),
              // ✅ NEW: Top 3 Podium
              if (standings.isNotEmpty) ...[
                _buildPodium(standings),
                const SizedBox(height: 32),
              ],
            ],
          ),
        );
      },
    );
  }

  /// ✅ NEW: Title Section
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.categoryColor.withOpacity(0.3),
                    widget.categoryColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.leaderboard_rounded,
                color: widget.categoryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'League Standings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Current rankings and points',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ NEW: Top 3 Podium View
  Widget _buildPodium(List<Map<String, dynamic>> standings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.categoryColor.withOpacity(0.05), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.categoryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Podium Title
          Text(
            '🏆 TOP 3',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: widget.categoryColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),

          // Podium
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              if (standings.length >= 2)
                _buildPodiumCard(standings[1], 2)
              else
                Container(),

              // 1st Place (Taller)
              if (standings.isNotEmpty)
                _buildPodiumCard(standings[0], 1)
              else
                Container(),

              // 3rd Place
              if (standings.length >= 3)
                _buildPodiumCard(standings[2], 3)
              else
                Container(),
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Podium Card for individual position
  Widget _buildPodiumCard(Map<String, dynamic> team, int position) {
    final teamName = team['players'].join('& ') as String;
    final stats = team['stats'] as Map<String, dynamic>;
    final points = (stats['points'] as int?) ?? 0;

    final podiumColors = {
      1: Colors.amber,
      2: Colors.grey.shade500,
      3: Colors.orange.shade700,
    };

    final podiumEmojis = {1: '🥇', 2: '🥈', 3: '🥉'};

    final podiumHeights = {1: 100.0, 2: 80.0, 3: 70.0};

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: podiumColors[position]!.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: podiumColors[position]!.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  podiumEmojis[position]!,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  teamName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: podiumHeights[position]!,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  podiumColors[position]!,
                  podiumColors[position]!.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    position.toString(),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$points pts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Stats Overview Cards
  Widget _buildStatsOverview(List<Map<String, dynamic>> standings) {
    if (standings.isEmpty) return const SizedBox.shrink();

    final topTeam = standings[0];
    final topStats = topTeam['stats'] as Map<String, dynamic>;

    int totalMatches = 0;
    int totalWins = 0;

    for (var team in standings) {
      final stats = team['stats'] as Map<String, dynamic>;
      totalMatches += (stats['matchesPlayed'] as int?) ?? 0;
      totalWins += (stats['won'] as int?) ?? 0;
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.sports_volleyball_rounded,
            label: 'Total Matches',
            value: (totalMatches ~/ standings.length).toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up_rounded,
            label: 'Teams',
            value: standings.length.toString(),
            color: widget.categoryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.verified_rounded,
            label: 'Leader Points',
            value: ((topStats['points'] as int?) ?? 0).toString(),
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  /// ✅ NEW: Stat Card
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.categoryColor.withOpacity(0.1),
            widget.categoryColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.categoryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'POS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: widget.categoryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'TEAM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: widget.categoryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'RECORD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: widget.categoryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              'DIFF',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: widget.categoryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'POINTS',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: widget.categoryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow(Map<String, dynamic> team, int position, int index) {
    final stats = team['stats'] as Map<String, dynamic>;
    final teamName = team['players'].join(' & ') as String;
    final points = (stats['points'] as int?) ?? 0;
    final won = (stats['won'] as int?) ?? 0;
    final lost = (stats['lost'] as int?) ?? 0;
    final drawn = (stats['drawn'] as int?) ?? 0;
    final netResult = (stats['netResult'] as int?) ?? 0;
    final matchesPlayed = (stats['matchesPlayed'] as int?) ?? 0;

    Color positionColor;
    if (position == 1) {
      positionColor = Colors.amber;
    } else if (position == 2) {
      positionColor = Colors.grey.shade500;
    } else if (position == 3) {
      positionColor = Colors.orange.shade700;
    } else {
      positionColor = widget.categoryColor.withOpacity(0.4);
    }

    final isTopThree = position <= 3;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.3 + (index * 0.05), 1.0, curve: Curves.easeOut),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTopThree
                ? widget.categoryColor.withOpacity(0.25)
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isTopThree
              ? [
                  BoxShadow(
                    color: widget.categoryColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
          gradient: isTopThree
              ? LinearGradient(
                  colors: [
                    widget.categoryColor.withOpacity(0.03),
                    Colors.white,
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            // Position Badge
            Container(
              width: 36,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.sports_volleyball_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$matchesPlayed matches',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Record
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 0.5),
              ),
              child: Column(
                children: [
                  Text(
                    '$won-$lost-$drawn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'W-L-D',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Net Result
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: netResult > 0
                    ? Colors.green.shade100
                    : netResult < 0
                    ? Colors.red.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: netResult > 0
                      ? Colors.green.shade300
                      : netResult < 0
                      ? Colors.red.shade300
                      : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${netResult > 0 ? '+' : ''}$netResult',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: netResult > 0
                          ? Colors.green.shade700
                          : netResult < 0
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Diff',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: netResult > 0
                          ? Colors.green.shade600
                          : netResult < 0
                          ? Colors.red.shade600
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Points
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.categoryColor.withOpacity(0.15),
                    widget.categoryColor.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.categoryColor.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    points.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: widget.categoryColor,
                    ),
                  ),
                  Text(
                    'pts',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: widget.categoryColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ NEW: Enhanced Legend
  Widget _buildEnhancedLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.categoryColor.withOpacity(0.08),
            widget.categoryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.categoryColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: widget.categoryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'Scoring System',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItemCompact('Win', '2 pts', Colors.green),
              _buildLegendItemCompact('Draw', '1 pt', Colors.amber),
              _buildLegendItemCompact('Loss', '0 pts', Colors.red),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade300, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Point Difference (Tiebreaker)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.purple.shade900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'When points are equal, teams are ranked by point difference (points scored minus points conceded).',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple.shade800,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Compact Legend Item
  Widget _buildLegendItemCompact(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 0.8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
