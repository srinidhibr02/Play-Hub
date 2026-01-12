import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';

class TournamentFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's local tournaments collection reference
  CollectionReference _getUserTournamentsCollection(String userEmail) {
    return _firestore
        .collection('users')
        .doc(userEmail)
        .collection('localTournament');
  }

  // Add to TournamentFirestoreService class

  Future<void> updateMatchOrder(
    String userEmail,
    String tournamentId,
    List<Match> reorderedMatches,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .collection('tournaments')
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
            .collection('users')
            .doc(userEmail)
            .collection('tournaments')
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

  // In TournamentFirestoreService class
  Future<List<Match>> getMatchesOnce(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('localTournaments')
          .doc(tournamentId)
          .collection('matches')
          .orderBy('orderIndex') // ✅ Order by position
          .get();

      final matches = snapshot.docs.map((doc) {
        final data = doc.data();
        return Match.fromJson({
          ...data,
          'id': doc.id,
        }); // Assuming you have fromJson
      }).toList();

      debugPrint('✅ getMatchesOnce: Retrieved ${matches.length} matches');
      return matches;
    } catch (e) {
      debugPrint('❌ getMatchesOnce error: $e');
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
      CollectionReference tournamentsRef = _getUserTournamentsCollection(
        userEmail,
      );

      // Create tournament document
      DocumentReference tournamentRef = await tournamentsRef.add({
        'creatorEmail': userEmail,
        'creatorName': creatorName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active', // active, completed, cancelled
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

      String tournamentId = tournamentRef.id;

      // Add teams as subcollection
      await _addTeamsToTournament(userEmail, tournamentId, teams);

      // Add matches as subcollection
      await _addMatchesToTournament(userEmail, tournamentId, matches);

      return tournamentId;
    } catch (e) {
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
      DocumentReference teamRef = _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('teams').doc(team.id);

      batch.set(teamRef, {
        'id': team.id,
        'name': team.name,
        'players': team.players,
        'stats': {'matchesPlayed': 0, 'won': 0, 'lost': 0, 'points': 0},
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
        DocumentReference matchRef = _getUserTournamentsCollection(
          userEmail,
        ).doc(tournamentId).collection('matches').doc(match.id);

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
          DocumentReference matchRef = _getUserTournamentsCollection(
            userEmail,
          ).doc(tournamentId).collection('matches').doc(match.id);

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

      // Update tournament total matches count
      DocumentSnapshot tournamentDoc = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).get();

      if (tournamentDoc.exists) {
        Map<String, dynamic> data =
            tournamentDoc.data() as Map<String, dynamic>;
        int currentTotal = data['stats']['totalMatches'] ?? 0;

        await _getUserTournamentsCollection(
          userEmail,
        ).doc(tournamentId).update({
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
      DocumentSnapshot doc = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      return data;
    } catch (e) {
      throw Exception('Failed to get tournament: $e');
    }
  }

  /// Get all tournaments for a user
  Stream<List<Map<String, dynamic>>> getUserTournaments(String userEmail) {
    return _getUserTournamentsCollection(
      userEmail,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get tournaments by type for a user
  Stream<List<Map<String, dynamic>>> getTournamentsByType(
    String userEmail,
    String teamType,
  ) {
    return _getUserTournamentsCollection(userEmail)
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

  /// Get active tournaments for a user
  Stream<List<Map<String, dynamic>>> getActiveTournaments(String userEmail) {
    return _getUserTournamentsCollection(userEmail)
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

  /// Get teams for a tournament
  Stream<List<Team>> getTeams(String userEmail, String tournamentId) {
    return _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('teams').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return Team(
          id: data['id'],
          name: data['name'],
          players: List<String>.from(data['players']),
        );
      }).toList();
    });
  }

  /// Get matches for a tournament
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

  /// Get team statistics
  Stream<List<TeamStats>> getTeamStats(String userEmail, String tournamentId) {
    return _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('teams').snapshots().map((snapshot) {
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
      await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('matches').doc(match.id).update({
        'score1': match.score1,
        'score2': match.score2,
        'status': match.status,
        'winner': match.winner,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  /// Update team statistics after match completion
  Future<void> _updateTeamStats(
    String userEmail,
    String tournamentId,
    Match match,
  ) async {
    // Determine winner and loser team IDs (considering parent teams)
    String winnerTeamId =
        match.parentTeam1Id != null &&
            match.winner?.contains(match.parentTeam1Id!) == true
        ? match.parentTeam1Id!
        : match.parentTeam2Id != null &&
              match.winner?.contains(match.parentTeam2Id!) == true
        ? match.parentTeam2Id!
        : match.winner!;

    String loserTeamId =
        match.parentTeam1Id != null && winnerTeamId == match.parentTeam1Id
        ? match.parentTeam2Id!
        : match.parentTeam1Id != null
        ? match.parentTeam1Id!
        : match.winner == match.team1.id
        ? match.team2.id
        : match.team1.id;

    WriteBatch batch = _firestore.batch();

    // Update winner stats
    DocumentReference winnerRef = _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('teams').doc(winnerTeamId);

    batch.update(winnerRef, {
      'stats.matchesPlayed': FieldValue.increment(1),
      'stats.won': FieldValue.increment(1),
      'stats.points': FieldValue.increment(2),
    });

    // Update loser stats
    DocumentReference loserRef = _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('teams').doc(loserTeamId);

    batch.update(loserRef, {
      'stats.matchesPlayed': FieldValue.increment(1),
      'stats.lost': FieldValue.increment(1),
    });

    await batch.commit();
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
      DocumentReference shareRef = await _firestore
          .collection('sharedTournaments')
          .add({
            'ownerEmail': userEmail,
            'tournamentId': tournamentId,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 30)),
            ), // Link expires in 30 days
          });

      return shareRef.id; // This is the share code
    } catch (e) {
      throw Exception('Failed to create shareable link: $e');
    }
  }

  /// Access tournament via share code
  Future<Map<String, dynamic>?> getTournamentByShareCode(
    String shareCode,
  ) async {
    try {
      DocumentSnapshot shareDoc = await _firestore
          .collection('sharedTournaments')
          .doc(shareCode)
          .get();

      if (!shareDoc.exists) return null;

      Map<String, dynamic> shareData = shareDoc.data() as Map<String, dynamic>;
      String ownerEmail = shareData['ownerEmail'];
      String tournamentId = shareData['tournamentId'];

      // Get the actual tournament
      return await getTournament(ownerEmail, tournamentId);
    } catch (e) {
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
}
