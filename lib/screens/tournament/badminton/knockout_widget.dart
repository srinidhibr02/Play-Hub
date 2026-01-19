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
  final VoidCallback onMatchTap;
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Match>>(
          stream: _badmintonService.getAllMatchesStream(
            widget.userEmail,
            widget.tournamentId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.orange.shade600),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No matches found'));
            }

            final allMatches = snapshot.data!;
            final knockoutMatches = allMatches
                .where((m) => m.stage == 'Knockout')
                .toList();

            if (knockoutMatches.isEmpty) {
              return const Center(child: Text('No knockout matches found'));
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

            // Check if tournament is complete
            final isTournamentComplete =
                allCurrentRoundCompleted && advancingTeamsCount == 1;

            final sortedRounds = matchesByRound.keys.toList()..sort();

            return Column(
              children: [
                // Show button to generate next round
                if (canGenerateNextRound && !isTournamentComplete)
                  _buildGenerateNextRoundCard(
                    context,
                    knockoutMatches,
                    latestRound,
                    advancingTeamsCount,
                  ),

                // Show tournament complete message
                if (isTournamentComplete && currentRoundMatches.isNotEmpty)
                  _buildTournamentCompleteCard(currentRoundMatches),

                // Display all rounds
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final round in sortedRounds)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                matchesByRound[round]?[0].roundName ??
                                    'Round $round',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ),
                            for (final match in matchesByRound[round] ?? [])
                              _buildKnockoutMatchCard(match),
                            const SizedBox(height: 24),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (_isGenerating)
          Container(
            color: Colors.black.withOpacity(0.45),
            child: Center(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generating next round',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please wait...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sports_score,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Round $currentRound Complete! ✨',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Text(
                    '$advancingTeamsCount teams advancing',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue Knockout',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Winners will advance to the next round. The tournament will continue until a champion is crowned!',
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
            child: ElevatedButton.icon(
              onPressed: () =>
                  _generateNextKnockoutRound(context, knockoutMatches),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Generate Next Round'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCompleteCard(List<Match> currentRoundMatches) {
    final winner = _getWinner(currentRoundMatches);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 48, color: Colors.amber.shade600),
          const SizedBox(height: 16),
          Text(
            '🏆 TOURNAMENT COMPLETE!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Champion',
            style: TextStyle(fontSize: 14, color: Colors.amber.shade600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300, width: 2),
            ),
            child: Text(
              winner?.name ?? 'Unknown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),
          ),
        ],
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
      onTap: () => widget.onMatchTap(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.amberAccent.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    match.id,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(match.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                  const SizedBox(height: 16),
                  _buildTeamScoreRow(
                    teamName: match.team2.name,
                    players: match.team2.players,
                    score: score2,
                    isWinner: team2Won && isCompleted,
                    isLoser: team1Won && isCompleted,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(match.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        match.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildByeMatchCard(Match match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade400, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_travel, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'BYE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Advanced',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        match.team1.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gets a free pass to the next round',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  fontSize: 16,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (isWinner)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: Colors.green.shade700,
            ),
          )
        else if (isLoser)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.red.shade700,
            ),
          ),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Round ${currentRoundNumber + 1} generated!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
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
          id: 'M_BYE_R${roundNumber}_${DateTime.now().millisecondsSinceEpoch}',
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
    if (teamCount == 4) return 'Semi-Final';
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Ongoing':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
