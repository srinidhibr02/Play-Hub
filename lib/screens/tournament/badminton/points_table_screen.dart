import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:play_hub/service/badminton_services/tournament_stats_service.dart';
import 'package:play_hub/widgets/shared_tournament_badminton_stats.dart';

class StandingsTab extends StatefulWidget {
  final int? matchDuration;
  final int? breakDuration;
  final String? tournamentId;

  const StandingsTab({
    super.key,
    this.breakDuration,
    this.matchDuration,
    this.tournamentId,
  });

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab>
    with SingleTickerProviderStateMixin {
  final TournamentFirestoreService _badmintonFirestoreService =
      TournamentFirestoreService();
  final AuthService _authService = AuthService();
  final TournamentStatsService _statsService = TournamentStatsService();

  late final String _tournamentId;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tournamentId = widget.tournamentId ?? '';
    if (_tournamentId.isEmpty) {
      debugPrint('⚠️ Warning: Tournament ID is empty!');
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildHeaderCard(theme),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Team Standings Section
                  StreamBuilder<List<TeamStats>>(
                    stream: _badmintonFirestoreService.getTeamStats(
                      _authService.currentUserEmailId ?? '',
                      _tournamentId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('❌ Stream Error: ${snapshot.error}');
                        return _buildErrorState(
                          context,
                          snapshot.error.toString(),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      final teamStats = snapshot.data!
                        ..sort((a, b) {
                          int res = b.points.compareTo(a.points);
                          if (res != 0) return res;
                          res = b.won.compareTo(a.won);
                          if (res != 0) return res;
                          return a.matchesPlayed.compareTo(b.matchesPlayed);
                        });

                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: teamStats.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildStandingsHeaderRow(theme);
                                }
                                final team = teamStats[index - 1];
                                return _buildTeamRow(theme, team, index - 1);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Player Statistics Section
                  StreamBuilder<TournamentStatsSummary>(
                    stream: _statsService.getTournamentStatsStream(
                      _authService.currentUserEmailId ?? '',
                      _tournamentId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('❌ Player Stats Error: ${snapshot.error}');
                        return const SizedBox.shrink();
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.playerStats.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final stats = snapshot.data!;
                      return _buildPlayerStatsSection(theme, stats);
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== PLAYER STATISTICS SECTION =====

  Widget _buildPlayerStatsSection(
    ThemeData theme,
    TournamentStatsSummary stats,
  ) {
    // Group players by team
    final teamGroups = <String, List<PlayerStats>>{};
    for (final playerStat in stats.playerStats.values) {
      teamGroups.putIfAbsent(playerStat.teamId, () => []).add(playerStat);
    }

    // Sort players within each team by win rate
    teamGroups.forEach((teamId, players) {
      players.sort((a, b) => b.winRate.compareTo(a.winRate));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Player Statistics Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Individual Player Statistics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stats.completedMatches} matches completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Team sections with player stats
        ...teamGroups.entries.map((entry) {
          final teamId = entry.key;
          final players = entry.value;

          // Find team name (assuming you have access to teams)
          final teamName = players.isNotEmpty ? players.first.teamName : 'Team';

          return _buildTeamPlayerStatsSection(theme, teamName, players);
        }).toList(),
      ],
    );
  }

  Widget _buildTeamPlayerStatsSection(
    ThemeData theme,
    String teamName,
    List<PlayerStats> players,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  teamName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${players.length} players',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),

          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Player',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _playerStatHeader('P'),
                _playerStatHeader('W'),
                _playerStatHeader('L'),
                _playerStatHeader('Win %'),
              ],
            ),
          ),

          // Player rows
          ...players.map((playerStat) {
            return _buildPlayerStatRow(theme, playerStat);
          }).toList(),
        ],
      ),
    );
  }

  Widget _playerStatHeader(String label) {
    return SizedBox(
      width: label == 'Win %' ? 60 : 36,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPlayerStatRow(ThemeData theme, PlayerStats stats) {
    final winRateColor = stats.winRate >= 60
        ? Colors.green
        : stats.winRate >= 40
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Player name with avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stats.playerName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stats.playerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Matches played
          SizedBox(
            width: 36,
            child: Text(
              '${stats.matchesPlayed}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Wins
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.wins}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ),

          // Losses
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.losses}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),

          // Win rate
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${stats.winRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: winRateColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  stats.winRate >= 50 ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: winRateColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== TEAM STANDINGS UI BUILDERS =====

  Widget _buildHeaderCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade700, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Live team rankings & points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.leaderboard_outlined,
              color: Colors.white.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsHeaderRow(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            child: Text(
              'Rank',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const Expanded(
            child: Text(
              'Team',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          _headerCell('P'),
          _headerCell('W'),
          _headerCell('Pts'),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return SizedBox(
      width: 40,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTeamRow(ThemeData theme, TeamStats team, int index) {
    final rank = index + 1;
    final isTop3 = rank <= 3;

    final Color badgeColor = switch (rank) {
      1 => Colors.amber.shade600,
      2 => Colors.blueGrey.shade400,
      3 => Colors.brown.shade400,
      _ => theme.colorScheme.surfaceVariant,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3 ? badgeColor : Colors.grey.shade200,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (team.players.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      team.players.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          _statCell('${team.matchesPlayed}', Colors.blueGrey),
          _statCell('${team.won}', Colors.green.shade600),
          _statCell(
            '${team.points}',
            Colors.orange.shade700,
            isEmphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, Color color, {bool isEmphasized = false}) {
    return SizedBox(
      width: 40,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isEmphasized ? 14 : 13,
          fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No teams found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Standings will appear once matches are created and completed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
