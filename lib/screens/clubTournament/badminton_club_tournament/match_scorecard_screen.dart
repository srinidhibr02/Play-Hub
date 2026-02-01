import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';
import 'package:play_hub/screens/clubTournament/club_service/tournament_progression_service.dart';

class MatchScorecardScreen extends StatefulWidget {
  final String tournamentId;
  final String categoryId;
  final Map<String, dynamic> match;
  final String tournamentFormat;

  const MatchScorecardScreen({
    super.key,
    required this.tournamentId,
    required this.categoryId,
    required this.match,
    required this.tournamentFormat,
  });

  @override
  State<MatchScorecardScreen> createState() => _MatchScorecardScreenState();
}

class _MatchScorecardScreenState extends State<MatchScorecardScreen> {
  late int score1;
  late int score2;
  late String status;
  late List<int> team1Sets;
  late List<int> team2Sets;
  int currentSet = 1;
  bool isLoading = false;

  final _service = ClubTournamentService();
  final _progressionService = TournamentProgressionService();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    score1 = widget.match['score1'] as int? ?? 0;
    score2 = widget.match['score2'] as int? ?? 0;
    status = widget.match['status'] as String? ?? 'Scheduled';
    team1Sets = [0, 0, 0];
    team2Sets = [0, 0, 0];
  }

  /// Increment score for team
  void _incrementScore(bool isTeam1) {
    setState(() {
      if (isTeam1) {
        score1++;
      } else {
        score2++;
      }
    });
  }

  /// Decrement score for team
  void _decrementScore(bool isTeam1) {
    setState(() {
      if (isTeam1) {
        if (score1 > 0) score1--;
      } else {
        if (score2 > 0) score2--;
      }
    });
  }

  /// Calculate net result (point difference)
  int _calculateNetResult(int score1, int score2) {
    return score1 - score2;
  }

  /// Determine winner
  String? _getWinner() {
    if (score1 > score2) return widget.match['team1']['id'];
    if (score2 > score1) return widget.match['team2']['id'];
    return null;
  }

  /// Save match result and handle tournament progression
  Future<void> _saveMatchResult() async {
    try {
      setState(() => isLoading = true);

      final team1Id = widget.match['team1']['id'] as String;
      final team2Id = widget.match['team2']['id'] as String;
      final winner = _getWinner();

      // Determine points based on match result
      int points1 = 0, points2 = 0;
      int won1 = 0, won2 = 0;
      int lost1 = 0, lost2 = 0;

      if (score1 > score2) {
        points1 = 2;
        won1 = 1;
        lost2 = 1;
      } else if (score2 > score1) {
        points2 = 2;
        won2 = 1;
        lost1 = 1;
      } else {
        points1 = 1;
        points2 = 1;
      }

      // Calculate net results
      final netResult1 = _calculateNetResult(score1, score2);
      final netResult2 = _calculateNetResult(score2, score1);

      // Update teams stats
      await _service.updateTeamStats(
        widget.tournamentId,
        widget.categoryId,
        team1Id,
        won: won1,
        lost: lost1,
        points: points1,
        netResult: netResult1,
      );

      await _service.updateTeamStats(
        widget.tournamentId,
        widget.categoryId,
        team2Id,
        won: won2,
        lost: lost2,
        points: points2,
        netResult: netResult2,
      );

      // Update match
      await _service.updateMatch(
        widget.tournamentId,
        widget.categoryId,
        widget.match['id'] as String,
        {
          'status': 'Completed',
          'score1': score1,
          'score2': score2,
          'winner': winner,
          'completedAt': FieldValue.serverTimestamp(),
        },
      );

      // Handle tournament progression
      if (widget.tournamentFormat == 'knockout') {
        // Progress knockout tournament
        await _progressionService.progressKnockoutRound(
          widget.tournamentId,
          widget.categoryId,
          DateTime.now(),
          const TimeOfDay(hour: 9, minute: 0),
          30,
          5,
        );

        // Check if semi-finals complete and create finals
        await _progressionService.checkAndCreateFinals(
          widget.tournamentId,
          widget.categoryId,
          DateTime.now(),
          const TimeOfDay(hour: 9, minute: 0),
          30,
          5,
        );
      } else if (widget.tournamentFormat == 'round_robin') {
        // Check if league complete and create playoffs
        final isComplete = await _progressionService.isLeagueComplete(
          widget.tournamentId,
          widget.categoryId,
        );

        if (isComplete) {
          // Create semi-finals with top 4 teams
          await _progressionService.createRoundRobinPlayoffs(
            widget.tournamentId,
            widget.categoryId,
            DateTime.now(),
            const TimeOfDay(hour: 9, minute: 0),
            30,
            5,
          );

          // Check if semi-finals complete and create finals
          await _progressionService.checkAndCreateFinals(
            widget.tournamentId,
            widget.categoryId,
            DateTime.now(),
            const TimeOfDay(hour: 9, minute: 0),
            30,
            5,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Match result saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team1 = widget.match['team1'] as Map<String, dynamic>;
    final team2 = widget.match['team2'] as Map<String, dynamic>;
    final stage = widget.match['stage'] as String? ?? 'League';
    final bestOf = widget.match['bestOf'] as int? ?? 1;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey.shade900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Scorecard',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${team1['name']} vs ${team2['name']}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Info
              _buildTournamentInfo(stage, bestOf),

              const SizedBox(height: 20),

              // Score Board Section
              _buildScoreBoard(team1, team2),

              const SizedBox(height: 24),

              // Teams Section
              _buildTeamsSection(team1, team2),

              const SizedBox(height: 24),

              // Match Info
              _buildMatchInfo(stage),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildTournamentInfo(String stage, int bestOf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                'Stage',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          if (bestOf > 1)
            Column(
              children: [
                Text(
                  'Format',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Best of $bestOf',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard(
    Map<String, dynamic> team1,
    Map<String, dynamic> team2,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Team Names
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team1['name'] as String? ?? 'Team 1',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  team2['name'] as String? ?? 'Team 2',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Score Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          score1.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          score2.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Net Result Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Net Result',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_calculateNetResult(score1, score2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _calculateNetResult(score1, score2) >= 0
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.2),
                ),
                Column(
                  children: [
                    Text(
                      'Points',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score1 > score2
                          ? '2'
                          : score1 == score2
                          ? '1'
                          : '0',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.yellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(
    Map<String, dynamic> team1,
    Map<String, dynamic> team2,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Control',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),

        _buildScoreControl(
          team1['name'] as String? ?? 'Team 1',
          score1,
          true,
          Colors.teal,
        ),

        const SizedBox(height: 16),

        _buildScoreControl(
          team2['name'] as String? ?? 'Team 2',
          score2,
          false,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildScoreControl(
    String teamName,
    int score,
    bool isTeam1,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _decrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.remove_rounded, color: color, size: 28),
                ),
              ),

              const SizedBox(width: 20),

              Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    score.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              GestureDetector(
                onTap: () => _incrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.add_rounded, color: color, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchInfo(String stage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Stage', stage, Colors.blue),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Format',
            widget.tournamentFormat == 'round_robin' ? 'League' : 'Knockout',
            Colors.purple,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Winner',
            _getWinner() != null ? 'Determined' : 'Pending',
            _getWinner() != null ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLoading ? null : _saveMatchResult,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.green.shade200,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Result',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
