import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Fixed Knockout tournament match generation service with teams collection
class KnockoutTournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate initial knockout matches for a tournament
  Future<void> generateKnockoutMatches(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> participants,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
    bool isBestOf3,
  ) async {
    try {
      debugPrint('🏆 Starting knockout match generation for: $categoryId');

      // ✅ STEP 1: Create categoryTournament document first
      await _createCategoryTournament(tournamentId, categoryId, isBestOf3);

      debugPrint('✅ Category tournament created: $categoryId');

      // ✅ STEP 2: Create teams collection and documents
      await _createTeams(tournamentId, categoryId, participants);

      debugPrint('✅ Teams created for: $categoryId');

      final roundName = _getInitialRoundName(participants.length);

      // ✅ STEP 3: Create matches under the category tournament
      await _createRoundMatches(
        tournamentId,
        categoryId,
        participants,
        roundName,
        startDate,
        startTime,
        matchDuration,
        breakDuration,
        isBestOf3,
      );

      debugPrint(
        '✅ Knockout matches generated for $categoryId: $roundName with ${participants.length ~/ 2} matches',
      );
    } catch (e) {
      debugPrint('❌ Error generating knockout matches: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Create category tournament document
  Future<void> _createCategoryTournament(
    String tournamentId,
    String categoryId,
    bool isBestOf3,
  ) async {
    try {
      final categoryTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      // Check if already exists
      final docSnapshot = await categoryTourRef.get();

      if (!docSnapshot.exists) {
        // Create the document with initial data
        await categoryTourRef.set({
          'id': categoryId,
          'category': categoryId,
          'tournamentId': tournamentId,
          'stage': 'Quarter-Finals',
          'currentRound': 'Quarter-Finals',
          'isBestOf3': isBestOf3,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('📁 Created categoryTournament document: $categoryId');
      } else {
        debugPrint('✓ Category tournament already exists: $categoryId');
      }
    } catch (e) {
      debugPrint('❌ Error creating category tournament: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Create teams collection with all participants as teams
  Future<void> _createTeams(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> participants,
  ) async {
    try {
      final teamsRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams');

      debugPrint('👥 Creating ${participants.length} teams for $categoryId');

      for (var participant in participants) {
        final teamId = participant['id'] as String;
        final teamName = participant['name'] as String;
        final players = participant['players'] as List<dynamic>? ?? [];

        // Create team document
        await teamsRef.doc(teamId).set({
          'id': teamId,
          'name': teamName,
          'players': players,
          'categoryId': categoryId,
          'tournamentId': tournamentId,
          'stats': {
            'matchesPlayed': 0,
            'won': 0,
            'lost': 0,
            'points': 0,
            'netResult': 0,
            'pointsFor': 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Team created: $teamName (ID: $teamId)');
      }

      debugPrint('✅ All ${participants.length} teams created for $categoryId');
    } catch (e) {
      debugPrint('❌ Error creating teams: $e');
      rethrow;
    }
  }

  /// Get initial round name based on participant count
  String _getInitialRoundName(int participantCount) {
    if (participantCount >= 8) {
      return 'Quarter-Finals';
    } else if (participantCount >= 4) {
      return 'Semi-Finals';
    } else {
      return 'Finals';
    }
  }

  /// Create matches for a specific round
  Future<void> _createRoundMatches(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> teams,
    String roundName,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
    bool isBestOf3,
  ) async {
    try {
      var currentDateTime = _combineDateTime(startDate, startTime);
      int matchCounter = 1;

      // ✅ Reference to matches collection under categoryTournament
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches');

      debugPrint('📊 Creating matches for round: $roundName');
      debugPrint('👥 Total teams: ${teams.length}');

      // Pair teams for matches
      for (int i = 0; i < teams.length; i += 2) {
        if (i + 1 < teams.length) {
          final team1 = teams[i];
          final team2 = teams[i + 1];

          final matchId = '${categoryId}_${roundName}_M$matchCounter';

          debugPrint('⚽ Creating match: ${team1['name']} vs ${team2['name']}');

          await matchesRef.doc(matchId).set({
            'id': matchId,
            'team1': {
              'id': team1['id'],
              'name': team1['name'],
              'members': team1['players'] ?? [],
            },
            'team2': {
              'id': team2['id'],
              'name': team2['name'],
              'members': team2['players'] ?? [],
            },
            'date': currentDateTime,
            'time': _formatTime(currentDateTime),
            'status': 'Scheduled',
            'score1': 0,
            'score2': 0,
            'stage': roundName,
            'round': roundName,
            'isBestOf3': isBestOf3,
            'winner': null,
            'setScores': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

          debugPrint('✅ Match created: $matchId');

          currentDateTime = currentDateTime.add(
            Duration(minutes: matchDuration + breakDuration),
          );
          matchCounter++;
        }
      }

      debugPrint('✅ Created ${matchCounter - 1} matches for $roundName');
    } catch (e) {
      debugPrint('❌ Error creating round matches: $e');
      rethrow;
    }
  }

  /// Get next round name based on current round
  String _getNextRoundName(String currentRound) {
    switch (currentRound) {
      case 'Quarter-Finals':
        return 'Semi-Finals';
      case 'Semi-Finals':
        return 'Finals';
      default:
        return 'Finals';
    }
  }

  /// Progress to next knockout round when current round is complete
  Future<void> progressToNextRound(
    String tournamentId,
    String categoryId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
  ) async {
    try {
      // Get current round info
      final catTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      final catTourDoc = await catTourRef.get();

      if (!catTourDoc.exists) {
        debugPrint('⚠️ Category tournament not found: $categoryId');
        return;
      }

      final currentRound = catTourDoc['currentRound'] as String?;

      if (currentRound == null) return;

      // Check if all matches in current round are complete
      final currentRoundMatches = await catTourRef
          .collection('matches')
          .where('stage', isEqualTo: currentRound)
          .get();

      final completedCount = currentRoundMatches.docs
          .where((m) => m['status'] == 'Completed')
          .length;

      if (completedCount != currentRoundMatches.docs.length) {
        debugPrint(
          '⏳ Not all matches in $currentRound completed yet ($completedCount/${currentRoundMatches.docs.length})',
        );
        return;
      }

      // Check if tournament is finished (Finals completed)
      if (currentRound == 'Finals') {
        debugPrint('🏆 Tournament Finals completed - Tournament Finished');

        await catTourRef.update({'stage': 'Completed'});

        return;
      }

      // Get winners from current round
      final winners = <Map<String, dynamic>>[];
      for (final match in currentRoundMatches.docs) {
        final data = match.data();
        final winnerId = data['winner'] as String?;

        if (winnerId != null) {
          final winnerTeam = data['team1']['id'] == winnerId
              ? data['team1']
              : data['team2'];
          winners.add(winnerTeam as Map<String, dynamic>);
        }
      }

      if (winners.isEmpty) {
        debugPrint('⚠️ No winners found in $currentRound');
        return;
      }

      // Create next round
      final nextRound = _getNextRoundName(currentRound);
      await _createRoundMatches(
        tournamentId,
        categoryId,
        winners,
        nextRound,
        startDate,
        startTime,
        matchDuration,
        breakDuration,
        catTourDoc['isBestOf3'] as bool? ?? false,
      );

      // Update current round
      await catTourRef.update({'currentRound': nextRound, 'stage': nextRound});

      debugPrint('✅ Progressed to $nextRound with ${winners.length} winners');
    } catch (e) {
      debugPrint('❌ Error progressing to next round: $e');
      rethrow;
    }
  }

  /// Get tournament winner (when Finals is complete)
  Future<Map<String, dynamic>?> getTournamentWinner(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final finalsMatches = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .where('stage', isEqualTo: 'Finals')
          .limit(1)
          .get();

      if (finalsMatches.docs.isEmpty) return null;

      final finalMatch = finalsMatches.docs.first.data();
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

  /// Get current round matches
  Stream<List<Map<String, dynamic>>> getCurrentRoundMatches(
    String tournamentId,
    String categoryId,
    String roundName,
  ) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('categoryTournaments')
        .doc(categoryId)
        .collection('matches')
        .where('stage', isEqualTo: roundName)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();
        });
  }

  /// Get all knockout matches
  Stream<List<Map<String, dynamic>>> getAllKnockoutMatches(
    String tournamentId,
    String categoryId,
  ) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('categoryTournaments')
        .doc(categoryId)
        .collection('matches')
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();
        });
  }

  /// Get all teams in a category
  Future<List<Map<String, dynamic>>> getTeams(
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

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'id': doc.id};
      }).toList();
    } catch (e) {
      debugPrint('Error getting teams: $e');
      return [];
    }
  }

  /// Get single team
  Future<Map<String, dynamic>?> getTeam(
    String tournamentId,
    String categoryId,
    String teamId,
  ) async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .doc(teamId)
          .get();

      if (doc.exists) {
        return {...doc.data() as Map<String, dynamic>, 'id': doc.id};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting team: $e');
      return null;
    }
  }

  /// Update team stats
  Future<void> updateTeamStats(
    String tournamentId,
    String categoryId,
    String teamId, {
    int? won,
    int? lost,
    int? points,
    int? netResult,
    int? pointsFor,
  }) async {
    try {
      final teamRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .doc(teamId);

      final updateData = <String, dynamic>{};

      if (won != null) {
        updateData['stats.won'] = FieldValue.increment(won);
      }
      if (lost != null) {
        updateData['stats.lost'] = FieldValue.increment(lost);
      }
      if (points != null) {
        updateData['stats.points'] = FieldValue.increment(points);
      }
      if (netResult != null) {
        updateData['stats.netResult'] = FieldValue.increment(netResult);
      }
      if (pointsFor != null) {
        updateData['stats.pointsFor'] = FieldValue.increment(pointsFor);
      }

      // Also increment matchesPlayed
      updateData['stats.matchesPlayed'] = FieldValue.increment(1);

      await teamRef.update(updateData);

      debugPrint('✅ Team stats updated: $teamId');
    } catch (e) {
      debugPrint('Error updating team stats: $e');
      rethrow;
    }
  }

  /// Combine date and time
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Format time to readable string
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
