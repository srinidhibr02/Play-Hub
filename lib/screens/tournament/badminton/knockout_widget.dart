import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';

class KnockoutMatchesWidget extends StatefulWidget {
  final String tournamentId;
  final String userEmail;
  final int? matchDuration;
  final int? breakDuration;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final Function(Match) onMatchTap;
  final Function(Match) onScoreUpdate;

  const KnockoutMatchesWidget({
    super.key,
    required this.tournamentId,
    required this.userEmail,
    this.matchDuration,
    this.breakDuration,
    this.startDate,
    this.startTime,
    required this.onMatchTap,
    required this.onScoreUpdate,
  });

  @override
  State<KnockoutMatchesWidget> createState() => _KnockoutMatchesWidgetState();
}

class _KnockoutMatchesWidgetState extends State<KnockoutMatchesWidget> {
  final _badmintonService = TournamentFirestoreService();
  bool _isGenerating = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Match>> _getAllMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    final matchesStream = _firestore
        .collection('friendlyTournaments')
        .doc(tournamentId)
        .collection('matches')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Match.fromMap(doc.data())).toList();
        });

    // Listen to matches count and update tournament stats
    matchesStream.listen((matches) async {
      await _updateTournamentStats(tournamentId, matches.length);
    });

    return matchesStream;
  }

  Future<void> _updateTournamentStats(
    String tournamentId,
    int totalMatches,
  ) async {
    try {
      final tournamentRef = _firestore
          .collection('friendlyTournaments')
          .doc(tournamentId);

      // ✅ Update nested stats.totalMatches field atomically
      await tournamentRef.update({'stats.totalMatches': totalMatches});

      debugPrint(
        '✅ Updated totalMatches: $totalMatches for tournament: $tournamentId',
      );
    } catch (e) {
      debugPrint('❌ Error updating stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Match>>(
          stream: _getAllMatchesStream(widget.userEmail, widget.tournamentId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading matches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.orange.shade600,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading matches...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sports_tennis,
                        size: 64,
                        color: Colors.blue.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No matches yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allMatches = snapshot.data!;
            final knockoutMatches = allMatches
                .where((m) => m.stage == 'Knockout')
                .toList();

            if (knockoutMatches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Colors.amber.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No knockout matches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group matches by round
            final matchesByRound = <int, List<Match>>{};
            for (final match in knockoutMatches) {
              final round = match.round ?? 1;
              matchesByRound.putIfAbsent(round, () => []);
              matchesByRound[round]!.add(match);
            }

            // Get current round info
            final latestRound = _getLatestRoundNumber(knockoutMatches);
            final currentRoundMatches = matchesByRound[latestRound] ?? [];
            final allCurrentRoundCompleted =
                currentRoundMatches.isNotEmpty &&
                currentRoundMatches.every((m) => m.status == 'Completed');

            final advancingTeamsCount = _getAdvancingTeamCount(
              currentRoundMatches,
            );

            final canGenerateNextRound =
                allCurrentRoundCompleted &&
                currentRoundMatches.isNotEmpty &&
                advancingTeamsCount >= 2 &&
                advancingTeamsCount > 1;

            final isTournamentComplete =
                allCurrentRoundCompleted && advancingTeamsCount == 1;

            final sortedRounds = matchesByRound.keys.toList()..sort();

            if (isTournamentComplete) {
              _badmintonService.completeTournament(widget.tournamentId);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canGenerateNextRound && !isTournamentComplete)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildGenerateNextRoundCard(
                      context,
                      knockoutMatches,
                      latestRound,
                      advancingTeamsCount,
                    ),
                  ),
                if (isTournamentComplete && currentRoundMatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTournamentCompleteCard(currentRoundMatches),
                  ),
                for (final round in sortedRounds)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchesByRound[round]?[0].roundName ??
                                  'Round $round',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final match in matchesByRound[round] ?? [])
                        _buildKnockoutMatchCard(match),
                      const SizedBox(height: 8),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
        if (_isGenerating)
          Container(
            color: Colors.black.withAlpha((255 * 0.5).toInt()),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.15).toInt()),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Generating Next Round',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we process the winners...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenerateNextRoundCard(
    BuildContext context,
    List<Match> knockoutMatches,
    int currentRound,
    int advancingTeamsCount,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withAlpha((255 * 0.5).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade600.withAlpha(
                          (255 * 0.3).toInt(),
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_score,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Round $currentRound Complete! ✨',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$advancingTeamsCount teams advancing to next round',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.8).toInt()),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Knockout Tournament',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Winners will automatically advance. The tournament continues until we crown a champion!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _generateNextKnockoutRound(context, knockoutMatches),
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text(
                  'Generate Next Round',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: Colors.blue.shade600.withAlpha(
                    (255 * 0.5).toInt(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentCompleteCard(List<Match> currentRoundMatches) {
    final winner = _getWinner(currentRoundMatches);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade200.withAlpha((255 * 0.6).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade600.withAlpha((255 * 0.4).toInt()),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 25,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '🏆 Tournament Champion! 🏆',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.amber.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.9).toInt()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    winner?.name ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  if (winner!.players.length >= 2) ...[
                    Text(
                      '${winner.players[0]} & ${winner.players[1]}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnockoutMatchCard(Match match) {
    final isBye = match.isBye ?? false;

    if (isBye) {
      return _buildByeMatchCard(match);
    }

    final isCompleted = match.status == 'Completed';
    final score1 = match.score1;
    final score2 = match.score2;
    final team1Won = score1 > score2;
    final team2Won = score2 > score1;

    return GestureDetector(
      onTap: () {
        debugPrint('Match tapped: ${match.id}');
        widget.onMatchTap(match);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.06).toInt()),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onMatchTap(match),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCompleted
                          ? [Colors.green.shade600, Colors.green.shade400]
                          : [Colors.orange.shade600, Colors.orange.shade400],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.roundName ?? 'Match',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              match.id,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((255 * 0.3).toInt()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          match.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTeamScoreRow(
                        teamName: match.team1.name,
                        players: match.team1.players,
                        score: score1,
                        isWinner: team1Won && isCompleted,
                        isLoser: team2Won && isCompleted,
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 14),
                      _buildTeamScoreRow(
                        teamName: match.team2.name,
                        players: match.team2.players,
                        score: score2,
                        isWinner: team2Won && isCompleted,
                        isLoser: team1Won && isCompleted,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM dd, yyyy').format(match.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              match.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildByeMatchCard(Match match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_travel, size: 13, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'BYE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 13, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Advanced',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.9).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      match.team1.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '✨ Free pass to next round',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreRow({
    required String teamName,
    required List<String> players,
    required int score,
    required bool isWinner,
    required bool isLoser,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? Colors.green.shade700 : Colors.black87,
                  decoration: isLoser
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              if (players.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  players.join(' & '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isWinner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green.shade700,
            ),
          )
        else if (isLoser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: Colors.red.shade700,
            ),
          ),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _generateNextKnockoutRound(
    BuildContext context,
    List<Match> knockoutMatches,
  ) async {
    setState(() => _isGenerating = true);

    try {
      final currentRoundNumber = _getLatestRoundNumber(knockoutMatches);
      final currentRoundMatches = knockoutMatches
          .where((m) => m.round == currentRoundNumber)
          .toList();

      final nextRoundTeams = <Team>[];
      for (final match in currentRoundMatches) {
        if (match.isBye ?? false) {
          nextRoundTeams.add(match.team1);
        } else {
          final winner = match.score1 > match.score2
              ? match.team1
              : match.team2;
          nextRoundTeams.add(winner);
        }
      }

      if (nextRoundTeams.length < 2) {
        setState(() => _isGenerating = false);
        return;
      }

      final teamsThatReceivedByeBefore = <String>{};
      for (final match in knockoutMatches) {
        if (match.isBye ?? false) {
          teamsThatReceivedByeBefore.add(match.team1.id);
        }
      }

      final nextRoundMatches = _generateKnockoutRoundMatches(
        nextRoundTeams,
        teamsThatReceivedByeBefore,
        currentRoundNumber + 1,
      );

      await _badmintonService.addPlayoffMatches(
        widget.userEmail,
        widget.tournamentId,
        nextRoundMatches,
      );

      setState(() => _isGenerating = false);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Round ${currentRoundNumber + 1} generated!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  List<Match> _generateKnockoutRoundMatches(
    List<Team> advancingTeams,
    Set<String> teamsWithByeBefore,
    int roundNumber,
  ) {
    final matches = <Match>[];
    var availableTeams = List<Team>.from(advancingTeams)..shuffle();
    var currentTime = widget.startDate ?? DateTime.now();
    currentTime = currentTime.add(Duration(days: roundNumber - 1));

    final needsBye = availableTeams.length.isOdd;

    if (needsBye) {
      final candidatesForBye = availableTeams
          .where((team) => !teamsWithByeBefore.contains(team.id))
          .toList();

      final byeTeam = candidatesForBye.isNotEmpty
          ? candidatesForBye.first
          : availableTeams.first;

      availableTeams.remove(byeTeam);

      matches.add(
        Match(
          id: 'M1_BYE_R$roundNumber',
          team1: byeTeam,
          team2: byeTeam,
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Completed',
          score1: 1,
          score2: 0,
          winner: byeTeam.id,
          round: roundNumber,
          roundName: _getRoundNameFromTeamCount(availableTeams.length + 1),
          stage: 'Knockout',
          isBye: true,
        ),
      );

      teamsWithByeBefore.add(byeTeam.id);
    }

    for (int i = 0; i < availableTeams.length; i += 2) {
      if (i + 1 < availableTeams.length) {
        final team1 = availableTeams[i];
        final team2 = availableTeams[i + 1];

        matches.add(
          Match(
            id: 'M_R${roundNumber}_M${(i ~/ 2) + 1}',
            team1: team1,
            team2: team2,
            date: currentTime,
            time: DateFormat('h:mm a').format(currentTime),
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: roundNumber,
            roundName: _getRoundNameFromTeamCount(
              availableTeams.length + (needsBye ? 1 : 0),
            ),
            stage: 'Knockout',
          ),
        );

        currentTime = currentTime.add(
          Duration(
            minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
          ),
        );
      }
    }

    return matches;
  }

  String _getRoundNameFromTeamCount(int teamCount) {
    if (teamCount == 2) return 'Final';
    if (teamCount <= 4) return 'Semi-Final';
    if (teamCount <= 8) return 'Quarter-Final';
    if (teamCount <= 16) return 'Round of 16';
    if (teamCount <= 32) return 'Round of 32';
    if (teamCount <= 64) return 'Round of 64';
    return 'Round of $teamCount';
  }

  int _getLatestRoundNumber(List<Match> knockoutMatches) {
    if (knockoutMatches.isEmpty) return 0;
    return knockoutMatches.fold<int>(
      0,
      (max, match) => (match.round ?? 0) > max ? (match.round ?? 0) : max,
    );
  }

  int _getAdvancingTeamCount(List<Match> currentRoundMatches) {
    final advancingTeams = <String>{};
    for (final match in currentRoundMatches) {
      if (match.isBye ?? false) {
        advancingTeams.add(match.team1.id);
      } else {
        final winner = match.score1 > match.score2
            ? match.team1.id
            : match.team2.id;
        advancingTeams.add(winner);
      }
    }
    return advancingTeams.length;
  }

  Team? _getWinner(List<Match> currentRoundMatches) {
    if (currentRoundMatches.isEmpty) return null;
    final match = currentRoundMatches.first;
    if (match.isBye ?? false) {
      return match.team1;
    }
    return match.score1 > match.score2 ? match.team1 : match.team2;
  }
}
