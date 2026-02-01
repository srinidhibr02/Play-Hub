import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';
import 'package:play_hub/screens/clubTournament/club_service/tournament_progression_service.dart';

class AdvancedMatchScorecardScreen extends StatefulWidget {
  final String tournamentId;
  final String categoryId;
  final Map<String, dynamic> match;
  final String tournamentFormat;
  final bool isBestOf3;

  const AdvancedMatchScorecardScreen({
    super.key,
    required this.tournamentId,
    required this.categoryId,
    required this.match,
    required this.tournamentFormat,
    required this.isBestOf3,
  });

  @override
  State<AdvancedMatchScorecardScreen> createState() =>
      _AdvancedMatchScorecardScreenState();
}

class _AdvancedMatchScorecardScreenState
    extends State<AdvancedMatchScorecardScreen> {
  late int score1;
  late int score2;
  late String status;
  late int setWins1; // Wins in the series
  late int setWins2; // Wins in the series
  late int currentSet; // 1, 2, or 3
  late List<Map<String, int>> setScores; // History of set scores
  bool isLoading = false;
  bool resultSaved = false; // ✅ NEW: Track if result is saved

  final _service = ClubTournamentService();
  final _progressionService = TournamentProgressionService();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    score1 = 0;
    score2 = 0;
    status = widget.match['status'] ?? 'Scheduled';
    setWins1 = 0;
    setWins2 = 0;
    currentSet = 1;
    setScores = [];

    // If match is already completed, load the previous results
    if (status == 'Completed') {
      _loadCompletedMatchData();
      resultSaved = true; // ✅ Mark as saved
    }
  }

  /// Load completed match data from Firestore
  void _loadCompletedMatchData() {
    if (widget.isBestOf3) {
      setWins1 = widget.match['score1'] as int? ?? 0;
      setWins2 = widget.match['score2'] as int? ?? 0;
      setScores = List<Map<String, int>>.from(
        (widget.match['setScores'] as List<dynamic>? ?? []).map(
          (score) => Map<String, int>.from(score as Map<dynamic, dynamic>),
        ),
      );
    } else {
      score1 = widget.match['score1'] as int? ?? 0;
      score2 = widget.match['score2'] as int? ?? 0;
    }
  }

  /// Check if match is completed
  bool _isMatchCompleted() {
    return status == 'Completed';
  }

  /// Check if current set is won
  Map<String, dynamic>? _checkSetWinner() {
    // Standard: First to 21
    if (score1 >= 21 || score2 >= 21) {
      // If either team reached 21, check if they have 2+ point lead
      if ((score1 - score2).abs() >= 2) {
        if (score1 > score2) {
          return {'winner': 1, 'score1': score1, 'score2': score2};
        } else {
          return {'winner': 2, 'score1': score1, 'score2': score2};
        }
      }
    }

    // Deuce handling: At 20-20, need 2 point lead
    if (score1 >= 20 && score2 >= 20) {
      if ((score1 - score2).abs() >= 2) {
        if (score1 > score2) {
          return {'winner': 1, 'score1': score1, 'score2': score2};
        } else {
          return {'winner': 2, 'score1': score1, 'score2': score2};
        }
      }
    }

    // Speed up rule: First to 30
    if (score1 >= 30 || score2 >= 30) {
      if (score1 > score2) {
        return {'winner': 1, 'score1': score1, 'score2': score2};
      } else {
        return {'winner': 2, 'score1': score1, 'score2': score2};
      }
    }

    return null;
  }

  /// Check if match (best of 3) is won
  bool _isMatchWon() {
    if (!widget.isBestOf3) {
      return false;
    }
    // Best of 3: First to win 2 sets
    return setWins1 >= 2 || setWins2 >= 2;
  }

  /// Move to next set
  void _nextSet() {
    if (resultSaved) return; // ✅ Don't allow if saved

    final setWinner = _checkSetWinner();
    if (setWinner != null) {
      setState(() {
        // Record this set score
        setScores.add({
          'set': currentSet,
          'score1': setWinner['score1'],
          'score2': setWinner['score2'],
          'winner': setWinner['winner'],
        });

        // Increment set wins
        if (setWinner['winner'] == 1) {
          setWins1++;
        } else {
          setWins2++;
        }

        // Check if match won (best of 3)
        if (widget.isBestOf3 && _isMatchWon()) {
          // Match complete
          status = 'Completed';
        } else if (currentSet < 3) {
          // Move to next set
          currentSet++;
          score1 = 0;
          score2 = 0;
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Set not complete yet'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Increment score for team (only if match not completed and not saved)
  void _incrementScore(bool isTeam1) {
    if (_isMatchCompleted() || resultSaved) return;

    // ✅ Check if set is completed
    final setWinner = _checkSetWinner();
    if (setWinner != null) {
      _showSetCompletedDialog(isTeam1, true);
      return;
    }

    setState(() {
      if (isTeam1) {
        score1++;
      } else {
        score2++;
      }
    });
  }

  /// Decrement score for team (only if match not completed and not saved)
  void _decrementScore(bool isTeam1) {
    if (_isMatchCompleted() || resultSaved) return;

    // ✅ Check if set is completed
    final setWinner = _checkSetWinner();
    if (setWinner != null) {
      _showSetCompletedDialog(isTeam1, false);
      return;
    }

    setState(() {
      if (isTeam1) {
        if (score1 > 0) score1--;
      } else {
        if (score2 > 0) score2--;
      }
    });
  }

  /// ✅ NEW: Show alert when set is completed
  void _showSetCompletedDialog(bool isTeam1, bool isIncrement) {
    final setWinner = _checkSetWinner();
    final winnerTeam = setWinner!['winner'] == 1 ? 'Team 1' : 'Team 2';
    final action = isIncrement ? 'increase' : 'decrease';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set Completed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set won by $winnerTeam',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This set has been completed. The score is fixed.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: Colors.amber.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click "Next Set" to continue to the next round',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Allow temporary override if user confirms
              _overrideScoreChange(isTeam1, isIncrement);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Override',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Allow score override after confirmation
  void _overrideScoreChange(bool isTeam1, bool isIncrement) {
    setState(() {
      if (isIncrement) {
        if (isTeam1) {
          score1++;
        } else {
          score2++;
        }
      } else {
        if (isTeam1) {
          if (score1 > 0) score1--;
        } else {
          if (score2 > 0) score2--;
        }
      }
    });

    // Show override message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Score override applied. Please verify before saving.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Get match winner (for best of 3)
  String? _getMatchWinner() {
    if (setWins1 > setWins2) {
      return widget.match['team1']['id'];
    } else if (setWins2 > setWins1) {
      return widget.match['team2']['id'];
    }
    return null;
  }

  /// Get winning team name
  String _getWinningTeamName() {
    final winnerId = widget.match['winner'] as String?;
    if (winnerId == null) return 'Unknown';

    if (winnerId == widget.match['team1']['id']) {
      return widget.match['team1']['name'] as String;
    } else {
      return widget.match['team2']['name'] as String;
    }
  }

  /// Save match result
  Future<void> _saveMatchResult() async {
    try {
      setState(() => isLoading = true);

      final team1Id = widget.match['team1']['id'] as String;
      final team2Id = widget.match['team2']['id'] as String;
      final winner = widget.isBestOf3
          ? _getMatchWinner()
          : score1 > score2
          ? team1Id
          : team2Id;

      if (widget.isBestOf3) {
        // Best of 3: Winner is who wins 2 sets
        if (!_isMatchWon()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Match not complete - need 2 set wins'),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          setState(() => isLoading = false);
          return;
        }

        // Points based on series result
        int points1 = 0, won1 = 0, lost1 = 0;
        int points2 = 0, won2 = 0, lost2 = 0;

        if (setWins1 > setWins2) {
          points1 = 2;
          won1 = 1;
          lost2 = 1;
        } else {
          points2 = 2;
          won2 = 1;
          lost1 = 1;
        }

        // Calculate net result from final scores of last set
        final lastSetScore = setScores.last;
        final netResult1 =
            (lastSetScore['score1'] as int) - (lastSetScore['score2'] as int);
        final netResult2 = -netResult1;

        // Update team stats
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
      } else {
        // Single set
        int points1 = 0, won1 = 0, lost1 = 0;
        int points2 = 0, won2 = 0, lost2 = 0;

        if (score1 > score2) {
          points1 = 2;
          won1 = 1;
          lost2 = 1;
        } else if (score2 > score1) {
          points2 = 2;
          won2 = 1;
          lost1 = 1;
        }

        final netResult1 = score1 - score2;
        final netResult2 = score2 - score1;

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
      }

      // Update match
      await _service.updateMatch(
        widget.tournamentId,
        widget.categoryId,
        widget.match['id'] as String,
        {
          'status': 'Completed',
          'score1': widget.isBestOf3 ? setWins1 : score1,
          'score2': widget.isBestOf3 ? setWins2 : score2,
          'winner': winner,
          'setScores': setScores,
          'completedAt': FieldValue.serverTimestamp(),
        },
      );

      // Handle tournament progression
      if (widget.tournamentFormat == 'knockout') {
        await _progressionService.progressKnockoutRound(
          widget.tournamentId,
          widget.categoryId,
          DateTime.now(),
          const TimeOfDay(hour: 9, minute: 0),
          30,
          5,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Match completed successfully!'),
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

      // ✅ Mark result as saved and lock scorecard
      setState(() {
        status = 'Completed';
        resultSaved = true; // Lock the scorecard
        isLoading = false;
      });

      // Delay navigation to show success message
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
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
              '${team1['members'].join(', ')} vs ${team2['members'].join(', ')}',
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
              _buildTournamentInfo(stage),

              const SizedBox(height: 20),

              // Series Info (for Best of 3)
              if (widget.isBestOf3) _buildSeriesInfo(),
              if (widget.isBestOf3) const SizedBox(height: 20),

              // Match Status Banner (when completed)
              if (_isMatchCompleted() || resultSaved) _buildCompletedBanner(),
              if (_isMatchCompleted() || resultSaved)
                const SizedBox(height: 20),

              // Current Set Display
              _buildSetDisplay(team1, team2),

              const SizedBox(height: 24),

              // Score Control (only if not completed and not saved)
              if (!_isMatchCompleted() && !resultSaved)
                Column(
                  children: [
                    _buildScoreControl(team1, team2),
                    const SizedBox(height: 24),
                  ],
                ),

              // Set History
              if (setScores.isNotEmpty) _buildSetHistory(),
              if (setScores.isNotEmpty) const SizedBox(height: 24),

              // Badminton Rules
              _buildRulesInfo(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  /// ✅ Build completed match banner
  Widget _buildCompletedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Match Completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Winner: ${_getWinningTeamName()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '🔒 Scoring is locked - Match results are final',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentInfo(String stage) {
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
                'Round',
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
          if (widget.isBestOf3)
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
                  'Best of 3',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          Column(
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (resultSaved || _isMatchCompleted())
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (resultSaved || _isMatchCompleted())
                      ? 'Completed'
                      : 'In Progress',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (resultSaved || _isMatchCompleted())
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'Set',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (resultSaved || _isMatchCompleted())
                    ? 'Final'
                    : '$currentSet/3',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'Series',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$setWins1 - $setWins2',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (resultSaved || _isMatchCompleted())
                    ? 'Complete'
                    : 'In Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: (resultSaved || _isMatchCompleted())
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetDisplay(
    Map<String, dynamic> team1,
    Map<String, dynamic> team2,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (resultSaved || _isMatchCompleted())
              ? [Colors.green.shade600, Colors.teal.shade600]
              : [Colors.teal.shade600, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (resultSaved || _isMatchCompleted())
                ? Colors.green.withOpacity(0.3)
                : Colors.teal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team1['members'].join(', ') as String? ?? 'Team 1',
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
                  team2['members'].join(', ') as String? ?? 'Team 2',
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
                          (widget.isBestOf3 &&
                                  (resultSaved || _isMatchCompleted()))
                              ? setWins1.toString()
                              : score1.toString(),
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
                  const SizedBox(height: 8),
                  if (!resultSaved && !_isMatchCompleted())
                    Text(
                      'Set $currentSet',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'FINAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
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
                          (widget.isBestOf3 &&
                                  (resultSaved || _isMatchCompleted()))
                              ? setWins2.toString()
                              : score2.toString(),
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

          // Set Winner Info (only show if not completed and set is won)
          if (!resultSaved && !_isMatchCompleted() && _checkSetWinner() != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade400.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.shade400.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade300,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Set ${_checkSetWinner()!['winner'] == 1 ? 'Won by ${widget.match['team1']['members'].join(', ') as String}' : 'Won by ${widget.match['team2']['members'].join(', ') as String}'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreControl(
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

        _buildTeamScoreControl(
          team1['members'].join(', ') as String? ?? 'Team 1',
          score1,
          true,
          Colors.teal,
        ),

        const SizedBox(height: 16),

        _buildTeamScoreControl(
          team2['members'].join(', ') as String? ?? 'Team 2',
          score2,
          false,
          Colors.orange,
        ),

        const SizedBox(height: 16),

        // Next Set Button (for Best of 3)
        if (widget.isBestOf3 && _checkSetWinner() != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isMatchWon() || resultSaved) ? null : _nextSet,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
              label: Text(
                _isMatchWon() ? 'Match Complete' : 'Next Set',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: (_isMatchWon() || resultSaved)
                    ? Colors.grey.shade400
                    : Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamScoreControl(
    String teamName,
    int score,
    bool isTeam1,
    Color color,
  ) {
    final isLocked = _isMatchCompleted() || resultSaved; // ✅ Check resultSaved

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocked ? Colors.grey.shade300 : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLocked ? 0.03 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: isLocked ? null : () => _decrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLocked
                          ? [Colors.grey.shade200, Colors.grey.shade100]
                          : [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.remove_rounded,
                    color: isLocked ? Colors.grey.shade400 : color,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 20),

              Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLocked
                        ? [Colors.grey.shade200, Colors.grey.shade100]
                        : [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLocked
                        ? Colors.grey.shade300
                        : color.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    score.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isLocked ? Colors.grey.shade500 : color,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              GestureDetector(
                onTap: isLocked ? null : () => _incrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLocked
                          ? [Colors.grey.shade200, Colors.grey.shade100]
                          : [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: isLocked ? Colors.grey.shade400 : color,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetHistory() {
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
            'Set History',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          ...setScores.map((setScore) {
            final winner = setScore['winner'] as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set ${setScore['set']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${setScore['score1']} - ${setScore['score2']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Team $winner Won',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRulesInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏸 Badminton Scoring Rules',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(height: 8),
          _buildRuleItem('First to 21 points wins', Colors.amber.shade700),
          _buildRuleItem(
            'If 20-20: Deuce (need 2-point lead)',
            Colors.amber.shade700,
          ),
          _buildRuleItem('At Deuce: Score up to 30', Colors.amber.shade700),
          _buildRuleItem(
            '26-24, 27-25, 30-28 etc. all win',
            Colors.amber.shade700,
          ),
          if (widget.isBestOf3)
            _buildRuleItem(
              'Best of 3: Win 2 sets to win match',
              Colors.amber.shade700,
            ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final isMatchComplete =
        resultSaved ||
        _isMatchCompleted() ||
        (!widget.isBestOf3 && _checkSetWinner() != null) ||
        (widget.isBestOf3 && _isMatchWon());

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
                  'Close',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ✅ Save Result Button (disabled if already saved)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (isMatchComplete && !resultSaved)
                        ? [Colors.green.shade600, Colors.green.shade700]
                        : [Colors.grey.shade400, Colors.grey.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: (isMatchComplete && !resultSaved)
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (isMatchComplete && !resultSaved)
                        ? _saveMatchResult
                        : null,
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
                                Icon(
                                  resultSaved
                                      ? Icons.check_circle_rounded
                                      : Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  resultSaved ? 'Saved' : 'Save Result',
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
