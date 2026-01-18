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
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderCard(theme),
            const SizedBox(height: 12),
            // Team Standings Section
            StreamBuilder<List<TeamStats>>(
              stream: _badmintonFirestoreService.getTeamStats(
                _authService.currentUserEmailId ?? '',
                _tournamentId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        color: Colors.orange.shade700,
                        strokeWidth: 3,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint('❌ Stream Error: ${snapshot.error}');
                  return _buildErrorState(context, snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(context);
                }

                final teamStats = snapshot.data!
                  ..sort((a, b) {
                    // 🔥 1. Primary: Points
                    int res = b.points.compareTo(a.points);
                    if (res != 0) return res;

                    // 🔥 2. Secondary: Wins
                    res = b.won.compareTo(a.won);
                    if (res != 0) return res;

                    // 🔥 3. Tie-breaker: netResult (NEW!)
                    res = b.netResult.compareTo(a.netResult);
                    if (res != 0) return res;

                    // 4. Fallback: Matches played (fewer better)
                    return a.matchesPlayed.compareTo(b.matchesPlayed);
                  });

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _buildStandingsHeaderRow(theme),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: teamStats.length,
                              itemBuilder: (context, index) {
                                final team = teamStats[index];
                                return _buildTeamRow(theme, team, index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Player Statistics Section
            FinalPlayerStatsWidget(
              completedMatches: _statsService.getCompletedMatches(
                _authService.currentUserEmailId ?? '',
                _tournamentId,
              ),
              teams: _statsService.getTeams(
                _authService.currentUserEmailId ?? '',
                _tournamentId,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

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

  /// 🔥 UPDATED Header with NetR column + subtitles
  Widget _buildStandingsHeaderRow(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          _headerCell('P', 'Played'),
          _headerCell('W', 'Won'),
          _headerCell('Pts', 'Points'),
          _headerCell('NR', 'Net'), // 🔥 NEW: NetResult
        ],
      ),
    );
  }

  Widget _headerCell(String label, String subtitle) {
    return Column(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 🔥 UPDATED Team Row with netResult display
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3 ? badgeColor : Colors.grey.shade200,
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: badgeColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Team Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
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

          // 🔥 Stats Columns
          _statCell('${team.matchesPlayed}', Colors.blueGrey.shade700),
          _statCell('${team.won}', Colors.green.shade600),
          _statCell(
            '${team.points}',
            Colors.orange.shade700,
            isEmphasized: true,
          ),
          _netResultCell(team.netResult), // 🔥 NEW NetResult Cell
        ],
      ),
    );
  }

  /// 🔥 NEW NetResult Cell with color coding
  Widget _netResultCell(int netResult) {
    final isPositive = netResult > 0;
    final displayText = isPositive
        ? '+${netResult.abs()}'
        : '${netResult.abs()}';

    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
            ),
          ),
          Text(
            'NR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, Color color, {bool isEmphasized = false}) {
    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isEmphasized ? 14 : 13,
              fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            switch (color) {
              const Color.fromARGB(255, 69, 90, 100) => 'P',
              const Color.fromARGB(255, 67, 160, 71) => 'W',
              const Color.fromARGB(255, 245, 124, 0) => 'Pts',
              _ => '',
            },
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No teams found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
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
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
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
