import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Tournament progression service for managing knockout and round-robin progressions
class TournamentProgressionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current stage of tournament
  Future<String> getCurrentStage(String tournamentId, String categoryId) async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .get();

      return doc.data()?['stage'] as String? ?? 'League';
    } catch (e) {
      debugPrint('Error getting stage: $e');
      return 'League';
    }
  }

  /// Check if all league matches are completed for round-robin
  Future<bool> isLeagueComplete(String tournamentId, String categoryId) async {
    try {
      final leagueMatches = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .where('stage', isEqualTo: 'League')
          .get();

      final completedCount = leagueMatches.docs
          .where((m) => m['status'] == 'Completed')
          .length;
      final totalCount = leagueMatches.docs.length;

      debugPrint('League progress: $completedCount/$totalCount completed');
      return completedCount == totalCount && totalCount > 0;
    } catch (e) {
      debugPrint('Error checking league completion: $e');
      return false;
    }
  }

  /// Create semi-finals and finals for round-robin (Top 4)
  Future<void> createRoundRobinPlayoffs(
    String tournamentId,
    String categoryId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      // Get top 4 teams from standings
      final standings = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .get();

      final teams = standings.docs.map((doc) => doc.data()).toList();

      // Sort by points and netResult
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
        return netB.compareTo(netA);
      });

      if (teams.length < 2) {
        debugPrint('⚠️ Not enough teams for playoffs');
        return;
      }

      final top4 = teams.take(4).toList();

      // Create semi-finals: 1 vs 4, 2 vs 3
      final batch = _firestore.batch();
      var currentDateTime = _combineDateTime(startDate, startTime);
      int matchCounter = 1;

      final matchesRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches');

      // Semi-Final 1: 1 vs 4
      batch.set(matchesRef.doc('${categoryId}_SF${matchCounter}'), {
        'id': '${categoryId}_SF${matchCounter}',
        'team1': {
          'id': top4[0]['id'],
          'name': top4[0]['name'],
          'members': top4[0]['players'] ?? [],
        },
        'team2': {
          'id': top4[3]['id'],
          'name': top4[3]['name'],
          'members': top4[3]['players'] ?? [],
        },
        'date': currentDateTime,
        'time': _formatTime(currentDateTime),
        'status': 'Scheduled',
        'score1': 0,
        'score2': 0,
        'winner': null,
        'stage': 'SemiFinals',
        'round': 'SF1',
      });

      currentDateTime = currentDateTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );
      matchCounter++;

      // Semi-Final 2: 2 vs 3
      batch.set(matchesRef.doc('${categoryId}_SF${matchCounter}'), {
        'id': '${categoryId}_SF${matchCounter}',
        'team1': {
          'id': top4[1]['id'],
          'name': top4[1]['name'],
          'members': top4[1]['players'] ?? [],
        },
        'team2': {
          'id': top4[2]['id'],
          'name': top4[2]['name'],
          'members': top4[2]['players'] ?? [],
        },
        'date': currentDateTime,
        'time': _formatTime(currentDateTime),
        'status': 'Scheduled',
        'score1': 0,
        'score2': 0,
        'winner': null,
        'stage': 'SemiFinals',
        'round': 'SF2',
      });

      // Update category tournament stage
      batch.update(
        _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('categoryTournaments')
            .doc(categoryId),
        {'stage': 'SemiFinals'},
      );

      await batch.commit();
      debugPrint(
        '✅ Round-robin playoffs created: Semi-Finals with Top 4 teams',
      );
    } catch (e) {
      debugPrint('❌ Error creating round-robin playoffs: $e');
      rethrow;
    }
  }

  /// Check if semi-finals are complete and create finals
  Future<void> checkAndCreateFinals(
    String tournamentId,
    String categoryId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      // Check if all semi-finals are completed
      final semiMatches = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .where('stage', isEqualTo: 'SemiFinals')
          .get();

      final completedCount = semiMatches.docs
          .where((m) => m['status'] == 'Completed')
          .length;

      if (completedCount == semiMatches.docs.length &&
          semiMatches.docs.isNotEmpty) {
        // Get semi-finals winners
        final winners = <Map<String, dynamic>>[];
        for (final doc in semiMatches.docs) {
          final match = doc.data();
          final winnerId = match['winner'] as String?;
          if (winnerId != null) {
            final winnerTeam = match['team1']['id'] == winnerId
                ? match['team1']
                : match['team2'];
            winners.add(winnerTeam as Map<String, dynamic>);
          }
        }

        if (winners.length == 2) {
          await _createFinal(
            tournamentId,
            categoryId,
            winners[0],
            winners[1],
            startDate,
            startTime,
            matchDuration,
            breakDuration,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking semi-finals: $e');
    }
  }

  /// Create final match
  Future<void> _createFinal(
    String tournamentId,
    String categoryId,
    Map<String, dynamic> team1,
    Map<String, dynamic> team2,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      final currentDateTime = _combineDateTime(startDate, startTime);

      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .doc('${categoryId}_Final')
          .set({
            'id': '${categoryId}_Final',
            'team1': {
              'id': team1['id'],
              'name': team1['name'],
              'members': team1['members'] ?? [],
            },
            'team2': {
              'id': team2['id'],
              'name': team2['name'],
              'members': team2['members'] ?? [],
            },
            'date': currentDateTime.add(
              Duration(minutes: matchDuration + breakDuration),
            ),
            'time': _formatTime(
              currentDateTime.add(
                Duration(minutes: matchDuration + breakDuration),
              ),
            ),
            'status': 'Scheduled',
            'score1': 0,
            'score2': 0,
            'winner': null,
            'stage': 'Final',
            'round': 'Final',
          });

      // Update stage to Finals
      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .update({'stage': 'Finals'});

      debugPrint('✅ Final match created');
    } catch (e) {
      debugPrint('Error creating final: $e');
    }
  }

  /// Handle knockout tournament progression
  Future<void> progressKnockoutRound(
    String tournamentId,
    String categoryId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      // Get all matches in current round
      final currentRound = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .orderBy('round')
          .get();

      if (currentRound.docs.isEmpty) {
        debugPrint('No matches found');
        return;
      }

      // Get the last round
      final lastMatch = currentRound.docs.last;
      final lastRound = lastMatch.data()['round'] as String?;

      // Check if all matches in current round are complete
      final currentRoundMatches = currentRound.docs
          .where((m) => m.data()['round'] == lastRound)
          .toList();

      final completedCount = currentRoundMatches
          .where((m) => m.data()['status'] == 'Completed')
          .length;

      if (completedCount == currentRoundMatches.length) {
        // Create next round
        await _createNextKnockoutRound(
          tournamentId,
          categoryId,
          currentRoundMatches,
          lastRound,
          startDate,
          startTime,
          matchDuration,
          breakDuration,
        );
      }
    } catch (e) {
      debugPrint('Error progressing knockout: $e');
    }
  }

  /// Create next knockout round matches from previous round winners
  Future<void> _createNextKnockoutRound(
    String tournamentId,
    String categoryId,
    List<QueryDocumentSnapshot> previousMatches,
    String? currentRound,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      final batch = _firestore.batch();
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches');

      // Get winners from previous round
      final winners = <Map<String, dynamic>>[];
      for (final match in previousMatches) {
        final data = match.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final winnerId = data['winner'] as String?;
        if (winnerId != null) {
          final winnerTeam = data['team1']['id'] == winnerId
              ? data['team1']
              : data['team2'];
          winners.add(winnerTeam as Map<String, dynamic>);
        }
      }

      if (winners.length < 2) {
        debugPrint('⚠️ Not enough winners to create next round');
        return;
      }

      // Determine next round
      String nextRound;
      String roundName;
      switch (currentRound) {
        case 'QF':
          nextRound = 'SF';
          roundName = 'Semi-Finals';
          break;
        case 'SF':
          nextRound = 'Final';
          roundName = 'Finals';
          break;
        default:
          nextRound = 'QF';
          roundName = 'Quarter-Finals';
      }

      var currentDateTime = _combineDateTime(startDate, startTime);
      int matchCounter = 1;

      // Create matches for next round
      for (int i = 0; i < winners.length; i += 2) {
        if (i + 1 < winners.length) {
          batch.set(
            matchesRef.doc('${categoryId}_${nextRound}${matchCounter}'),
            {
              'id': '${categoryId}_${nextRound}${matchCounter}',
              'team1': {
                'id': winners[i]['id'],
                'name': winners[i]['name'],
                'members': winners[i]['members'] ?? [],
              },
              'team2': {
                'id': winners[i + 1]['id'],
                'name': winners[i + 1]['name'],
                'members': winners[i + 1]['members'] ?? [],
              },
              'date': currentDateTime,
              'time': _formatTime(currentDateTime),
              'status': 'Scheduled',
              'score1': 0,
              'score2': 0,
              'winner': null,
              'stage': roundName,
              'round': '$nextRound${matchCounter}',
              'bestOf': 3,
            },
          );

          currentDateTime = currentDateTime.add(
            Duration(minutes: matchDuration + breakDuration),
          );
          matchCounter++;
        }
      }

      await batch.commit();
      debugPrint(
        '✅ $roundName matches created: ${winners.length ~/ 2} matches',
      );
    } catch (e) {
      debugPrint('Error creating next knockout round: $e');
      rethrow;
    }
  }

  /// Combine date and time
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Format time to string
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get tournament winner
  Future<Map<String, dynamic>?> getTournamentWinner(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final finalMatches = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .where('stage', isEqualTo: 'Final')
          .limit(1)
          .get();

      if (finalMatches.docs.isEmpty) return null;

      final finalMatch = finalMatches.docs.first.data();
      final winnerId = finalMatch['winner'] as String?;

      if (winnerId == null) return null;

      final winnerTeam = finalMatch['team1']['id'] == winnerId
          ? finalMatch['team1']
          : finalMatch['team2'];

      return winnerTeam as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting tournament winner: $e');
      return null;
    }
  }
}
