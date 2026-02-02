import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlayoffSchedulingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Check if all league matches are completed
  Future<bool> isLeagueComplete(String tournamentId, String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .where('stage', isEqualTo: 'League')
          .where('status', isNotEqualTo: 'Completed')
          .get();

      return snapshot.docs.isEmpty; // Complete if no pending matches
    } catch (e) {
      debugPrint('❌ Error checking league completion: $e');
      return false;
    }
  }

  /// ✅ Get standings from league stage
  Future<List<Map<String, dynamic>>> getLeagueStandings(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .get();

      final teams = snapshot.docs.map((doc) => doc.data()).toList();

      // Sort by points, then net result, then goals for
      teams.sort((a, b) {
        final statsA = a['stats'] as Map<String, dynamic>;
        final statsB = b['stats'] as Map<String, dynamic>;

        final pointsA = (statsA['points'] as int?) ?? 0;
        final pointsB = (statsB['points'] as int?) ?? 0;

        if (pointsA != pointsB) {
          return pointsB.compareTo(pointsA);
        }

        final netA = (statsA['netResult'] as int?) ?? 0;
        final netB = (statsB['netResult'] as int?) ?? 0;

        if (netA != netB) {
          return netB.compareTo(netA);
        }

        final forA = (statsA['pointsFor'] as int?) ?? 0;
        final forB = (statsB['pointsFor'] as int?) ?? 0;

        return forB.compareTo(forA);
      });

      return teams;
    } catch (e) {
      debugPrint('❌ Error getting standings: $e');
      return [];
    }
  }

  /// ✅ Show dialog to ask user about playoff format
  Future<PlayoffChoice?> showPlayoffChoiceDialog(
    BuildContext context,
    int teamCount,
  ) async {
    return showDialog<PlayoffChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PlayoffChoiceDialog(teamCount: teamCount),
    );
  }

  /// ✅ Create playoffs based on user choice
  Future<void> createPlayoffs(
    String tournamentId,
    String categoryId,
    PlayoffChoice choice,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      final standings = await getLeagueStandings(tournamentId, categoryId);

      if (standings.isEmpty) {
        throw Exception('No teams found for playoff creation');
      }

      if (choice == PlayoffChoice.semiAndFinals) {
        // Create semi-finals with top 4
        await _createSemiFinals(
          tournamentId,
          categoryId,
          standings,
          startDate,
          startTime,
          matchDuration,
          breakDuration,
        );
      } else if (choice == PlayoffChoice.justFinals) {
        // Create finals with top 2
        await _createFinals(
          tournamentId,
          categoryId,
          standings,
          startDate,
          startTime,
          matchDuration,
          breakDuration,
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating playoffs: $e');
      rethrow;
    }
  }

  /// ✅ Create semi-finals (4 teams)
  Future<void> _createSemiFinals(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> standings,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      final batch = _firestore.batch();

      // Get top 4 teams
      final topTeams = standings.take(4).toList();

      if (topTeams.length < 2) {
        throw Exception('Need at least 2 teams for semi-finals');
      }

      var currentDateTime = _combineDateTime(startDate, startTime);

      // Semi-final 1: 1st vs 4th
      final semiFinal1 = _createMatch(
        team1: topTeams[0],
        team2: topTeams.length > 3 ? topTeams[3] : topTeams[1],
        matchNumber: 1,
        stage: 'Semi-Final',
        date: currentDateTime,
        categoryId: categoryId,
      );

      currentDateTime = currentDateTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );

      // Semi-final 2: 2nd vs 3rd
      final semiFinal2 = _createMatch(
        team1: topTeams[1],
        team2: topTeams.length > 2 ? topTeams[2] : topTeams[0],
        matchNumber: 2,
        stage: 'Semi-Final',
        date: currentDateTime,
        categoryId: categoryId,
      );

      final catTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      batch.set(
        catTourRef.collection('matches').doc(semiFinal1['id']),
        semiFinal1,
      );
      batch.set(
        catTourRef.collection('matches').doc(semiFinal2['id']),
        semiFinal2,
      );

      await batch.commit();

      debugPrint('✅ Semi-finals created successfully');
    } catch (e) {
      debugPrint('❌ Error creating semi-finals: $e');
      rethrow;
    }
  }

  /// ✅ Create finals (2 teams)
  Future<void> _createFinals(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> standings,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      final batch = _firestore.batch();

      // Get top 2 teams
      final topTeams = standings.take(2).toList();

      if (topTeams.length < 2) {
        throw Exception('Need at least 2 teams for finals');
      }

      final currentDateTime = _combineDateTime(startDate, startTime);

      // Final: 1st vs 2nd
      final finalMatch = _createMatch(
        team1: topTeams[0],
        team2: topTeams[1],
        matchNumber: 1,
        stage: 'Final',
        date: currentDateTime,
        categoryId: categoryId,
      );

      final catTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      batch.set(
        catTourRef.collection('matches').doc(finalMatch['id']),
        finalMatch,
      );

      await batch.commit();

      debugPrint('✅ Finals created successfully');
    } catch (e) {
      debugPrint('❌ Error creating finals: $e');
      rethrow;
    }
  }

  /// ✅ Create match document
  Map<String, dynamic> _createMatch({
    required Map<String, dynamic> team1,
    required Map<String, dynamic> team2,
    required int matchNumber,
    required String stage,
    required DateTime date,
    required String categoryId,
  }) {
    final team1Id = team1['id'] as String? ?? 'team_1';
    final team2Id = team2['id'] as String? ?? 'team_2';
    final team1Name = team1['name'] as String? ?? 'Team 1';
    final team2Name = team2['name'] as String? ?? 'Team 2';
    final team1Players = team1['players'] as List<dynamic>? ?? [];
    final team2Players = team2['players'] as List<dynamic>? ?? [];

    return {
      'id': '${categoryId}_${stage}_M$matchNumber',
      'team1': {
        'id': team1Id,
        'name': team1Name,
        'members': List<String>.from(team1Players),
      },
      'team2': {
        'id': team2Id,
        'name': team2Name,
        'members': List<String>.from(team2Players),
      },
      'date': date,
      'time': _formatTime(date),
      'status': 'Scheduled',
      'score1': 0,
      'score2': 0,
      'winner': null,
      'stage': stage,
      'category': categoryId,
      'isBye': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Combine date and time
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Format time
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Playoff choice enum
enum PlayoffChoice { semiAndFinals, justFinals }

/// ✅ Playoff choice dialog widget
class _PlayoffChoiceDialog extends StatelessWidget {
  final int teamCount;

  const _PlayoffChoiceDialog({required this.teamCount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade600, Colors.cyan.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
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
                              'League Complete! 🎉',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Time for playoffs',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ Info
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
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have $teamCount teams. Choose your playoff format:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ Option 1: Semi-finals + Finals
                _buildPlayoffOption(
                  context,
                  icon: Icons.filter_3_rounded,
                  title: 'Semi-Finals + Finals',
                  description: 'Top 4 teams play semi-finals, then finals',
                  details: [
                    '• Semi-Final 1: 1st vs 4th',
                    '• Semi-Final 2: 2nd vs 3rd',
                    '• Final: Winners of both semi-finals',
                  ],
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context, PlayoffChoice.semiAndFinals);
                  },
                ),

                const SizedBox(height: 12),

                // ✅ Option 2: Just Finals
                _buildPlayoffOption(
                  context,
                  icon: Icons.filter_2_rounded,
                  title: 'Just Finals',
                  description: 'Top 2 teams play directly',
                  details: [
                    '• Final: 1st vs 2nd',
                    '• Quickest path to champion',
                    '• 3rd & 4th teams complete season',
                  ],
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context, PlayoffChoice.justFinals);
                  },
                ),

                const SizedBox(height: 24),

                // ✅ Cancel button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
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

  Widget _buildPlayoffOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<String> details,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details
                    .map(
                      (detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          detail,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tap to select',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
