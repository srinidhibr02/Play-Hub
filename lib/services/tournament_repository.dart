import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:play_hub/logic/fixture_generator.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// All Firestore access for tournaments lives here.
///
/// Data layout (a new root collection, so the previous version's data is
/// left untouched):
///
///     sportsTournaments/{tournamentId}
///       teams/{teamId}
///       matches/{matchId}
class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const String rootCollection = 'sportsTournaments';

  // Firestore allows 500 writes per batch; stay comfortably below.
  static const int _batchSize = 400;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection(rootCollection);

  CollectionReference<Map<String, dynamic>> _teams(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('teams');

  CollectionReference<Map<String, dynamic>> _matches(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('matches');

  // ---------------------------------------------------------------- streams

  /// Tournaments created by [uid], newest first.
  Stream<List<Tournament>> watchMyTournaments(String uid) {
    return _tournaments
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map(_tournamentsFrom);
  }

  /// Public tournaments from everyone, newest first.
  Stream<List<Tournament>> watchPublicTournaments() {
    return _tournaments
        .where('isPublic', isEqualTo: true)
        .limit(60)
        .snapshots()
        .map(_tournamentsFrom);
  }

  Stream<Tournament?> watchTournament(String id) {
    return _tournaments.doc(id).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Tournament.fromMap(doc.id, data);
    });
  }

  Stream<List<Team>> watchTeams(String tournamentId) {
    return _teams(tournamentId).orderBy('seed').snapshots().map(
          (snap) => snap.docs
              .map((d) => Team.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }

  Stream<List<TournamentMatch>> watchMatches(String tournamentId) {
    return _matches(tournamentId).orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((d) => TournamentMatch.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }

  List<Tournament> _tournamentsFrom(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs
        .map((d) => Tournament.fromMap(d.id, d.data()))
        .toList(growable: true);
    // A just-created document has no server timestamp yet; treat it as newest.
    final now = DateTime.now();
    list.sort(
      (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
    );
    return list;
  }

  // ------------------------------------------------------------ tournaments

  /// Creates the tournament and returns its new id.
  Future<String> createTournament(Tournament tournament) async {
    final ref = _tournaments.doc();
    await ref.set({
      ...tournament.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateTournament(Tournament tournament) {
    return _tournaments.doc(tournament.id).update({
      'name': tournament.name,
      'venue': tournament.venue,
      'description': tournament.description,
      'startDate': Timestamp.fromDate(tournament.startDate),
      'isPublic': tournament.isPublic,
    });
  }

  /// Deletes the tournament together with its teams and matches.
  Future<void> deleteTournament(String tournamentId) async {
    await _deleteAll(_matches(tournamentId));
    await _deleteAll(_teams(tournamentId));
    await _tournaments.doc(tournamentId).delete();
  }

  // ------------------------------------------------------------------ teams

  /// Adds teams after the existing ones. [startSeed] is the current team
  /// count, so new teams are seeded at the end of the list.
  Future<void> addTeams(
    String tournamentId,
    List<Team> teams, {
    required int startSeed,
  }) async {
    if (teams.isEmpty) return;
    final batch = _db.batch();
    for (var i = 0; i < teams.length; i++) {
      final ref = _teams(tournamentId).doc();
      batch.set(ref, teams[i].copyWith(seed: startSeed + i).toMap());
    }
    batch.update(_tournaments.doc(tournamentId), {
      'teamCount': FieldValue.increment(teams.length),
    });
    await batch.commit();
  }

  Future<void> updateTeam(String tournamentId, Team team) {
    return _teams(tournamentId).doc(team.id).update(team.toMap());
  }

  Future<void> deleteTeam(String tournamentId, String teamId) async {
    final batch = _db.batch();
    batch.delete(_teams(tournamentId).doc(teamId));
    batch.update(_tournaments.doc(tournamentId), {
      'teamCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // --------------------------------------------------------------- fixtures

  /// Creates the fixture list and moves the tournament to "live".
  ///
  /// Returns the number of matches that will actually be played (byes in a
  /// knockout bracket are stored but not counted).
  Future<int> generateFixtures({
    required Tournament tournament,
    required List<Team> teams,
    required bool shuffle,
  }) async {
    final matches = FixtureGenerator.generate(
      format: tournament.format,
      teams: teams,
      legs: tournament.settings.legs,
      random: shuffle ? Random() : null,
      newId: () => _matches(tournament.id).doc().id,
    );

    // Start from a clean slate in case a previous attempt half-finished.
    await _deleteAll(_matches(tournament.id));

    for (var i = 0; i < matches.length; i += _batchSize) {
      final batch = _db.batch();
      for (final m in matches.skip(i).take(_batchSize)) {
        batch.set(_matches(tournament.id).doc(m.id), m.toMap());
      }
      await batch.commit();
    }

    final playable = matches.where((m) => !m.isBye).length;
    await _tournaments.doc(tournament.id).update({
      'status': TournamentStatus.live.name,
      'matchCount': playable,
      'completedCount': 0,
    });
    return playable;
  }

  /// Removes every match (and score) and returns the tournament to "upcoming".
  Future<void> resetFixtures(String tournamentId) async {
    await _deleteAll(_matches(tournamentId));
    await _tournaments.doc(tournamentId).update({
      'status': TournamentStatus.upcoming.name,
      'matchCount': 0,
      'completedCount': 0,
    });
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += _batchSize) {
      final batch = _db.batch();
      for (final doc in docs.skip(i).take(_batchSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
