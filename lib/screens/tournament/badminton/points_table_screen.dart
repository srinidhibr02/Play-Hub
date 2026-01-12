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
          ],
        );
      },
    );
  }
}
