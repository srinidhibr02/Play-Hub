import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Tournament progression service for managing knockout and round-robin progressions
class TournamentProgressionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Get current stage of tournament
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

  /// ✅ Check if all league matches are completed for round-robin
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

  Future<void> checkAndUpdateTournamentCompletion(String tournamentId) async {
    try {
      debugPrint('🔍 Checking tournament completion status...');

      // Get all category tournaments
      final categoryToursSnapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .get();

      if (categoryToursSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No category tournaments found');
        return;
      }

      debugPrint('📋 Total categories: ${categoryToursSnapshot.docs.length}');

      // Check status of each category
      final completedCount = categoryToursSnapshot.docs
          .where((doc) => doc['status'] == 'completed')
          .length;

      final totalCount = categoryToursSnapshot.docs.length;

      debugPrint('📊 Category Status: $completedCount/$totalCount completed');

      // If all categories are completed, update tournament status
      if (completedCount == totalCount && totalCount > 0) {
        await _firestore.collection('tournaments').doc(tournamentId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Tournament status updated to: completed');
        debugPrint('🏆🏆🏆 ALL CATEGORIES COMPLETED - TOURNAMENT FINISHED!');

        return;
      }

      debugPrint(
        '⏳ Tournament still in progress ($completedCount/$totalCount categories completed)',
      );
    } catch (e) {
      debugPrint('❌ Error checking tournament completion: $e');
      rethrow;
    }
  }

  /// This method checks all matches in current round, creates next round, and updates currentRound
  Future<void> progressKnockoutRound(
    String tournamentId,
    String categoryId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      debugPrint('🔄 Starting knockout round progression...');

      final catTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      final catTourDoc = await catTourRef.get();

      if (!catTourDoc.exists) {
        debugPrint('⚠️ Category tournament not found');
        return;
      }

      final currentRound = catTourDoc['currentRound'] as String?;
      if (currentRound == null) {
        debugPrint('⚠️ No current round found');
        return;
      }

      debugPrint('📋 Current Round: $currentRound');

      // Get all matches in current round
      final currentRoundMatches = await catTourRef
          .collection('matches')
          .where('stage', isEqualTo: currentRound)
          .get();

      if (currentRoundMatches.docs.isEmpty) {
        debugPrint('⚠️ No matches found for round: $currentRound');
        return;
      }

      final completedCount = currentRoundMatches.docs
          .where((m) => m['status'] == 'Completed')
          .length;
      final totalCount = currentRoundMatches.docs.length;

      debugPrint('📊 Match Status: $completedCount/$totalCount completed');

      // If not all matches completed, wait
      if (completedCount != totalCount) {
        debugPrint('⏳ Waiting for all matches to complete...');
        return;
      }

      debugPrint('✅ All matches in $currentRound completed!');

      // Get winners from current round
      final winners = <Map<String, dynamic>>[];
      for (final doc in currentRoundMatches.docs) {
        final match = doc.data();
        final winnerId = match['winner'] as String?;

        if (winnerId != null) {
          final winnerTeam = match['team1']['id'] == winnerId
              ? match['team1']
              : match['team2'];
          winners.add(winnerTeam as Map<String, dynamic>);
        }
      }

      if (winners.isEmpty) {
        debugPrint('⚠️ No winners found');
        return;
      }

      debugPrint('🏆 Winners: ${winners.map((w) => w['name']).toList()}');

      // Check if tournament is finished (1 winner)
      if (winners.length == 1) {
        debugPrint('🏆🏆🏆 TOURNAMENT COMPLETE!');
        debugPrint('🎉 Winner: ${winners[0]['name']}');

        await catTourRef.update({
          'stage': 'Finals',
          'currentRound': 'Finals',
          'status': 'completed',
          'winner': winners[0]['id'],
          'completedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Tournament marked as completed');
        return;
      }

      // Determine next round based on remaining teams
      final nextRound = _getNextRoundName(currentRound, winners.length);

      debugPrint('📈 Next Round: $nextRound (${winners.length} teams)');

      // Create next round matches
      await _createNextKnockoutRound(
        tournamentId,
        categoryId,
        winners,
        nextRound,
        startDate,
        startTime,
        matchDuration,
        breakDuration,
      );

      // ✅ CRITICAL: Update currentRound in Firebase
      await catTourRef.update({'currentRound': nextRound, 'stage': nextRound});

      debugPrint('✅ Updated currentRound to: $nextRound');
      debugPrint('✅ Round progression complete!');
    } catch (e) {
      debugPrint('❌ Error progressing knockout: $e');
    }
  }

  /// ✅ Determine next round name based on current round and team count
  String _getNextRoundName(String currentRound, int teamCount) {
    // Handle standard rounds
    if (currentRound.contains('Round of')) {
      // Extract number from "Round of X"
      final match = RegExp(r'Round of (\d+)').firstMatch(currentRound);
      if (match != null) {
        final currentTeams = int.tryParse(match.group(1) ?? '') ?? 0;
        final nextTeams = (currentTeams / 2).ceil();

        if (nextTeams == 16) return 'Round of 16';
        if (nextTeams == 8) return 'Quarter-Finals';
        if (nextTeams == 4) return 'Semi-Finals';
        if (nextTeams == 2) return 'Finals';
        if (nextTeams == 1) return 'Finals';

        return 'Round of $nextTeams';
      }
    }

    // Handle specific round names
    switch (currentRound) {
      case 'Quarter-Finals':
        return teamCount >= 2 ? 'Semi-Finals' : 'Finals';
      case 'Semi-Finals':
        return 'Finals';
      case 'Finals':
        return 'Champion';
      default:
        return teamCount >= 2 ? 'Quarter-Finals' : 'Finals';
    }
  }

  /// ✅ Create next knockout round matches from previous round winners
  Future<void> _createNextKnockoutRound(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> winners,
    String nextRound,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      debugPrint('📊 Creating $nextRound with ${winners.length} teams...');

      final batch = _firestore.batch();
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches');

      var currentDateTime = _combineDateTime(startDate, startTime);
      int matchCounter = 1;

      // Handle odd number of teams (bye logic)
      List<Map<String, dynamic>> teamsForMatching = List.from(winners);
      teamsForMatching.shuffle();
      if (winners.length % 2 != 0) {
        final byeTeam = teamsForMatching.removeAt(2);

        debugPrint('🎫 BYE given to: ${byeTeam['name']}');

        // Create bye match
        final byeMatchId = '${categoryId}_${nextRound}_BYE';

        batch.set(matchesRef.doc(byeMatchId), {
          'id': byeMatchId,
          'team1': {
            'id': byeTeam['id'],
            'name': byeTeam['name'],
            'members': byeTeam['members'] ?? [],
          },
          'team2': null,
          'date': currentDateTime,
          'time': _formatTime(currentDateTime),
          'status': 'Completed',
          'score1': 0,
          'score2': 0,
          'winner': byeTeam['id'],
          'stage': nextRound,
          'round': '${nextRound}_BYE',
          'isBye': true,
        });

        currentDateTime = currentDateTime.add(
          Duration(minutes: matchDuration + breakDuration),
        );
      }

      // Create regular matches
      for (int i = 0; i < teamsForMatching.length; i += 2) {
        if (i + 1 < teamsForMatching.length) {
          final team1 = teamsForMatching[i];
          final team2 = teamsForMatching[i + 1];

          final matchId = '${categoryId}_${nextRound}_M$matchCounter';

          debugPrint('⚽ Match: ${team1['name']} vs ${team2['name']}');

          batch.set(matchesRef.doc(matchId), {
            'id': matchId,
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
            'date': currentDateTime,
            'time': _formatTime(currentDateTime),
            'status': 'Scheduled',
            'score1': 0,
            'score2': 0,
            'winner': null,
            'stage': nextRound,
            'round': '${nextRound}_M$matchCounter',
            'isBye': false,
          });

          currentDateTime = currentDateTime.add(
            Duration(minutes: matchDuration + breakDuration),
          );
          matchCounter++;
        }
      }

      await batch.commit();

      final totalMatches = matchCounter - 1;
      debugPrint('✅ Created $totalMatches matches for $nextRound');
    } catch (e) {
      debugPrint('❌ Error creating next knockout round: $e');
      rethrow;
    }
  }

  /// ✅ Get tournament winner
  Future<Map<String, dynamic>?> getTournamentWinner(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final catTourDoc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .get();

      final winnerId = catTourDoc['winner'] as String?;

      if (winnerId == null) return null;

      final winnerTeam = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .doc(winnerId)
          .get();

      if (winnerTeam.exists) {
        return winnerTeam.data() as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting tournament winner: $e');
      return null;
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
}
