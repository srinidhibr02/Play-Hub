import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Dynamic Knockout tournament with proper round progression
class KnockoutTournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ FIXED: Determine round name based on team count
  String _getRoundName(int teamCount) {
    if (teamCount > 16) {
      return 'Round of ${teamCount}'; // 32, 64, etc.
    } else if (teamCount == 16) {
      return 'Round of 16';
    } else if (teamCount > 8 && teamCount <= 15) {
      return 'Round of ${teamCount}'; // 9-15 teams
    } else if (teamCount == 8) {
      return 'Quarter-Finals';
    } else if (teamCount > 4 && teamCount < 8) {
      return 'Quarter-Finals'; // 5, 6, 7 teams
    } else if (teamCount == 4) {
      return 'Semi-Finals';
    } else if (teamCount == 3) {
      return 'Semi-Finals'; // 3 teams still go to semis
    } else if (teamCount == 2) {
      return 'Finals';
    } else if (teamCount == 1) {
      return 'Champion';
    }
    return 'Finals';
  }

  /// ✅ FIXED: Get all rounds from current team count to finals
  List<String> _getAllRounds(int teamCount) {
    List<String> rounds = [];
    int currentCount = teamCount;

    debugPrint('🔄 Calculating rounds for $teamCount teams:');

    // Keep dividing until we reach 1 team (champion)
    while (currentCount >= 2) {
      final roundName = _getRoundName(currentCount);

      // Only add if not already in the list (avoid duplicates)
      if (!rounds.contains(roundName)) {
        rounds.add(roundName);
        debugPrint('  → $currentCount teams = $roundName');
      }

      // Divide teams by 2 for next round
      currentCount = (currentCount / 2).ceil();
    }

    debugPrint('📋 Final rounds list: $rounds');
    return rounds;
  }

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
      debugPrint('👥 Total teams: ${participants.length}');

      final initialRound = _getRoundName(participants.length);
      final allRounds = _getAllRounds(participants.length);

      debugPrint('🎯 Initial Round: $initialRound');
      debugPrint('📋 All Tournament Rounds: $allRounds');

      // ✅ Create categoryTournament document AND teams collection
      await _createCategoryTournamentWithTeams(
        tournamentId,
        categoryId,
        participants,
        isBestOf3,
        initialRound,
        allRounds,
      );

      debugPrint('✅ Category tournament and teams created: $categoryId');

      // ✅ Create initial round matches
      await _createRoundMatches(
        tournamentId,
        categoryId,
        participants,
        initialRound,
        startDate,
        startTime,
        matchDuration,
        breakDuration,
        isBestOf3,
      );

      debugPrint(
        '✅ Knockout matches generated for $categoryId: $initialRound with ${(participants.length / 2).ceil()} matches',
      );
    } catch (e) {
      debugPrint('❌ Error generating knockout matches: $e');
      rethrow;
    }
  }

  /// ✅ Create category tournament document AND teams collection with all rounds
  Future<void> _createCategoryTournamentWithTeams(
    String tournamentId,
    String categoryId,
    List<Map<String, dynamic>> teams,
    bool isBestOf3,
    String initialRound,
    List<String> allRounds,
  ) async {
    try {
      final categoryTourRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId);

      // Step 1: Create the categoryTournament document
      final docSnapshot = await categoryTourRef.get();

      if (!docSnapshot.exists) {
        await categoryTourRef.set({
          'id': categoryId,
          'category': categoryId,
          'tournamentId': tournamentId,
          'stage': initialRound,
          'currentRound': initialRound,
          'isBestOf3': isBestOf3,
          'status': 'active',
          'totalTeams': teams.length,
          'allRounds': allRounds,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('📁 Created categoryTournament document: $categoryId');
        debugPrint('📋 Registered rounds: $allRounds');
      }

      // Step 2: Create teams collection and add all teams
      final teamsRef = categoryTourRef.collection('teams');

      debugPrint('👥 Creating ${teams.length} teams for category: $categoryId');

      for (var team in teams) {
        final teamId = team['id'] as String;
        final teamName = team['name'] as String;
        final players = team['players'] as List<dynamic>? ?? [];

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
            'draw': 0,
            'points': 0,
            'netResult': 0,
            'pointsFor': 0,
            'pointsAgainst': 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Team created: $teamName (ID: $teamId)');
      }

      debugPrint(
        '✅ All ${teams.length} teams added to collection: $categoryId',
      );
    } catch (e) {
      debugPrint('❌ Error creating category tournament with teams: $e');
      rethrow;
    }
  }

  /// Create matches for a specific round with bye handling
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
      List<Map<String, dynamic>> byeTeams = [];

      // Reference to matches collection under categoryTournament
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches');

      debugPrint('📊 Creating matches for round: $roundName');
      debugPrint('👥 Total teams: ${teams.length}');

      // Handle odd number of teams (bye logic)
      List<Map<String, dynamic>> teamsForMatching = List.from(teams);

      if (teams.length % 2 != 0) {
        // Odd number of teams - give bye to last team
        final byeTeam = teamsForMatching.removeLast();
        byeTeams.add(byeTeam);

        debugPrint('🎫 BYE given to: ${byeTeam['name']}');

        // Create bye "match" (team automatically advances)
        final byeMatchId = '${categoryId}_${roundName}_BYE_${byeTeams.length}';

        await matchesRef.doc(byeMatchId).set({
          'id': byeMatchId,
          'team1': {
            'id': byeTeam['id'],
            'name': byeTeam['name'],
            'members': byeTeam['players'] ?? [],
          },
          'team2': null, // No opponent
          'date': currentDateTime,
          'time': _formatTime(currentDateTime),
          'status': 'Completed',
          'score1': 0,
          'score2': 0,
          'stage': roundName,
          'round': roundName,
          'isBestOf3': isBestOf3,
          'winner': byeTeam['id'], // Auto-winner
          'isBye': true, // Mark as bye match
          'setScores': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('🎫 BYE Match created: $byeMatchId');
      }

      // Pair remaining teams for matches
      for (int i = 0; i < teamsForMatching.length; i += 2) {
        if (i + 1 < teamsForMatching.length) {
          final team1 = teamsForMatching[i];
          final team2 = teamsForMatching[i + 1];

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
            'isBye': false, // Regular match
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

      final totalMatches = matchCounter - 1;
      final byeCount = byeTeams.length;

      debugPrint(
        '✅ Created $totalMatches matches + $byeCount bye matches for $roundName',
      );
    } catch (e) {
      debugPrint('❌ Error creating round matches: $e');
      rethrow;
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

      // Get winners from current round (including bye winners)
      final winners = <Map<String, dynamic>>[];
      for (final match in currentRoundMatches.docs) {
        final data = match.data();
        final winnerId = data['winner'] as String?;

        if (winnerId != null) {
          final isBye = data['isBye'] as bool? ?? false;

          // For bye matches, team1 is the winner
          final winnerTeam = isBye
              ? data['team1']
              : (data['team1']['id'] == winnerId
                    ? data['team1']
                    : data['team2']);

          winners.add(winnerTeam as Map<String, dynamic>);
        }
      }

      if (winners.isEmpty) {
        debugPrint('⚠️ No winners found in $currentRound');
        return;
      }

      debugPrint('🏆 Winners from $currentRound: ${winners.length}');

      // Check if tournament is finished (1 winner left)
      if (winners.length == 1) {
        debugPrint('🏆 TOURNAMENT WINNER: ${winners[0]['name']}');

        await catTourRef.update({
          'stage': 'Completed',
          'status': 'completed',
          'winner': winners[0]['id'],
          'completedAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      // Create next round
      final nextRound = _getRoundName(winners.length);
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

      debugPrint('✅ Progressed to $nextRound with ${winners.length} teams');
    } catch (e) {
      debugPrint('❌ Error progressing to next round: $e');
      rethrow;
    }
  }

  /// Get tournament winner
  Future<Map<String, dynamic>?> getTournamentWinner(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final categoryTour = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .get();

      if (!categoryTour.exists) return null;

      final winnerId = categoryTour['winner'] as String?;
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
        return {
          ...winnerTeam.data() as Map<String, dynamic>,
          'id': winnerTeam.id,
        };
      }

      return null;
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
    int? draw,
    int? points,
    int? netResult,
    int? pointsFor,
    int? pointsAgainst,
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
      if (draw != null) {
        updateData['stats.draw'] = FieldValue.increment(draw);
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
      if (pointsAgainst != null) {
        updateData['stats.pointsAgainst'] = FieldValue.increment(pointsAgainst);
      }

      // Always increment matchesPlayed
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
