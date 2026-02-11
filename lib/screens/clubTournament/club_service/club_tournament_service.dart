import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClubTournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get main tournament data
  Future<Map<String, dynamic>?> getTournament(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get();

      return doc.data();
    } catch (e) {
      debugPrint('❌ Error fetching tournament: $e');
      rethrow;
    }
  }

  /// Get all registrations grouped by category
  Future<Map<String, List<Map<String, dynamic>>>> getRegistrationsByCategory(
    String tournamentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('registrations')
          .get();

      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Uncategorized';

        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }

        grouped[category]!.add(data);
      }

      return grouped;
    } catch (e) {
      debugPrint('❌ Error fetching registrations: $e');
      rethrow;
    }
  }

  /// ✅ UPDATED: Create category tournaments with teams and matches collections
  Future<void> generateCategoryTournaments(
    String tournamentId,
    DateTime startDate,
    TimeOfDay startTime,
    int matchDuration,
    int breakDuration,
    String tournamentFormat,
  ) async {
    try {
      final regsByCategory = await getRegistrationsByCategory(tournamentId);
      final batch = _firestore.batch();

      for (final entry in regsByCategory.entries) {
        final category = entry.key;
        final registrations = entry.value;

        // Create category tournament
        final catTourRef = _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('categoryTournaments')
            .doc(category);

        // Convert registrations to teams
        final teams = _registrationsToTeams(registrations, category);

        // ✅ Create teams collection and save teams
        for (int i = 0; i < teams.length; i++) {
          final team = teams[i];
          final teamRef = catTourRef.collection('teams').doc(team.id);

          batch.set(teamRef, {
            'id': team.id,
            'name': team.name,
            'players': team.members,
            'createdAt': FieldValue.serverTimestamp(),
            'stats': {
              'matchesPlayed': 0,
              'won': 0,
              'lost': 0,
              'points': 0,
              'netResult': 0,
            },
          });
        }

        // Generate matches for this category
        final matches = _generateRoundRobinMatches(
          teams: teams,
          startDate: startDate,
          startTime: startTime,
          matchDuration: matchDuration,
          breakDuration: breakDuration,
          category: category,
        );

        // Save category tournament details
        batch.set(catTourRef, {
          'category': category,
          'participantCount': registrations.length,
          'teamCount': teams.length,
          'totalMatches': matches.length,
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
          'startDate': Timestamp.fromDate(startDate),
          'startTime': _formatTime(startTime),
        });

        // ✅ Save matches
        for (final match in matches) {
          final matchRef = catTourRef.collection('matches').doc(match.id);
          batch.set(matchRef, match.toMap());
        }
      }

      await batch.commit();
      debugPrint('✅ Category tournaments with teams created successfully');
    } catch (e) {
      debugPrint('❌ Error creating category tournaments: $e');
      rethrow;
    }
  }

  /// Convert registrations to Team objects
  List<Team> _registrationsToTeams(
    List<Map<String, dynamic>> registrations,
    String category,
  ) {
    final teams = <Team>[];

    for (int i = 0; i < registrations.length; i++) {
      final reg = registrations[i];
      final participants = List<String>.from(reg['participants'] ?? []);

      teams.add(
        Team(
          id: reg['participantId'] ?? 'team_${i + 1}',
          name: reg['fullName'] ?? 'Team ${i + 1}',
          members: participants,
          playerCount: participants.length,
        ),
      );
    }

    return teams;
  }

  /// Generate round-robin matches for a category
  List<Match> _generateRoundRobinMatches({
    required List<Team> teams,
    required DateTime startDate,
    required TimeOfDay startTime,
    required int matchDuration,
    required int breakDuration,
    required String category,
  }) {
    final matches = <Match>[];
    var currentDateTime = _combineDateTime(startDate, startTime);
    int matchCounter = 1;

    // ✅ Generate FAIR round-robin rounds (no consecutive matches)
    final numTeams = teams.length;
    final numRounds = numTeams - 1; // Standard round-robin rounds

    // Create team copy for rotation
    List<Team> roundTeams = List.from(teams);

    for (int round = 0; round < numRounds; round++) {
      // Generate matches for this round (max parallel matches)
      final roundMatches = <Match>[];

      // Pair teams: 0vs1, 2vs3, 4vs5... (fair distribution)
      for (int i = 0; i < numTeams; i += 2) {
        if (i + 1 < numTeams) {
          final team1 = roundTeams[i];
          final team2 = roundTeams[i + 1];

          roundMatches.add(
            Match(
              id: '${category}_League_M${matchCounter}',
              team1: team1,
              team2: team2,
              date: currentDateTime,
              time: _formatTime(currentDateTime),
              status: 'Scheduled',
              score1: 0,
              score2: 0,
              winner: null,
              round: round + 1,
              roundName: 'Round ${round + 1}',
              stage: 'League',
              category: category,
            ),
          );
          matchCounter++;
        }
      }

      matches.addAll(roundMatches);

      // ✅ Rotate teams for next round (prevents consecutive matches)
      _rotateTeams(roundTeams);

      // Add break between rounds (longer rest)
      currentDateTime = currentDateTime.add(
        Duration(minutes: matchDuration * 2 + breakDuration * 2), // Extra rest
      );
    }

    return matches;
  }

  // ✅ Team rotation algorithm (prevents consecutive matches)
  void _rotateTeams(List<Team> teams) {
    final lastTeam = teams.removeLast();
    teams.insert(1, lastTeam);
  }

  /// Combine date and time into DateTime
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Format time to readable string
  String _formatTime(dynamic time) {
    if (time is TimeOfDay) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (time is DateTime) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '00:00';
  }

  /// Get all category tournaments (Future - for initial load)
  Future<List<Map<String, dynamic>>> getCategoryTournaments(
    String tournamentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('❌ Error fetching category tournaments: $e');
      return [];
    }
  }

  /// Get category tournaments (Stream - for real-time updates)
  Stream<List<Map<String, dynamic>>> getCategoryTournamentsStream(
    String tournamentId,
  ) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('categoryTournaments')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
  }

  /// Get matches for a specific category (returns Map for UI compatibility)
  Stream<List<Map<String, dynamic>>> getCategoryMatchesStream(
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

  /// Get teams for a specific category
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

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error fetching teams: $e');
      return [];
    }
  }

  /// Get single team data
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

      return doc.data();
    } catch (e) {
      debugPrint('❌ Error fetching team: $e');
      return null;
    }
  }

  /// Update team stats after match
  Future<void> updateTeamStats(
    String tournamentId,
    String categoryId,
    String teamId, {
    required int won,
    required int lost,
    required int points,
    required int netResult,
  }) async {
    try {
      final teamRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('teams')
          .doc(teamId);

      // Get current stats
      final teamDoc = await teamRef.get();
      final currentStats =
          (teamDoc.data()?['stats'] as Map<String, dynamic>?) ??
          {
            'matchesPlayed': 0,
            'won': 0,
            'lost': 0,
            'points': 0,
            'netResult': 0,
          };

      // Update stats
      await teamRef.update({
        'stats': {
          'matchesPlayed': (currentStats['matchesPlayed'] as int? ?? 0) + 1,
          'won': (currentStats['won'] as int? ?? 0) + won,
          'lost': (currentStats['lost'] as int? ?? 0) + lost,
          'points': (currentStats['points'] as int? ?? 0) + points,
          'netResult': (currentStats['netResult'] as int? ?? 0) + netResult,
        },
      });

      debugPrint('✅ Team stats updated: $teamId');
    } catch (e) {
      debugPrint('❌ Error updating team stats: $e');
      rethrow;
    }
  }

  /// Update match score
  Future<void> updateMatch(
    String tournamentId,
    String categoryId,
    String matchId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('categoryTournaments')
          .doc(categoryId)
          .collection('matches')
          .doc(matchId)
          .update(updates);

      debugPrint('✅ Match updated: $matchId');
    } catch (e) {
      debugPrint('❌ Error updating match: $e');
      rethrow;
    }
  }

  /// Get standings for a category (based on teams stats)
  Future<List<Map<String, dynamic>>> getCategoryStandings(
    String tournamentId,
    String categoryId,
  ) async {
    try {
      final teams = await getTeams(tournamentId, categoryId);

      // Sort by points (descending)
      teams.sort((a, b) {
        final pointsA = (a['stats']['points'] as int?) ?? 0;
        final pointsB = (b['stats']['points'] as int?) ?? 0;
        if (pointsA != pointsB) {
          return pointsB.compareTo(pointsA);
        }

        // Tiebreaker: netResult
        final netA = (a['stats']['netResult'] as int?) ?? 0;
        final netB = (b['stats']['netResult'] as int?) ?? 0;
        return netB.compareTo(netA);
      });

      return teams;
    } catch (e) {
      debugPrint('❌ Error getting standings: $e');
      return [];
    }
  }

  /// Update tournament status
  Future<void> updateTournamentStatus(
    String tournamentId,
    String status,
  ) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': status,
      });

      debugPrint('✅ Tournament status updated to: $status');
    } catch (e) {
      debugPrint('❌ Error updating tournament status: $e');
      rethrow;
    }
  }
}

