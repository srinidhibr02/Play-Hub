import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';

class ScorecardScreen extends StatefulWidget {
  final Match match;
  final String teamType;
  final Function(Match) onScoreUpdate;

  const ScorecardScreen({
    super.key,
    required this.match,
    required this.teamType,
    required this.onScoreUpdate,
  });

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  late int score1;
  late int score2;
  late String status;

  @override
  void initState() {
    super.initState();
    score1 = widget.match.score1;
    score2 = widget.match.score2;
    status = widget.match.status;
  }

  void _updateScore(bool isTeam1, bool increment) {
    setState(() {
      if (isTeam1) {
        score1 = increment ? score1 + 1 : (score1 > 0 ? score1 - 1 : 0);
      } else {
        score2 = increment ? score2 + 1 : (score2 > 0 ? score2 - 1 : 0);
      }
    });
  }

  void _completeMatch() {
    final winner = score1 > score2
        ? widget.match.team1.id
        : (score2 > score1 ? widget.match.team2.id : null);

    if (winner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scores must be different to complete'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final updatedMatch = widget.match.copyWith(
      score1: score1,
      score2: score2,
      status: 'Completed',
      winner: winner,
    );
    widget.onScoreUpdate(updatedMatch);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Match completed! Winner: ${score1 > score2 ? widget.match.team1.name : widget.match.team2.name}',
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        elevation: 0,
        title: const Text(
          'Scorecard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            // <--- Fix: Added this
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade600, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade300.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Match ${widget.match.id}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${DateFormat('MMM d').format(widget.match.date)}, ${widget.match.time}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildScoreCard(
                      name: widget.match.team1.name,
                      players: widget.match.team1.players,
                      score: score1,
                      onIncrement: () => _updateScore(true, true),
                      onDecrement: () => _updateScore(true, false),
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 20),
                    _buildScoreCard(
                      name: widget.match.team2.name,
                      players: widget.match.team2.players,
                      score: score2,
                      onIncrement: () => _updateScore(false, true),
                      onDecrement: () => _updateScore(false, false),
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _completeMatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Complete Match',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard({
    required String name,
    required List<String> players,
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          if (players.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              players.join(' • '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                score.toString(),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove, size: 24),
                  color: color,
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 30),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add, size: 24),
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
