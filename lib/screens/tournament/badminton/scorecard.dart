import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';

class ScorecardScreen extends StatefulWidget {
  final Match match;
  final Function(Match) onScoreUpdate;
  final bool isBestOf3;

  const ScorecardScreen({
    super.key,
    required this.match,
    required this.onScoreUpdate,
    this.isBestOf3 = false,
  });

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  late int score1;
  late int score2;
  late bool isBestOf3;
  late int matchesWon1;
  late int matchesWon2;
  late int currentSet;
  late List<Map<String, int>> setResults;
  bool _isShowingWinDialog = false;

  @override
  void initState() {
    super.initState();
    score1 = widget.match.score1;
    score2 = widget.match.score2;
    isBestOf3 = widget.isBestOf3;
    matchesWon1 = 0;
    matchesWon2 = 0;
    currentSet = 1;
    setResults = [];
  }

  bool get _isMatchCompleted => widget.match.status == 'Completed';

  bool get _hasScoreChanged =>
      score1 != widget.match.score1 || score2 != widget.match.score2;

  Future<bool> _onWillPop() async {
    if (_isMatchCompleted) {
      return true;
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
      score1: isBestOf3 ? matchesWon1 : score1,
      score2: isBestOf3 ? matchesWon2 : score2,
      setResults: setResults.isNotEmpty
          ? setResults
          : null, // ✅ PASS setResults
      winner: null,
      round: widget.match.round,
      roundName: widget.match.roundName,
      stage: widget.match.stage,
      parentTeam1Id: widget.match.parentTeam1Id,
      parentTeam2Id: widget.match.parentTeam2Id,
    );
    debugPrint('💾 Saving progress with ${setResults.length} sets');
    widget.onScoreUpdate(updatedMatch);
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

  /// Badminton Scoring Rules:
  /// - First to 21 points wins
  /// - If both reach 20-20 (deuce), must win by 2 points
  /// - Maximum 30 points (at 29-29, first to score wins)
  bool _checkIfSetWon(int t1Score, int t2Score) {
    if (t1Score >= 30 || t2Score >= 30) {
      return true;
    }

    if (t1Score >= 20 && t2Score >= 20) {
      if ((t1Score - t2Score).abs() >= 2) {
        return true;
      }
    }

    if ((t1Score >= 21 && t2Score < 20) || (t2Score >= 21 && t1Score < 20)) {
      return true;
    }

    return false;
  }

  void _checkMatchWin() {
    if (_checkIfSetWon(score1, score2) && !_isShowingWinDialog) {
      if (isBestOf3) {
        _handleBestOf3SetWin();
      } else {
        _isShowingWinDialog = true;
        _showMatchCompleteDialog();
      }
    }
  }

  void _handleBestOf3SetWin() {
    if (_isShowingWinDialog || !mounted) return;

    _isShowingWinDialog = true;

    String setWinnerName = score1 > score2
        ? widget.match.team1.name
        : widget.match.team2.name;

    // ✅ Store complete set result with both scores
    setResults.add({'team1': score1, 'team2': score2});
    debugPrint('📝 Set $currentSet Result: Team1: $score1 - Team2: $score2');

    // Update matches won
    if (score1 > score2) {
      matchesWon1++;
    } else {
      matchesWon2++;
    }

    debugPrint('🏆 Current Series: Team1: $matchesWon1 - Team2: $matchesWon2');

    // Check if series is complete (one team won 2 sets)
    bool seriesComplete = matchesWon1 == 2 || matchesWon2 == 2;

    if (seriesComplete) {
      _showMatchCompleteDialog();
      return;
    }

    // Series not complete, show "Next Set" dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flag,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Set Complete!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set Winner',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    setWinnerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Set $currentSet: $score1 - $score2',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Series: ${widget.match.team1.name}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$matchesWon1 - $matchesWon2',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        Text(
                          widget.match.team2.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _isShowingWinDialog = false;
                        _resetForNextSet();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Next Set',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _isShowingWinDialog = false;
      }
    });
  }

  void _resetForNextSet() {
    setState(() {
      score1 = 0;
      score2 = 0;
      currentSet++;
      debugPrint('📝 Reset for Set $currentSet');
    });
  }

  String _buildSetResultsDisplay() {
    List<String> results = [];
    for (int i = 0; i < setResults.length; i++) {
      final result = setResults[i];
      results.add('Set ${i + 1}: ${result['team1']}-${result['team2']}');
    }
    return results.join('\n');
  }

  void _showMatchCompleteDialog() {
    _isShowingWinDialog = true;

    String winnerName = '';
    String winnerId = '';
    bool isBestOf3Complete =
        isBestOf3 && (matchesWon1 == 2 || matchesWon2 == 2);

    if (isBestOf3Complete) {
      // Best of 3 winner
      winnerName = matchesWon1 > matchesWon2
          ? widget.match.team1.name
          : widget.match.team2.name;
      winnerId = matchesWon1 > matchesWon2
          ? widget.match.team1.id
          : widget.match.team2.id;
    } else {
      // Single match winner
      winnerName = score1 > score2
          ? widget.match.team1.name
          : widget.match.team2.name;
      winnerId = score1 > score2
          ? widget.match.team1.id
          : widget.match.team2.id;
    }

    debugPrint(
      '🏆 Match Complete: $winnerName wins (Best of 3: $isBestOf3Complete)',
    );
    debugPrint('📊 Set Results: $setResults');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBestOf3Complete
                        ? 'Best of 3 Complete!'
                        : 'Match Complete!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Winner',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    winnerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (isBestOf3Complete) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          if (isBestOf3Complete) ...[
                            Text(
                              'Series: $matchesWon1 - $matchesWon2',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            _buildSetResultsDisplay(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$score1 - $score2',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!isBestOf3Complete)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _isShowingWinDialog = false;
                            },
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
                              'Cancel',
                              style: TextStyle(
                                fontSize: 13,
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
                                setResults: setResults.isNotEmpty
                                    ? setResults
                                    : null, // ✅ PASS setResults
                                winner: winnerId,
                                round: widget.match.round,
                                roundName: widget.match.roundName,
                                stage: widget.match.stage,
                                parentTeam1Id: widget.match.parentTeam1Id,
                                parentTeam2Id: widget.match.parentTeam2Id,
                              );

                              debugPrint(
                                '💾 Saving single match result with ${setResults.length} sets',
                              );
                              widget.onScoreUpdate(updatedMatch);

                              Navigator.of(dialogContext).pop();
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save Result',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final updatedMatch = Match(
                            id: widget.match.id,
                            team1: widget.match.team1,
                            team2: widget.match.team2,
                            date: widget.match.date,
                            time: widget.match.time,
                            status: 'Completed',
                            score1: matchesWon1,
                            score2: matchesWon2,
                            setResults: setResults.isNotEmpty
                                ? setResults
                                : null, // ✅ PASS setResults
                            winner: winnerId,
                            round: widget.match.round,
                            roundName: widget.match.roundName,
                            stage: widget.match.stage,
                            parentTeam1Id: widget.match.parentTeam1Id,
                            parentTeam2Id: widget.match.parentTeam2Id,
                          );

                          debugPrint(
                            '💾 Saving best of 3 match with ${setResults.length} sets and winner: $winnerId',
                          );
                          widget.onScoreUpdate(updatedMatch);

                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Result',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        _isShowingWinDialog = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _onWillPop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black45),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy • h:mm a').format(widget.match.date),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            if (_isMatchCompleted)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
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
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    if (isBestOf3)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Best of 3 Series',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                Text(
                                  'Sets: $matchesWon1 - $matchesWon2 (Set $currentSet)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    if (isBestOf3) const SizedBox(height: 12),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$score1 : $score2',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          if (isBestOf3) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Set $currentSet',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).toInt()),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'This match is locked. Score cannot be changed.',
                                style: TextStyle(
                                  fontSize: 11,
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
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'First to 21 • At 20-20 win by 2 • Max 30',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLeading ? color : Colors.grey.shade200,
          width: isLeading ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLeading
                ? color.withAlpha((255 * 0.15).toInt())
                : Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: isLeading ? 15 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  players.length == 1 ? Icons.person : Icons.people,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (players.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        players.join(' & '),
                        style: TextStyle(
                          fontSize: 10,
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
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Colors.green.shade700,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Leading',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
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
                behavior: HitTestBehavior.opaque,
                onTap: isDisabled ? null : onDecrement,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? Colors.grey.shade300
                          : color.withAlpha((255 * 0.3).toInt()),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.transparent,
                    boxShadow: isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: color.withAlpha((255 * 0.1).toInt()),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.remove,
                    color: isDisabled ? Colors.grey.shade400 : color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDisabled
                          ? Colors.grey.shade400.withAlpha((255 * 0.9).toInt())
                          : color.withAlpha((255 * 0.9).toInt()),
                      isDisabled ? Colors.grey.shade400 : color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDisabled
                          ? Colors.grey.shade400.withAlpha((255 * 0.3).toInt())
                          : color.withAlpha((255 * 0.3).toInt()),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    score.toString(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isDisabled ? null : onIncrement,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey.shade400 : color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: color.withAlpha((255 * 0.3).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