/// Team model
class Team {
  final String id;
  final String name;
  final List<String> members;
  final int playerCount;

  Team({
    required this.id,
    required this.name,
    required this.members,
    required this.playerCount,
  });
}

/// Match model
class Match {
  final String id;
  final Team team1;
  final Team team2;
  final DateTime date;
  final String time;
  final String status;
  final int score1;
  final int score2;
  final String? winner;
  final int round;
  final String roundName;
  final String stage;
  final String category;

  Match({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.time,
    required this.status,
    required this.score1,
    required this.score2,
    this.winner,
    required this.round,
    required this.roundName,
    required this.stage,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team1': {'id': team1.id, 'name': team1.name, 'members': team1.members},
      'team2': {'id': team2.id, 'name': team2.name, 'members': team2.members},
      'date': date,
      'time': time,
      'status': status,
      'score1': score1,
      'score2': score2,
      'winner': winner,
      'round': round,
      'roundName': roundName,
      'stage': stage,
      'category': category,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map) {
    final team1Data = map['team1'] as Map<String, dynamic>;
    final team2Data = map['team2'] as Map<String, dynamic>;

    return Match(
      id: map['id'] ?? '',
      team1: Team(
        id: team1Data['id'] ?? '',
        name: team1Data['name'] ?? '',
        members: List<String>.from(team1Data['members'] ?? []),
        playerCount: (team1Data['members'] as List?)?.length ?? 0,
      ),
      team2: Team(
        id: team2Data['id'] ?? '',
        name: team2Data['name'] ?? '',
        members: List<String>.from(team2Data['members'] ?? []),
        playerCount: (team2Data['members'] as List?)?.length ?? 0,
      ),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      time: map['time'] ?? '00:00',
      status: map['status'] ?? 'Scheduled',
      score1: map['score1'] ?? 0,
      score2: map['score2'] ?? 0,
      winner: map['winner'],
      round: map['round'] ?? 1,
      roundName: map['roundName'] ?? '',
      stage: map['stage'] ?? '',
      category: map['category'] ?? '',
    );
  }
}
