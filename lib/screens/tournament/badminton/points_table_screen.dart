import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_service.dart';

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

class _StandingsTabState extends State<StandingsTab> {
  final TournamentFirestoreService _badmintonFirestoreService =
      TournamentFirestoreService();
  final AuthService _authService = AuthService();
  late String _tournamentId;
  bool _isGeneratingNextRound = false;

  @override
  void initState() {
    super.initState();
    _tournamentId = widget.tournamentId ?? '';
    if (_tournamentId.isEmpty) {
      debugPrint('⚠️ Warning: Tournament ID is empty!');
    }
  }

  Widget _buildTeamRow(TeamStats team, int index) {
    final isTopRanked = index == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isTopRanked ? Colors.orange.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isTopRanked ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (team.players.isNotEmpty && team.players.length > 1)
                  Text(
                    team.players.join(', '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              team.matchesPlayed.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              team.won.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade600,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              team.points.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime);

  Future<void> _generateRoundRobinKnockouts(List<TeamStats> topTeams) async {
    if (_tournamentId.isEmpty) {
      _showErrorSnackBar('Tournament ID is missing');
      return;
    }

    setState(() => _isGeneratingNextRound = true);

    try {
      if (topTeams.length < 2) {
        _showErrorSnackBar('Not enough teams to generate knockouts');
        setState(() => _isGeneratingNextRound = false);
        return;
      }

      DateTime lastMatchTime = DateTime.now();
      List<Match> existingMatches = await _badmintonFirestoreService
          .getMatches(_authService.currentUserEmailId ?? '', _tournamentId)
          .first;

      if (existingMatches.isNotEmpty) {
        lastMatchTime = existingMatches
            .map((m) => m.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      DateTime knockoutStartTime = lastMatchTime.add(
        Duration(minutes: (widget.breakDuration ?? 10) * 3),
      );

      List<Match> knockoutMatches = [];

      if (topTeams.length == 2) {
        knockoutMatches.add(
          Match(
            id: 'M${existingMatches.length + 1}',
            team1: Team(
              id: topTeams[0].teamId,
              name: topTeams[0].teamName,
              players: topTeams[0].players,
            ),
            team2: Team(
              id: topTeams[1].teamId,
              name: topTeams[1].teamName,
              players: topTeams[1].players,
            ),
            date: knockoutStartTime,
            time: _formatTime(knockoutStartTime),
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: 1,
            roundName: 'Final',
            stage: 'Playoff',
          ),
        );
      } else if (topTeams.length == 3 || topTeams.length == 4) {
        List<TeamStats> semiFinalTeams = topTeams.take(4).toList();

        for (int i = 0; i < semiFinalTeams.length; i += 2) {
          if (i + 1 < semiFinalTeams.length) {
            knockoutMatches.add(
              Match(
                id: 'M${existingMatches.length + knockoutMatches.length + 1}',
                team1: Team(
                  id: semiFinalTeams[i].teamId,
                  name: semiFinalTeams[i].teamName,
                  players: semiFinalTeams[i].players,
                ),
                team2: Team(
                  id: semiFinalTeams[i + 1].teamId,
                  name: semiFinalTeams[i + 1].teamName,
                  players: semiFinalTeams[i + 1].players,
                ),
                date: knockoutStartTime,
                time: _formatTime(knockoutStartTime),
                status: 'Scheduled',
                score1: 0,
                score2: 0,
                winner: null,
                round: 1,
                roundName: 'Semi Finals',
                stage: 'Playoff',
              ),
            );

            if (widget.matchDuration != null && widget.breakDuration != null) {
              knockoutStartTime = knockoutStartTime.add(
                Duration(
                  minutes: widget.matchDuration! + widget.breakDuration!,
                ),
              );
            }
          }
        }
      } else {
        List<TeamStats> qFinalTeams = topTeams.take(8).toList();

        for (int i = 0; i < qFinalTeams.length; i += 2) {
          if (i + 1 < qFinalTeams.length) {
            knockoutMatches.add(
              Match(
                id: 'M${existingMatches.length + knockoutMatches.length + 1}',
                team1: Team(
                  id: qFinalTeams[i].teamId,
                  name: qFinalTeams[i].teamName,
                  players: qFinalTeams[i].players,
                ),
                team2: Team(
                  id: qFinalTeams[i + 1].teamId,
                  name: qFinalTeams[i + 1].teamName,
                  players: qFinalTeams[i + 1].players,
                ),
                date: knockoutStartTime,
                time: _formatTime(knockoutStartTime),
                status: 'Scheduled',
                score1: 0,
                score2: 0,
                winner: null,
                round: 1,
                roundName: 'Quarter Finals',
                stage: 'Playoff',
              ),
            );

            if (widget.matchDuration != null && widget.breakDuration != null) {
              knockoutStartTime = knockoutStartTime.add(
                Duration(
                  minutes: widget.matchDuration! + widget.breakDuration!,
                ),
              );
            }
          }
        }
      }

      await _badmintonFirestoreService.addMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId,
        knockoutMatches,
      );

      setState(() => _isGeneratingNextRound = false);
      _showSuccessSnackBar('Playoff rounds generated successfully!');
    } catch (e) {
      setState(() => _isGeneratingNextRound = false);
      _showErrorSnackBar('Failed to generate playoffs: $e');
      debugPrint('❌ Error: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeamStats>>(
      stream: _badmintonFirestoreService.getTeamStats(
        _authService.currentUserEmailId ?? '',
        _tournamentId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (snapshot.hasError) {
          debugPrint('❌ Stream Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No teams found'));
        }

        List<TeamStats> teamStats = snapshot.data!;
        teamStats.sort((a, b) {
          int res = b.points.compareTo(a.points);
          if (res != 0) return res;
          res = b.won.compareTo(a.won);
          if (res != 0) return res;
          return a.matchesPlayed.compareTo(b.matchesPlayed);
        });

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.orange.shade400,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Team',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            'Played',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Won',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Pts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teamStats.length,
                      itemBuilder: (context, index) =>
                          _buildTeamRow(teamStats[index], index),
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<List<Match>>(
              stream: _badmintonFirestoreService.getMatches(
                _authService.currentUserEmailId ?? '',
                _tournamentId,
              ),
              builder: (context, matchSnapshot) {
                if (matchSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                if (!matchSnapshot.hasData || matchSnapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                List<Match> leagueMatches = matchSnapshot.data!
                    .where(
                      (m) =>
                          m.stage == 'League' ||
                          m.stage == null ||
                          m.stage == '',
                    )
                    .toList();

                bool isLeagueComplete =
                    leagueMatches.isNotEmpty &&
                    leagueMatches.every(
                      (m) => m.winner != null || m.status == 'Completed',
                    );

                bool knockoutsExist = matchSnapshot.data!.any(
                  (m) => m.stage == 'Playoff',
                );

                if (!isLeagueComplete || knockoutsExist) {
                  return const SizedBox.shrink();
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.amber.shade300, width: 2),
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingNextRound
                        ? null
                        : () => _generateRoundRobinKnockouts(
                            matchSnapshot.data
                                    ?.map(
                                      (match) => matchSnapshot.data![0],
                                    ) // Placeholder fix
                                    .toList()
                                as List<TeamStats>,
                          ),
                    icon: _isGeneratingNextRound
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange.shade600,
                              ),
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      _isGeneratingNextRound
                          ? 'Generating Playoffs...'
                          : '🏆 Generate Playoff Rounds',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
