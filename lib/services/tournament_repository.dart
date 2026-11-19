import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:play_hub/logic/fixture_generator.dart';
import 'package:play_hub/logic/invite_code.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// A problem the organizer can understand and act on, such as trying to edit
/// a result after the next round was played.
class ResultException implements Exception {
  const ResultException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  // Prefixed with "sports" so they cannot collide with collections used by
  // the previous version of the app in the same Firebase project.
  static const String inviteCodesCollection = 'sportsInviteCodes';
  static const String usersCollection = 'sportsUsers';

  // Firestore allows 500 writes per batch; stay comfortably below.
  static const int _batchSize = 400;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection(rootCollection);

  CollectionReference<Map<String, dynamic>> _teams(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('teams');

  CollectionReference<Map<String, dynamic>> _matches(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('matches');

  CollectionReference<Map<String, dynamic>> _registrations(
    String tournamentId,
  ) =>
      _tournaments.doc(tournamentId).collection('registrations');

  /// code -> tournament lookup, so a tournament can be found from its invite
  /// code without listing every tournament.
  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _db.collection(inviteCodesCollection);

  /// Tournaments a user has registered for.
  CollectionReference<Map<String, dynamic>> _joined(String uid) =>
      _db.collection(usersCollection).doc(uid).collection('joined');

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

  /// Creates the tournament, reserves its invite code and returns its id.
  Future<String> createTournament(Tournament tournament) async {
    final ref = _tournaments.doc();
    final code = await _reserveInviteCode(
      tournamentId: ref.id,
      ownerId: tournament.ownerId,
    );
    await ref.set({
      ...tournament.toMap(),
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Gives a tournament that has no invite code (created before codes
  /// existed) one. Returns the code.
  Future<String> ensureInviteCode(Tournament tournament) async {
    if (tournament.inviteCode.isNotEmpty) return tournament.inviteCode;
    final code = await _reserveInviteCode(
      tournamentId: tournament.id,
      ownerId: tournament.ownerId,
    );
    await _tournaments.doc(tournament.id).update({'inviteCode': code});
    return code;
  }

  /// Picks a random unused code and claims it in a transaction, so two
  /// tournaments can never share one.
  Future<String> _reserveInviteCode({
    required String tournamentId,
    required String ownerId,
  }) async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = InviteCode.generate(random);
      final codeRef = _inviteCodes.doc(code);
      final claimed = await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(codeRef);
        if (snap.exists) return false;
        tx.set(codeRef, {
          'tournamentId': tournamentId,
          'ownerId': ownerId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (claimed) return code;
    }
    throw const ResultException('Could not create an invite code. Try again.');
  }

  /// Looks up a tournament id from an invite code as typed by a person.
  /// Returns null if the code is malformed or unknown.
  Future<String?> findTournamentIdByCode(String input) async {
    if (!InviteCode.isValid(input)) return null;
    final snap = await _inviteCodes.doc(InviteCode.normalize(input)).get();
    final id = snap.data()?['tournamentId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Opens or closes registration for a hosted tournament.
  Future<void> setRegistrationOpen(String tournamentId, bool open) {
    return _tournaments.doc(tournamentId).update({'registrationOpen': open});
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

  /// Deletes the tournament together with its teams, matches, registrations
  /// and invite code.
  Future<void> deleteTournament(String tournamentId) async {
    final snap = await _tournaments.doc(tournamentId).get();
    final code = snap.data()?['inviteCode'];

    await _deleteAll(_matches(tournamentId));
    await _deleteAll(_teams(tournamentId));
    await _deleteAll(_registrations(tournamentId));
    await _tournaments.doc(tournamentId).delete();
    if (code is String && code.isNotEmpty) {
      await _inviteCodes.doc(code).delete();
    }
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

  /// Removes a team. If it came from an approved registration (the team id
  /// is the registration id) that registration is marked rejected, so the
  /// two never disagree.
  Future<void> deleteTeam(String tournamentId, String teamId) {
    final regRef = _registrations(tournamentId).doc(teamId);
    return _db.runTransaction((tx) async {
      final regSnap = await tx.get(regRef);
      tx.delete(_teams(tournamentId).doc(teamId));
      tx.update(_tournaments.doc(tournamentId), {
        'teamCount': FieldValue.increment(-1),
      });
      final regData = regSnap.data();
      if (regData != null &&
          RegistrationStatus.fromName(regData['status']) ==
              RegistrationStatus.approved) {
        tx.update(regRef, {
          'status': RegistrationStatus.rejected.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
      // Once the draw is made nobody else can join.
      'registrationOpen': false,
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

  // ---------------------------------------------------------- registrations

  /// All registrations for a tournament. Only the organizer can read these.
  Stream<List<Registration>> watchRegistrations(String tournamentId) {
    return _registrations(tournamentId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Registration.fromMap(d.id, d.data()))
          .toList(growable: true);
      final now = DateTime.now();
      list.sort(
        (a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now),
      );
      return list;
    });
  }

  /// One person's own registration (null if they have not registered).
  Stream<Registration?> watchMyRegistration(String tournamentId, String uid) {
    return _registrations(tournamentId).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Registration.fromMap(doc.id, data);
    });
  }

  /// Ids of tournaments a user has registered for, newest first.
  Stream<List<String>> watchJoinedIds(String uid) {
    return _joined(uid).snapshots().map((snap) {
      final now = DateTime.now();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final at = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? now;
          final bt = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? now;
          return bt.compareTo(at);
        });
      return docs.map((d) => d.id).toList(growable: false);
    });
  }

  /// Registers the signed-in user's team. The registration id is the user id,
  /// so a second attempt cannot create a duplicate.
  Future<void> submitRegistration(
    Tournament tournament,
    Registration registration,
  ) async {
    final blocked = tournament.registrationBlockedReason(DateTime.now());
    if (blocked != null) throw ResultException(blocked);

    final batch = _db.batch();
    batch.set(_registrations(tournament.id).doc(registration.userId), {
      ...registration.toMap(),
      'paymentStatus': (tournament.hasEntryFee
              ? PaymentStatus.unpaid
              : PaymentStatus.notRequired)
          .name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_joined(registration.userId).doc(tournament.id), {
      'tournamentId': tournament.id,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Cancels a registration that has not been approved yet.
  Future<void> withdrawRegistration(String tournamentId, String uid) async {
    final batch = _db.batch();
    batch.delete(_registrations(tournamentId).doc(uid));
    batch.delete(_joined(uid).doc(tournamentId));
    await batch.commit();
  }

  /// Team tells the organizer it has paid. The organizer still has to
  /// confirm it with [setPaymentStatus].
  Future<void> submitPayment({
    required String tournamentId,
    required String uid,
    required PaymentMethod method,
    String reference = '',
  }) {
    return _registrations(tournamentId).doc(uid).update({
      'paymentStatus': PaymentStatus.submitted.name,
      'paymentMethod': method.name,
      'paymentRef': reference.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Organizer confirms (or reverts) a payment.
  Future<void> setPaymentStatus({
    required String tournamentId,
    required String registrationId,
    required PaymentStatus status,
  }) {
    return _registrations(tournamentId).doc(registrationId).update({
      'paymentStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepts a registration: the team is added to the tournament in the same
  /// transaction. Refused when the tournament is full or fixtures are drawn.
  Future<void> approveRegistration({
    required String tournamentId,
    required String registrationId,
  }) {
    final tournamentRef = _tournaments.doc(tournamentId);
    final regRef = _registrations(tournamentId).doc(registrationId);
    // The team reuses the registration id, which links the two.
    final teamRef = _teams(tournamentId).doc(registrationId);

    return _db.runTransaction((tx) async {
      final tournamentSnap = await tx.get(tournamentRef);
      final regSnap = await tx.get(regRef);
      final tournamentData = tournamentSnap.data();
      final regData = regSnap.data();
      if (tournamentData == null || regData == null) {
        throw const ResultException('This registration was removed.');
      }
      final tournament = Tournament.fromMap(tournamentSnap.id, tournamentData);
      final registration = Registration.fromMap(regSnap.id, regData);

      if (tournament.hasFixtures) {
        throw const ResultException(
          'Fixtures are already drawn. Reset them to change the teams.',
        );
      }
      if (registration.isApproved) {
        throw const ResultException('This team is already approved.');
      }
      if (tournament.isFull) {
        throw ResultException(
          'The tournament is full (${tournament.maxTeams} teams).',
        );
      }

      final team = Team(
        id: registrationId,
        name: registration.teamName,
        shortName: Team.autoShortName(registration.teamName),
        colorValue: paletteColor(tournament.teamCount),
        players: registration.players,
        seed: tournament.teamCount,
      );
      tx.set(teamRef, team.toMap());
      tx.update(regRef, {
        'status': RegistrationStatus.approved.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(tournamentRef, {'teamCount': FieldValue.increment(1)});
    });
  }

  /// Declines a registration. If it had been approved, the team is taken
  /// back out of the tournament (only possible before fixtures are drawn).
  Future<void> rejectRegistration({
    required String tournamentId,
    required String registrationId,
  }) {
    final tournamentRef = _tournaments.doc(tournamentId);
    final regRef = _registrations(tournamentId).doc(registrationId);

    return _db.runTransaction((tx) async {
      final tournamentSnap = await tx.get(tournamentRef);
      final regSnap = await tx.get(regRef);
      final tournamentData = tournamentSnap.data();
      final regData = regSnap.data();
      if (tournamentData == null || regData == null) {
        throw const ResultException('This registration was removed.');
      }
      final tournament = Tournament.fromMap(tournamentSnap.id, tournamentData);
      final registration = Registration.fromMap(regSnap.id, regData);
      if (registration.isRejected) return;

      if (registration.isApproved) {
        if (tournament.hasFixtures) {
          throw const ResultException(
            'Fixtures are already drawn. Reset them to remove a team.',
          );
        }
        tx.delete(_teams(tournamentId).doc(registrationId));
        tx.update(tournamentRef, {'teamCount': FieldValue.increment(-1)});
      }
      tx.update(regRef, {
        'status': RegistrationStatus.rejected.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------- results

  /// Marks a match as live (or back to scheduled). Completed matches are
  /// left alone; clear their result first.
  Future<void> setMatchLive(
    String tournamentId,
    String matchId, {
    required bool live,
  }) async {
    final ref = _matches(tournamentId).doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw const ResultException('This match was removed.');
      final match = TournamentMatch.fromMap(snap.id, data);
      if (match.status == MatchStatus.completed) return;
      if (live && !match.hasBothTeams) {
        throw const ResultException('Both teams must be known first.');
      }
      tx.update(ref, {
        'status': (live ? MatchStatus.live : MatchStatus.scheduled).name,
      });
    });
  }

  /// Saves a final score.
  ///
  /// In one transaction this updates the match, the tournament's progress
  /// counters and status, and (in a knockout) places the winner in the next
  /// round. Editing a result is allowed unless it would change who reaches a
  /// next-round match that has already been played.
  Future<void> saveResult({
    required String tournamentId,
    required String matchId,
    required MatchScore score,
    required String? winnerId,
  }) {
    final tournamentRef = _tournaments.doc(tournamentId);
    final matchRef = _matches(tournamentId).doc(matchId);

    return _db.runTransaction((tx) async {
      // All reads first; Firestore requires reads before writes.
      final matchSnap = await tx.get(matchRef);
      final tournamentSnap = await tx.get(tournamentRef);
      final matchData = matchSnap.data();
      final tournamentData = tournamentSnap.data();
      if (matchData == null || tournamentData == null) {
        throw const ResultException('This match was removed.');
      }
      final match = TournamentMatch.fromMap(matchSnap.id, matchData);
      final tournament = Tournament.fromMap(tournamentSnap.id, tournamentData);

      if (match.isBye || !match.hasBothTeams) {
        throw const ResultException('Both teams must be known before scoring.');
      }
      final isKnockout = tournament.format == TournamentFormat.knockout;
      if (isKnockout && winnerId == null) {
        throw const ResultException('A knockout match needs a winner.');
      }
      if (winnerId != null &&
          winnerId != match.teamAId &&
          winnerId != match.teamBId) {
        throw const ResultException('The winner must be one of the teams.');
      }

      DocumentReference<Map<String, dynamic>>? nextRef;
      TournamentMatch? next;
      if (match.nextMatchId != null) {
        nextRef = _matches(tournamentId).doc(match.nextMatchId);
        final nextSnap = await tx.get(nextRef);
        final nextData = nextSnap.data();
        if (nextData != null) {
          next = TournamentMatch.fromMap(nextSnap.id, nextData);
        }
      }

      final winnerChanged = winnerId != match.winnerId;
      if (next != null &&
          winnerChanged &&
          next.status != MatchStatus.scheduled) {
        throw const ResultException(
          'The next round match has already started, so this result cannot '
          'change who advances. Clear the next match first.',
        );
      }

      // Writes.
      tx.update(matchRef, {
        'status': MatchStatus.completed.name,
        'score': score.toMap(),
        'winnerId': winnerId,
      });

      if (next != null && nextRef != null && winnerChanged) {
        final winnerName =
            winnerId == match.teamAId ? match.teamAName : match.teamBName;
        tx.update(
          nextRef,
          match.nextSlot == 'A'
              ? {'teamAId': winnerId, 'teamAName': winnerName}
              : {'teamBId': winnerId, 'teamBName': winnerName},
        );
      }

      final wasCompleted = match.status == MatchStatus.completed;
      final completed = tournament.completedCount + (wasCompleted ? 0 : 1);
      tx.update(tournamentRef, {
        'completedCount': completed,
        'status': (completed >= tournament.matchCount
                ? TournamentStatus.completed
                : TournamentStatus.live)
            .name,
      });
    });
  }

  /// Removes a match's result so it can be scored again. In a knockout the
  /// winner is taken back out of the next round, which must not have been
  /// played yet.
  Future<void> clearResult({
    required String tournamentId,
    required String matchId,
  }) {
    final tournamentRef = _tournaments.doc(tournamentId);
    final matchRef = _matches(tournamentId).doc(matchId);

    return _db.runTransaction((tx) async {
      final matchSnap = await tx.get(matchRef);
      final tournamentSnap = await tx.get(tournamentRef);
      final matchData = matchSnap.data();
      final tournamentData = tournamentSnap.data();
      if (matchData == null || tournamentData == null) {
        throw const ResultException('This match was removed.');
      }
      final match = TournamentMatch.fromMap(matchSnap.id, matchData);
      final tournament = Tournament.fromMap(tournamentSnap.id, tournamentData);
      if (match.status != MatchStatus.completed) return;

      DocumentReference<Map<String, dynamic>>? nextRef;
      TournamentMatch? next;
      if (match.nextMatchId != null) {
        nextRef = _matches(tournamentId).doc(match.nextMatchId);
        final nextSnap = await tx.get(nextRef);
        final nextData = nextSnap.data();
        if (nextData != null) {
          next = TournamentMatch.fromMap(nextSnap.id, nextData);
        }
      }
      if (next != null && next.status != MatchStatus.scheduled) {
        throw const ResultException(
          'The next round match has already started. Clear that result '
          'first.',
        );
      }

      tx.update(matchRef, {
        'status': MatchStatus.scheduled.name,
        'score': null,
        'winnerId': null,
      });

      if (next != null && nextRef != null) {
        tx.update(
          nextRef,
          match.nextSlot == 'A'
              ? {'teamAId': null, 'teamAName': null}
              : {'teamBId': null, 'teamBName': null},
        );
      }

      final completed = max(0, tournament.completedCount - 1);
      tx.update(tournamentRef, {
        'completedCount': completed,
        'status': TournamentStatus.live.name,
      });
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
