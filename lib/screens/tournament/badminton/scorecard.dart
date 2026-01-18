import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';

class ScorecardScreen extends StatefulWidget {
  final Match match;
  final Function(Match) onScoreUpdate;

  const ScorecardScreen({
    super.key,
    required this.match,
    required this.onScoreUpdate,
  });

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  late int score1;
  late int score2;

  @override
  void initState() {
    super.initState();
    score1 = widget.match.score1;
    score2 = widget.match.score2;
  }

  bool get _isMatchCompleted => widget.match.status == 'Completed';

  bool get _hasScoreChanged =>
      score1 != widget.match.score1 || score2 != widget.match.score2;

  Future<bool> _onWillPop() async {
    if (_isMatchCompleted) {
      Navigator.pop(context);
      return false;
    }

    if (_hasScoreChanged) {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save, size: 48, color: Colors.orange.shade600),
                    const SizedBox(height: 16),
                    const Text(
                      'Save Match Progress?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You have unsaved changes. Do you want to save the current score?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Discard',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _saveMatchProgress();
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
          ) ??
          false;
    }

    return true;
  }

  void _saveMatchProgress() {
    final updatedMatch = Match(
      id: widget.match.id,
      team1: widget.match.team1,
      team2: widget.match.team2,
      date: widget.match.date,
      time: widget.match.time,
      status: 'Ongoing',
      score1: score1,
      score2: score2,
      winner: null,
      parentTeam1Id: widget.match.parentTeam1Id,
      parentTeam2Id: widget.match.parentTeam2Id,
    );
    if (widget.onScoreUpdate != null) {
      widget.onScoreUpdate!(updatedMatch);
    }
  }

  void _updateScore(bool isTeam1, bool increment) {
    if (_isMatchCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cannot update score. Match is already completed.',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (isTeam1) {
        if (increment) {
          score1++;
        } else if (score1 > 0) {
          score1--;
        }
      } else {
        if (increment) {
          score2++;
        } else if (score2 > 0) {
          score2--;
        }
      }
      _checkMatchWin();
    });
  }

  void _checkMatchWin() {
    // Badminton rules: First to 21, win by 2, max 30
    if (score1 >= 21 || score2 >= 21) {
      int diff = (score1 - score2).abs();
      int maxScore = score1 > score2 ? score1 : score2;

      bool hasWinner = false;
      if (maxScore >= 30) {
        hasWinner = true;
      } else if (diff >= 2) {
        hasWinner = true;
      }

      if (hasWinner) {
        _showMatchCompleteDialog();
      }
    }
  }

  bool _isShowingWinDialog = false; // ✅ Add this class field

  void _showMatchCompleteDialog() {
    // ✅ Prevent multiple dialogs & state conflicts
    if (_isShowingWinDialog || !mounted) return;

    _isShowingWinDialog = true;

    String winnerName = score1 > score2
        ? widget.match.team1.name
        : widget.match.team2.name;

    String winnerId = score1 > score2
        ? widget.match.team1.id
        : widget.match.team2.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        // ✅ Prevent back button during dialog
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.amber.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Match Complete!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Text(
                  'Winner',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),

                Text(
                  winnerName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Final Score
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$score1 - $score2',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (mounted) {
                            setState(() => _isShowingWinDialog = false);
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final updatedMatch = Match(
                            id: widget.match.id,
                            team1: widget.match.team1,
                            team2: widget.match.team2,
                            date: widget.match.date,
                            time: widget.match.time,
                            status: 'Completed',
                            score1: score1,
                            score2: score2,
                            winner: winnerId,
                            parentTeam1Id: widget.match.parentTeam1Id,
                            parentTeam2Id: widget.match.parentTeam2Id,
                          );

                          if (widget.onScoreUpdate != null && mounted) {
                            widget.onScoreUpdate!(updatedMatch);
                          }

                          // ✅ Sequential navigation - no conflicts
                          Navigator.of(dialogContext).pop(); // Close dialog
                          if (mounted) {
                            Navigator.of(context).pop(); // Close scorecard
                            Navigator.of(context).pop();
                            setState(() => _isShowingWinDialog = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Result',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
      ),
    ).then((_) {
      // ✅ Cleanup when dialog closes
      if (mounted) {
        setState(() => _isShowingWinDialog = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black45),
          onPressed: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match ${widget.match.id}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy • h:mm a').format(widget.match.date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          if (_isMatchCompleted)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                const Spacer(),

                // Team 1
                _buildTeamSection(
                  name: widget.match.team1.name,
                  players: widget.match.team1.players,
                  score: score1,
                  color: Colors.orange.shade600,
                  isLeading: score1 > score2,
                  isDisabled: _isMatchCompleted,
                  onIncrement: () => _updateScore(true, true),
                  onDecrement: () => _updateScore(true, false),
                ),

                const SizedBox(height: 40),

                // Score Divider
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$score1 : $score2',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Team 2
                _buildTeamSection(
                  name: widget.match.team2.name,
                  players: widget.match.team2.players,
                  score: score2,
                  color: Colors.blue.shade600,
                  isLeading: score2 > score1,
                  isDisabled: _isMatchCompleted,
                  onIncrement: () => _updateScore(false, true),
                  onDecrement: () => _updateScore(false, false),
                ),

                const Spacer(),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_isMatchCompleted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This match is locked. Score cannot be changed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'First to 21 • Win by 2 • Max 30',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection({
    required String name,
    required List<String> players,
    required int score,
    required Color color,
    required bool isLeading,
    required bool isDisabled,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLeading ? color : Colors.grey.shade200,
          width: isLeading ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLeading
                ? color.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: isLeading ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Team Name & Players
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  players.length == 1 ? Icons.person : Icons.people,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (players.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        players.join(' & '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isLeading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Colors.green.shade700,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Leading',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // ✅ FIXED Score Controls - GestureDetector + HitTestBehavior.opaque
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrement Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isDisabled ? null : onDecrement,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.transparent,
                    boxShadow: isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.remove,
                    color: isDisabled ? Colors.grey.shade400 : color,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // Score Display
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDisabled
                          ? Colors.grey.shade400.withOpacity(0.9)
                          : color.withOpacity(0.9),
                      isDisabled ? Colors.grey.shade400 : color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDisabled
                          ? Colors.grey.shade400.withOpacity(0.3)
                          : color.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    score.toString(),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // Increment Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isDisabled ? null : onIncrement,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey.shade400 : color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
