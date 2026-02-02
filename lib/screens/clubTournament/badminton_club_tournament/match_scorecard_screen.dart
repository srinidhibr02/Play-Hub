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
  late bool resultSaved;
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
    resultSaved =
        (widget.match['status'] as String? ?? 'Scheduled') == 'Completed';
  }

  /// ✅ Check if set is completed
  bool _isSetCompleted() {
    if (score1 == 30 || score2 == 30) {
      return true;
    }

    if ((score1 == 21 && score2 < 20) || (score2 == 21 && score1 < 20)) {
      return true;
    }

    if (score1 >= 20 && score2 >= 20) {
      if ((score1 - score2).abs() == 2) {
        return true;
      }
    }

    return false;
  }

  /// ✅ Check if score is at deuce
  bool _isDeuce() {
    return score1 >= 20 && score2 >= 20 && score1 == score2;
  }

  /// ✅ Increment score for team
  void _incrementScore(bool isTeam1) {
    if (resultSaved || _isSetCompleted()) {
      _showMatchCompletedDialog();
      return;
    }

    setState(() {
      if (isTeam1) {
        if (score1 < 30) {
          score1++;
        }
      } else {
        if (score2 < 30) {
          score2++;
        }
      }
    });
  }

  /// ✅ Decrement score for team
  void _decrementScore(bool isTeam1) {
    if (resultSaved) {
      _showMatchCompletedDialog();
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

  /// ✅ Show match completed dialog
  void _showMatchCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Header with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Title
                  Text(
                    'Match Completed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ Description
                  Text(
                    'This match has already been completed and locked. The scorecard cannot be edited unless you choose to edit it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ✅ Information box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_rounded,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Editing will unlock the scorecard for modifications.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ✅ Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
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

                      // Edit Button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade600,
                                Colors.orange.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _unlockScorecard();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Edit Score',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ✅ Unlock scorecard
  Future<void> _unlockScorecard() async {
    try {
      setState(() => isLoading = true);

      final matchId = widget.match['id'] as String?;
      if (matchId == null) {
        throw Exception('Match ID not found');
      }

      await _service
          .updateMatch(widget.tournamentId, widget.categoryId, matchId, {
            'resultSaved': false,
            'isLocked': false,
            'unlockedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() {
        resultSaved = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Scorecard unlocked. You can now edit the score.'),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
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

  int _calculateNetResult(int score1, int score2) {
    return score1 - score2;
  }

  String? _getWinner() {
    if (!_isSetCompleted()) return null;
    if (score1 > score2) return widget.match['team1']['id'] as String?;
    if (score2 > score1) return widget.match['team2']['id'] as String?;
    return null;
  }

  String? _getSetWinnerMessage() {
    if (!_isSetCompleted()) return null;

    if (score1 > score2) {
      final teamName =
          widget.match['team1']['members'].join(', ') as String? ?? 'Team 1';
      return '$teamName wins';
    } else if (score2 > score1) {
      final teamName =
          widget.match['team2']['members'].join(', ') as String? ?? 'Team 2';
      return '$teamName wins';
    }
    return null;
  }

  Future<void> _saveMatchResult() async {
    try {
      setState(() => isLoading = true);

      final team1Id = widget.match['team1']['id'] as String?;
      final team2Id = widget.match['team2']['id'] as String?;
      final winner = _getWinner();

      if (team1Id == null || team2Id == null) {
        throw Exception('Team IDs not found');
      }

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

      final netResult1 = _calculateNetResult(score1, score2);
      final netResult2 = _calculateNetResult(score2, score1);

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

      final matchId = widget.match['id'] as String?;
      if (matchId == null) {
        throw Exception('Match ID not found');
      }

      await _service
          .updateMatch(widget.tournamentId, widget.categoryId, matchId, {
            'status': 'Completed',
            'score1': score1,
            'score2': score2,
            'winner': winner,
            'resultSaved': true,
            'isLocked': true,
            'completedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;

      setState(() {
        resultSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Match result saved and locked successfully!'),
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

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
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
    final team1 = widget.match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = widget.match['team2'] as Map<String, dynamic>? ?? {};
    final stage = widget.match['stage'] as String? ?? 'League';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(team1, team2),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTournamentInfo(stage),
              const SizedBox(height: 20),
              _buildScoreBoard(team1, team2),
              _buildTeamsSection(team1, team2),
              const SizedBox(height: 24),
              _buildMatchInfo(stage),
              const SizedBox(height: 24),
              if (!resultSaved) _buildBadmintonRulesInfo(),
              if (!resultSaved) const SizedBox(height: 24),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  PreferredSizeWidget _buildAppBar(
    Map<String, dynamic> team1,
    Map<String, dynamic> team2,
  ) {
    final team1Name = team1['name'] as String? ?? 'Team 1';
    final team2Name = team2['name'] as String? ?? 'Team 2';

    return AppBar(
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
          Row(
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
              if (resultSaved) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Text(
            '$team1Name vs $team2Name',
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
    );
  }

  Widget _buildBadmintonRulesInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Badminton Scoring Rules',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRuleItem('First to 21 wins the set', Colors.purple),
          _buildRuleItem(
            'At 20-20 (deuce), difference of 2 wins',
            Colors.purple,
          ),
          _buildRuleItem('Maximum 30 points per set', Colors.purple),
          _buildRuleItem(
            'Set is locked once completed',
            Colors.purple,
            isImportant: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule, Color color, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isImportant ? Icons.lock_rounded : Icons.check_rounded,
            size: 14,
            color: isImportant ? Colors.red : color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isImportant ? FontWeight.w700 : FontWeight.w600,
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
          Column(
            children: [
              Text(
                'Set',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentSet.toString(),
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
                'Format',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Badminton',
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
    final setCompleted = _isSetCompleted();
    final isDeuce = _isDeuce();
    final team1Name = team1['members'].join(', ') as String? ?? 'Team 1';
    final team2Name = team2['members'].join(', ') as String? ?? 'Team 2';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team1Name,
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
                  team2Name,
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
                  if (isDeuce)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEUCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
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
            child: Column(
              children: [
                Row(
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
                if (setCompleted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSetWinnerMessage() ?? 'Set Completed',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (resultSaved)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildScoreControl(
          team1['members'].join(', ') as String? ?? 'Team 1',
          score1,
          true,
          Colors.teal,
        ),
        const SizedBox(height: 16),
        _buildScoreControl(
          team2['members'].join(', ') as String? ?? 'Team 2',
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
        border: Border.all(
          color: resultSaved ? Colors.grey.shade300 : Colors.grey.shade200,
          width: 1.5,
        ),
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
              color: resultSaved ? Colors.grey.shade500 : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ MINUS BUTTON - DISABLED STATE
              GestureDetector(
                onTap: resultSaved ? null : () => _decrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: resultSaved
                          ? [Colors.grey.shade200, Colors.grey.shade100]
                          : [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: resultSaved
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.remove_rounded,
                    color: resultSaved ? Colors.grey.shade400 : color,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // SCORE DISPLAY
              Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: resultSaved
                        ? [Colors.grey.shade100, Colors.grey.shade50]
                        : [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: resultSaved
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
                      color: resultSaved ? Colors.grey.shade400 : color,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // ✅ PLUS BUTTON - DISABLED STATE
              GestureDetector(
                onTap: resultSaved ? null : () => _incrementScore(isTeam1),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: resultSaved
                          ? [Colors.grey.shade200, Colors.grey.shade100]
                          : [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: resultSaved
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: resultSaved ? Colors.grey.shade400 : color,
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
          const SizedBox(height: 8),
          _buildInfoRow(
            'Status',
            resultSaved ? 'Locked' : 'Editing',
            resultSaved ? Colors.amber : Colors.blue,
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
                    colors: resultSaved
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : [Colors.green.shade600, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (resultSaved ? Colors.grey : Colors.green)
                          .withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (isLoading || resultSaved) ? null : _saveMatchResult,
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
                                      ? Icons.lock_rounded
                                      : Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  resultSaved ? 'Locked' : 'Save Result',
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
