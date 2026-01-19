import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/service/badminton_services/tournament_stats_service.dart';

class TournamentFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's local tournaments collection reference
  CollectionReference _getUserTournamentsCollection(String userEmail) {
    return _firestore.collection('sharedTournaments');
  }

  Query _getUserTournamentsQuery(String userEmail) {
    return _getUserTournamentsCollection(
      userEmail,
    ).where('creatorEmail', isEqualTo: userEmail);
  }

  Future<void> updateMatchOrder(
    String userEmail,
    String tournamentId,
    List<Match> reorderedMatches,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('sharedTournaments')
          .doc(tournamentId)
          .collection('matches')
          .doc('_metadata')
          .set({
            'matches': reorderedMatches.map((m) => m.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update each match individually
      for (var match in reorderedMatches) {
        await FirebaseFirestore.instance
            .collection('sharedTournaments')
            .doc(tournamentId)
            .collection('matches')
            .doc(match.id)
            .update(match.toMap());
      }
    } catch (e) {
      debugPrint('❌ Error updating match order: $e');
      rethrow;
    }
  }

  /// Create a new tournament under user's collection
  Future<String> createTournament({
    required String userEmail,
    required String creatorName,
    required List<String> members,
    required String teamType,
    required List<Team> teams,
    required List<Match> matches,
    required DateTime startDate,
    required TimeOfDay startTime,
    required int matchDuration,
    required int breakDuration,
    required int totalMatches,
    required int rematches,
    required bool allowRematches,
    required String tournamentFormat,
    int? customTeamSize,
  }) async {
    try {
      // ✅ FIXED: Use CollectionReference for .add()
      final tournamentsRef = _getUserTournamentsCollection(userEmail);

      // Create tournament document
      final tournamentRef = await tournamentsRef.add({
        'creatorEmail': userEmail,
        'creatorName': creatorName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'teamType': teamType,
        'members': members,
        'customTeamSize': customTeamSize,
        'tournamentFormat': tournamentFormat,
        'schedule': {
          'startDate': Timestamp.fromDate(startDate),
          'startTimeHour': startTime.hour,
          'startTimeMinute': startTime.minute,
          'matchDuration': matchDuration,
          'breakDuration': breakDuration,
          'rematches': rematches,
          'allowRematches': allowRematches,
        },
        'stats': {
          'totalTeams': teams.length,
          'totalMatches': matches.length,
          'completedMatches': 0,
          'ongoingMatches': 0,
        },
      });

      final String tournamentId = tournamentRef.id;

      // Add teams and matches
      await _addTeamsToTournament(userEmail, tournamentId, teams);
      await _addMatchesToTournament(userEmail, tournamentId, matches);

      return tournamentId;
    } catch (e) {
      debugPrint('❌ createTournament error: $e');
      throw Exception('Failed to create tournament: $e');
    }
  }

  /// Add teams to tournament
  Future<void> _addTeamsToTournament(
    String userEmail,
    String tournamentId,
    List<Team> teams,
  ) async {
    WriteBatch batch = _firestore.batch();

    for (Team team in teams) {
      // ✅ FIXED: Go directly to matches subcollection
      DocumentReference teamRef = _firestore
          .collection('sharedTournaments')
          .doc(tournamentId) // Tournament document
          .collection('teams') // Teams subcollection
          .doc(team.id); // Team document

      batch.set(teamRef, {
        'id': team.id,
        'name': team.name,
        'players': team.players,
        'stats': {
          'matchesPlayed': 0,
          'won': 0,
          'lost': 0,
          'points': 0,
          'netResult': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Add matches to tournament
  Future<void> _addMatchesToTournament(
    String userEmail,
    String tournamentId,
    List<Match> matches,
  ) async {
    // Process in batches of 500 (Firestore batch limit)
    for (int i = 0; i < matches.length; i += 500) {
      WriteBatch batch = _firestore.batch();

      int end = (i + 500 < matches.length) ? i + 500 : matches.length;
      List<Match> batchMatches = matches.sublist(i, end);

      for (Match match in batchMatches) {
        // ✅ FIXED: Direct path to matches subcollection
        DocumentReference matchRef = _firestore
            .collection('sharedTournaments')
            .doc(tournamentId)
            .collection('matches')
            .doc(match.id);

        batch.set(matchRef, {
          'id': match.id,
          'team1': {
            'id': match.team1.id,
            'name': match.team1.name,
            'players': match.team1.players,
          },
          'team2': {
            'id': match.team2.id,
            'name': match.team2.name,
            'players': match.team2.players,
          },
          'parentTeam1Id': match.parentTeam1Id,
          'parentTeam2Id': match.parentTeam2Id,
          'scheduledDate': Timestamp.fromDate(match.date),
          'time': match.time,
          'status': match.status,
          'score1': match.score1,
          'score2': match.score2,
          'winner': match.winner,
          'round': match.round,
          'stage': match.stage,
          'roundName': match.roundName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  Future<List<Match>> getCompletedMatches(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      debugPrint('📥 Fetching completed matches for tournament: $tournamentId');

      // ✅ FIXED: Direct path to tournament matches subcollection
      final matchesSnapshot = await _firestore
          .collection('sharedTournaments')
          .doc(tournamentId)
          .collection('matches')
          .where('status', isEqualTo: 'Completed')
          .orderBy('scheduledDate')
          .get();

      final matches = matchesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Match.fromMap(data);
      }).toList();

      debugPrint('✅ Fetched ${matches.length} completed matches');
      return matches;
    } catch (e) {
      debugPrint('❌ Error fetching completed matches: $e');
      rethrow;
    }
  }

  /// Stream of completed matches (real-time updates)
  Stream<List<Match>> getCompletedMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    return _firestore
        .collection('sharedTournaments')
        .doc(tournamentId)
        .collection('matches')
        .where('status', isEqualTo: 'Completed')
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '🔄 Real-time update: ${snapshot.docs.length} completed matches',
          );
          return snapshot.docs.map((doc) => Match.fromMap(doc.data())).toList();
        });
  }

  Future<TournamentStatsSummary> getTournamentStats(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      final matches = await getAllMatches(userEmail, tournamentId);
      final teams = await getTeams(userEmail, tournamentId);

      final completedMatches = matches
          .where((m) => m.status == 'Completed')
          .toList();
      final scheduledMatches = matches
          .where((m) => m.status == 'scheduled')
          .toList();
      final ongoingMatches = matches
          .where((m) => m.status == 'ongoing')
          .toList();

      return TournamentStatsSummary(
        totalMatches: matches.length,
        completedMatches: completedMatches.length,
        scheduledMatches: scheduledMatches.length,
        ongoingMatches: ongoingMatches.length,
        totalTeams: teams.length as int,
        playerStats: calculatePlayerStats(
          completedMatches,
          teams as List<Team>,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error getting tournament stats: $e');
      rethrow;
    }
  }

  Future<List<Match>> getAllMatches(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      debugPrint('📥 Fetching all matches for tournament: $tournamentId');

      // ✅ FIXED: Direct path to tournament matches subcollection
      final matchesSnapshot = await _firestore
          .collection('sharedTournaments')
          .doc(tournamentId)
          .collection('matches')
          .orderBy('scheduledDate')
          .get();

      final matches = matchesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Match.fromMap(data);
      }).toList();

      debugPrint('✅ Fetched ${matches.length} total matches');
      return matches;
    } catch (e) {
      debugPrint('❌ Error fetching matches: $e');
      rethrow;
    }
  }

  Stream<List<Match>> getAllMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    return _firestore
        .collection('sharedTournaments')
        .doc(tournamentId)
        .collection('matches')
        .orderBy('scheduledDate') // ✅ Server-side ordering
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Match.fromMap(doc.data())).toList();
        });
  }

  /// Stream of tournament statistics (real-time)
  Stream<TournamentStatsSummary> getTournamentStatsStream(
    String userEmail,
    String tournamentId,
  ) async* {
    await for (final matches in getAllMatchesStream(userEmail, tournamentId)) {
      final teams = await getTeams(userEmail, tournamentId);

      final completedMatches = matches
          .where((m) => m.status == 'Completed')
          .toList();
      final scheduledMatches = matches
          .where((m) => m.status == 'scheduled')
          .toList();
      final ongoingMatches = matches
          .where((m) => m.status == 'ongoing')
          .toList();

      yield TournamentStatsSummary(
        totalMatches: matches.length,
        completedMatches: completedMatches.length,
        scheduledMatches: scheduledMatches.length,
        ongoingMatches: ongoingMatches.length,
        totalTeams: teams.length as int,
        playerStats: calculatePlayerStats(
          completedMatches,
          teams as List<Team>,
        ),
      );
    }
  }

  /// Add new matches to existing tournament (for knockout next rounds)
  Future<void> addMatches(
    String userEmail,
    String tournamentId,
    List<Match> matches,
  ) async {
    try {
      // Process in batches of 500 (Firestore batch limit)
      for (int i = 0; i < matches.length; i += 500) {
        WriteBatch batch = _firestore.batch();

        int end = (i + 500 < matches.length) ? i + 500 : matches.length;
        List<Match> batchMatches = matches.sublist(i, end);

        for (Match match in batchMatches) {
          // ✅ FIXED
          DocumentReference matchRef = _firestore
              .collection('sharedTournaments')
              .doc(tournamentId)
              .collection('matches')
              .doc(match.id);

          batch.set(matchRef, {
            'id': match.id,
            'team1': {
              'id': match.team1.id,
              'name': match.team1.name,
              'players': match.team1.players,
            },
            'team2': {
              'id': match.team2.id,
              'name': match.team2.name,
              'players': match.team2.players,
            },
            'parentTeam1Id': match.parentTeam1Id,
            'parentTeam2Id': match.parentTeam2Id,
            'scheduledDate': Timestamp.fromDate(match.date),
            'time': match.time,
            'status': match.status,
            'score1': match.score1,
            'score2': match.score2,
            'winner': match.winner,
            'round': match.round,
            'roundName': match.roundName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      // ✅ FIXED: Update tournament stats
      DocumentSnapshot tournamentDoc = await _firestore
          .collection('sharedTournaments')
          .doc(tournamentId)
          .get();

      if (tournamentDoc.exists) {
        Map<String, dynamic> data =
            tournamentDoc.data() as Map<String, dynamic>;
        int currentTotal = data['stats']['totalMatches'] ?? 0;

        await _firestore
            .collection('sharedTournaments')
            .doc(tournamentId)
            .update({
              'stats.totalMatches': currentTotal + matches.length,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      throw Exception('Failed to add matches: $e');
    }
  }

  // ==================== READ ====================

  /// Get tournament by user email and tournament ID
  Future<Map<String, dynamic>?> getTournament(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      // ✅ FIXED
      DocumentSnapshot doc = await _firestore
          .collection('sharedTournaments')
          .doc(tournamentId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      throw Exception('Failed to get tournament: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserTournaments(String userEmail) {
    // ✅ FIXED: This one is correct - queries TOP LEVEL collection
    return _getUserTournamentsQuery(
      userEmail,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getTournamentsByType(
    String userEmail,
    String teamType,
  ) {
    // ✅ FIXED: This one is correct too
    return _getUserTournamentsQuery(userEmail)
        .where('teamType', isEqualTo: teamType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getActiveTournaments(String userEmail) {
    // ✅ FIXED: This one is correct too
    return _getUserTournamentsQuery(userEmail)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Stream<List<Team>> getTeams(String userEmail, String tournamentId) {
    // ✅ FIXED
    return _firestore
        .collection('sharedTournaments')
        .doc(tournamentId)
        .collection('teams')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            return Team.fromMap(data);
          }).toList();
        });
  }

  Stream<List<Match>> getMatches(String userEmail, String tournamentId) {
    return _getUserTournamentsCollection(userEmail)
        .doc(tournamentId)
        .collection('matches')
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();

            return Match(
              id: data['id'],
              team1: Team(
                id: data['team1']['id'],
                name: data['team1']['name'],
                players: List<String>.from(data['team1']['players']),
              ),
              team2: Team(
                id: data['team2']['id'],
                name: data['team2']['name'],
                players: List<String>.from(data['team2']['players']),
              ),
              date: (data['scheduledDate'] as Timestamp).toDate(),
              time: data['time'],
              status: data['status'],
              score1: data['score1'],
              score2: data['score2'],
              winner: data['winner'],
              parentTeam1Id: data['parentTeam1Id'],
              parentTeam2Id: data['parentTeam2Id'],
              round: data['round'],
              roundName: data['roundName'],
            );
          }).toList();
        });
  }

  Stream<List<TeamStats>> getTeamStats(String userEmail, String tournamentId) {
    // ✅ FIXED
    return _firestore
        .collection('sharedTournaments')
        .doc(tournamentId)
        .collection('teams')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            Map<String, dynamic> stats = data['stats'] ?? {};

            return TeamStats(
              teamId: data['id'],
              teamName: data['name'],
              players: List<String>.from(data['players']),
              matchesPlayed: stats['matchesPlayed'] ?? 0,
              won: stats['won'] ?? 0,
              lost: stats['lost'] ?? 0,
              points: stats['points'] ?? 0,
              netResult: stats['netResult'] ?? 0,
            );
          }).toList();
        });
  }

  // ==================== UPDATE ====================

  /// Update match score and status
  Future<void> updateMatch(
    String userEmail,
    String tournamentId,
    Match match,
  ) async {
    try {
      debugPrint(
        'Checking to see ${match.parentTeam1Id} & ${match.parentTeam2Id}',
      );
      print(match.id);
      final querySnapshot = await _getUserTournamentsCollection(userEmail)
          .doc(tournamentId)
          .collection('matches')
          .where('id', isEqualTo: match.id) // ✅ Query by field 'id'
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docRef = querySnapshot.docs.first.reference;
        await docRef.set({
          'score1': match.score1,
          'score2': match.score2,
          'status': match.status,
          'winner': match.winner,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        debugPrint('❌ Match not found: ${match.id}');
      }

      // Update team statistics if match is completed
      if (match.status == 'Completed' && match.winner != null) {
        await _updateTeamStats(userEmail, tournamentId, match);
      }

      // Update tournament stats
      await _updateTournamentStats(userEmail, tournamentId);
    } catch (e) {
      throw Exception('Failed to update match: $e');
    }
  }

  Future<void> _updateTeamStats(
    String userEmail,
    String tournamentId,
    Match match,
  ) async {
    String? winnerParentTeamId;
    String? loserParentTeamId;

    debugPrint('${match.toMap()}');

    // Check if this is a custom tournament match (has parent team references)
    if (match.parentTeam1Id != null && match.parentTeam2Id != null) {
      debugPrint('🔍 Match Details:');
      debugPrint('   Match ID: ${match.id}');
      debugPrint('   Playing Team 1: ${match.team1.name} (${match.team1.id})');
      debugPrint('   Playing Team 2: ${match.team2.name} (${match.team2.id})');
      debugPrint('   Winner ID: ${match.winner}');
      debugPrint('   Parent Team 1 ID: ${match.parentTeam1Id}');
      debugPrint('   Parent Team 2 ID: ${match.parentTeam2Id}');
      debugPrint('   Score: ${match.score1}-${match.score2}');

      // Compare winner ID with playing team IDs (exact match)
      if (match.winner == match.team1.id) {
        // Team 1's pair won → Parent Team 1 gets points
        winnerParentTeamId = match.parentTeam1Id;
        loserParentTeamId = match.parentTeam2Id;
        debugPrint(
          '   ✅ ${match.team1.name} won → ${match.parentTeam1Id} gets +2 points',
        );
      } else if (match.winner == match.team2.id) {
        // Team 2's pair won → Parent Team 2 gets points
        winnerParentTeamId = match.parentTeam2Id;
        loserParentTeamId = match.parentTeam1Id;
        debugPrint(
          '   ✅ ${match.team2.name} won → ${match.parentTeam2Id} gets +2 points',
        );
      } else {
        debugPrint(
          '   ❌ ERROR: Winner ID "${match.winner}" does not match either:',
        );
        debugPrint('      - Team 1: "${match.team1.id}"');
        debugPrint('      - Team 2: "${match.team2.id}"');
        return;
      }
    } else {
      // Singles/Doubles tournament: use direct team IDs
      debugPrint('🔍 Singles/Doubles Match:');
      debugPrint('   Winner: ${match.winner}');

      winnerParentTeamId = match.winner;
      loserParentTeamId = match.winner == match.team1.id
          ? match.team2.id
          : match.team1.id;
    }

    // Validate we have valid team IDs
    if (winnerParentTeamId == null || loserParentTeamId == null) {
      debugPrint('❌ ERROR: Could not determine winner/loser team IDs');
      debugPrint('   Winner Parent: $winnerParentTeamId');
      debugPrint('   Loser Parent: $loserParentTeamId');
      return;
    }

    // Critical validation: Winner and loser MUST be different
    if (winnerParentTeamId == loserParentTeamId) {
      debugPrint('❌ CRITICAL ERROR: Winner and loser are the same team!');
      debugPrint('   Team ID: $winnerParentTeamId');
      debugPrint('   Match data may be corrupted. Aborting update.');
      return;
    }

    // 🔥 NEW: Calculate netResult (point difference)
    final score1 = match.score1 ?? 0;
    final score2 = match.score2 ?? 0;
    final pointDifference = match.winner == match.team1.id
        ? (score1 - score2) // Team1 won: +diff for winner, -diff for loser
        : (score2 - score1); // Team2 won: +diff for winner, -diff for loser

    debugPrint(
      '🔥 NetResult calc: score1=$score1, score2=$score2, diff=$pointDifference',
    );

    debugPrint('');
    debugPrint('📊 Updating Firestore Stats:');
    debugPrint(
      '   Winner: $winnerParentTeamId (+2 points, +1 win, +$pointDifference NR)',
    );
    debugPrint(
      '   Loser: $loserParentTeamId (+0 points, +1 loss, -$pointDifference NR)',
    );

    try {
      WriteBatch batch = _firestore.batch();

      // Update winner stats
      DocumentReference winnerRef = _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('teams').doc(winnerParentTeamId);

      batch.update(winnerRef, {
        'stats.matchesPlayed': FieldValue.increment(1),
        'stats.won': FieldValue.increment(1),
        'stats.points': FieldValue.increment(2),
        'stats.netResult': FieldValue.increment(
          pointDifference,
        ), // 🔥 WINNER: +diff
      });

      debugPrint('   ✓ Winner batch queued: teams/$winnerParentTeamId');

      // Update loser stats
      DocumentReference loserRef = _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('teams').doc(loserParentTeamId);

      batch.update(loserRef, {
        'stats.matchesPlayed': FieldValue.increment(1),
        'stats.lost': FieldValue.increment(1),
        'stats.netResult': FieldValue.increment(
          -pointDifference,
        ), // 🔥 LOSER: -diff
      });

      debugPrint('   ✓ Loser batch queued: teams/$loserParentTeamId');

      await batch.commit();

      debugPrint('');
      debugPrint('✅ Stats updated successfully in Firestore!');
      debugPrint('   Winner netResult: +$pointDifference');
      debugPrint('   Loser netResult: -$pointDifference');
      debugPrint('═══════════════════════════════════════════════');
    } catch (e) {
      debugPrint('');
      debugPrint('❌ ERROR updating stats: $e');
      debugPrint('═══════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Update overall tournament statistics
  Future<void> _updateTournamentStats(
    String userEmail,
    String tournamentId,
  ) async {
    // Get all matches
    QuerySnapshot matchesSnapshot = await _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('matches').get();

    int completedMatches = 0;
    int ongoingMatches = 0;

    for (var doc in matchesSnapshot.docs) {
      String status = doc.get('status');
      if (status == 'Completed') {
        completedMatches++;
      } else if (status == 'Ongoing') {
        ongoingMatches++;
      }
    }

    await _getUserTournamentsCollection(userEmail).doc(tournamentId).update({
      'stats.completedMatches': completedMatches,
      'stats.ongoingMatches': ongoingMatches,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update tournament status
  Future<void> updateTournamentStatus(
    String userEmail,
    String tournamentId,
    String status,
  ) async {
    await _getUserTournamentsCollection(userEmail).doc(tournamentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== DELETE ====================

  /// Delete tournament and all its data
  Future<void> deleteTournament(String userEmail, String tournamentId) async {
    try {
      // Delete teams subcollection
      await _deleteCollection(
        _getUserTournamentsCollection(
          userEmail,
        ).doc(tournamentId).collection('teams'),
      );

      // Delete matches subcollection
      await _deleteCollection(
        _getUserTournamentsCollection(
          userEmail,
        ).doc(tournamentId).collection('matches'),
      );

      // Delete tournament document
      await _getUserTournamentsCollection(userEmail).doc(tournamentId).delete();
    } catch (e) {
      throw Exception('Failed to delete tournament: $e');
    }
  }

  /// Helper method to delete a collection
  Future<void> _deleteCollection(CollectionReference collection) async {
    QuerySnapshot snapshot = await collection.get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ==================== SHARED ACCESS ====================

  /// Create a shareable link data structure
  /// Store tournament reference in a public collection for sharing
  Future<String> createShareableLink(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      String shareCode = tournamentId;

      return shareCode; // This is the share code
    } catch (e) {
      throw Exception('Failed to create shareable link: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getJoinedTournaments(String userEmail) {
    return _firestore
        .collection('sharedTournaments')
        .where('joinedPlayers', arrayContains: userEmail)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  Future<void> addPlayerToTournament(
    String tournamentId,
    String userEmail,
  ) async {
    try {
      await _firestore.collection('sharedTournaments').doc(tournamentId).update(
        {
          'joinedPlayers': FieldValue.arrayUnion([userEmail]),
        },
      );
    } catch (e) {
      throw Exception('Failed to add player to tournament: $e');
    }
  }

  /// Access tournament via share code
  Future<Map<String, dynamic>?> getTournamentByShareCode(
    String shareCode,
  ) async {
    try {
      // ✅ Get tournament directly by tournamentId
      DocumentSnapshot doc = await _firestore
          .collection('sharedTournaments')
          .doc(shareCode) // Use tournamentId, not shareCode
          .get();

      if (!doc.exists) {
        debugPrint('❌ Tournament not found: $shareCode');
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      data['shareCode'] =
          shareCode; // Optional: include shareCode for convenience

      debugPrint('✅ Found tournament: ${data['name'] ?? 'Unnamed'}');
      return data;
    } catch (e) {
      debugPrint('❌ Error getting tournament by share code: $e');
      throw Exception('Failed to get tournament by share code: $e');
    }
  }

  /// Get matches via share code
  Stream<List<Match>> getMatchesByShareCode(String shareCode) async* {
    try {
      DocumentSnapshot shareDoc = await _firestore
          .collection('sharedTournaments')
          .doc(shareCode)
          .get();

      if (!shareDoc.exists) {
        yield [];
        return;
      }

      Map<String, dynamic> shareData = shareDoc.data() as Map<String, dynamic>;
      String ownerEmail = shareData['ownerEmail'];
      String tournamentId = shareData['tournamentId'];

      yield* getMatches(ownerEmail, tournamentId);
    } catch (e) {
      yield [];
    }
  }

  /// Get team stats via share code
  Stream<List<TeamStats>> getTeamStatsByShareCode(String shareCode) async* {
    try {
      DocumentSnapshot shareDoc = await _firestore
          .collection('sharedTournaments')
          .doc(shareCode)
          .get();

      if (!shareDoc.exists) {
        yield [];
        return;
      }

      Map<String, dynamic> shareData = shareDoc.data() as Map<String, dynamic>;
      String ownerEmail = shareData['ownerEmail'];
      String tournamentId = shareData['tournamentId'];

      yield* getTeamStats(ownerEmail, tournamentId);
    } catch (e) {
      yield [];
    }
  }

  Map<String, PlayerStats> calculatePlayerStats(
    List<Match> completedMatches,
    List<Team> teams,
  ) {
    final playerStatsMap = <String, PlayerStats>{};

    // Initialize all players
    for (final team in teams) {
      for (final player in team.players) {
        playerStatsMap[player] = PlayerStats(
          playerName: player,
          teamId: team.id,
          teamName: team.name,
        );
      }
    }

    debugPrint('📊 Calculating stats for ${playerStatsMap.length} players');

    // Process completed matches
    for (final match in completedMatches) {
      if (match.status != 'Completed' || match.winner == null) continue;

      final team1Players = match.team1.players;
      final team2Players = match.team2.players;
      final team1Won = match.winner == match.team1.id;

      // Update stats for team 1 players
      for (final player in team1Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score1;
          playerStatsMap[player]!.totalPointsAgainst += match.score2;

          if (team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }

      // Update stats for team 2 players
      for (final player in team2Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score2;
          playerStatsMap[player]!.totalPointsAgainst += match.score1;

          if (!team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }
    }

    debugPrint('✅ Stats calculated for ${completedMatches.length} matches');
    return playerStatsMap;
  }
}

// Add this extension to your TournamentFirestoreService class
// in badminton_service.dart (or your service file)

extension PlayoffMethods on TournamentFirestoreService {
  /// Add playoff matches to tournament
  Future<void> addPlayoffMatches(
    String userEmail,
    String tournamentId,
    List<Match> playoffMatches,
  ) async {
    try {
      if (playoffMatches.isEmpty) {
        throw Exception('No playoff matches to add');
      }

      final matchesRef = FirebaseFirestore.instance
          .collection('sharedTournaments')
          .doc(tournamentId)
          .collection('matches');

      // Convert playoff matches to maps
      final newMatches = playoffMatches
          .map((match) => _matchToMap(match))
          .toList();

      // ✅ FIX 2: Use matchesRef (NOT userRef) + collection.add()
      // Add NEW playoff matches to subcollection
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < playoffMatches.length; i++) {
        final matchDocRef = matchesRef.doc('P${i + 1}');
        batch.set(matchDocRef, {
          ...newMatches[i],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update tournament metadata
      final tournamentRef = FirebaseFirestore.instance
          .collection('sharedTournaments')
          .doc(tournamentId);

      batch.update(tournamentRef, {
        'playoffsStarted': true,
        'playoffsStartedAt': FieldValue.serverTimestamp(),
        'playoffMatchCount': playoffMatches.length,
      });

      await batch.commit();

      debugPrint('✅ Playoff matches added successfully');
    } catch (e) {
      debugPrint('❌ Error adding playoff matches: $e');
      rethrow;
    }
  }

  /// Helper method to convert Match to Firestore map
  Map<String, dynamic> _matchToMap(Match match) {
    return {
      'id': match.id,
      'team1': {
        'id': match.team1.id,
        'name': match.team1.name,
        'players': match.team1.players,
      },
      'team2': {
        'id': match.team2.id,
        'name': match.team2.name,
        'players': match.team2.players,
      },
      'date': Timestamp.fromDate(match.date),
      'time': match.time,
      'status': match.status,
      'score1': match.score1,
      'score2': match.score2,
      'winner': match.winner,
      'round': match.round,
      'roundName': match.roundName,
      'stage': match.stage,
      'rematchNumber': match.rematchNumber,
      'parentTeam1Id': match.parentTeam1Id,
      'parentTeam2Id': match.parentTeam2Id,
    };
  }

  /// Update playoff match (after semifinal completion)
  Future<void> updatePlayoffMatch(
    String userEmail,
    String tournamentId,
    Match updatedMatch,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('sharedTournaments')
          .doc(tournamentId);

      final docSnapshot = await userRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Tournament not found');
      }

      final matches = List<Map<String, dynamic>>.from(
        docSnapshot['matches'] ?? [],
      );

      // Find and update the playoff match
      final matchIndex = matches.indexWhere((m) => m['id'] == updatedMatch.id);

      if (matchIndex == -1) {
        throw Exception('Match not found: ${updatedMatch.id}');
      }

      matches[matchIndex] = _matchToMap(updatedMatch);

      // If this is a semifinal, update the final match with winner
      if (updatedMatch.stage == 'Playoff' &&
          updatedMatch.roundName?.contains('Semi') == true) {
        _updateFinalWithWinner(matches, updatedMatch);
      }

      await userRef.update({'matches': matches});
      debugPrint('✅ Playoff match updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating playoff match: $e');
      rethrow;
    }
  }

  /// Helper to update final match with semifinal winner
  void _updateFinalWithWinner(
    List<Map<String, dynamic>> matches,
    Match semifinalMatch,
  ) {
    // Find the final match
    final finalIndex = matches.indexWhere(
      (m) => m['roundName'] == 'Final' && m['stage'] == 'Playoff',
    );

    if (finalIndex == -1) return;

    final final_ = matches[finalIndex];
    final winner = semifinalMatch.score1 > semifinalMatch.score2
        ? semifinalMatch.team1
        : semifinalMatch.team2;

    // Update final match based on which semifinal it was
    if (semifinalMatch.roundName == 'Semi-Final 1') {
      // Update team1 position
      final_.update(
        'team1',
        (value) => {
          'id': winner.id,
          'name': winner.name,
          'players': winner.players,
        },
      );
    } else if (semifinalMatch.roundName == 'Semi-Final 2') {
      // Update team2 position
      final_.update(
        'team2',
        (value) => {
          'id': winner.id,
          'name': winner.name,
          'players': winner.players,
        },
      );
    }

    // Update status when both semifinal winners are known
    final team1Filled =
        final_['team1'] != null &&
        final_['team1']['id'] != null &&
        !final_['team1']['id'].toString().startsWith('team');
    final team2Filled =
        final_['team2'] != null &&
        final_['team2']['id'] != null &&
        !final_['team2']['id'].toString().startsWith('team');

    if (team1Filled && team2Filled) {
      final_.update('status', (value) => 'Scheduled');
    }
  }

  /// Get playoff status
  Future<List<Map<String, dynamic>>> getPlayoffMatches(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('sharedTournaments')
          .doc(tournamentId)
          .collection('matches')
          .where('stage', isEqualTo: 'Playoff');

      final querySnapshot = await userRef.get(); // ✅ QuerySnapshot

      // ✅ CORRECT: Access docs from QuerySnapshot
      final matches = querySnapshot.docs.map((doc) => doc.data()).toList();

      // ✅ Convert to List<Map<String, dynamic>>
      final playoffMatches = List<Map<String, dynamic>>.from(matches);

      print('Play off match $playoffMatches');

      return playoffMatches;
    } catch (e) {
      debugPrint('❌ Error getting playoff status: $e');
      rethrow;
    }
  }
}
