import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/services/tournament_repository.dart';

Tournament newTournament({
  TournamentKind kind = TournamentKind.hosted,
  TournamentFormat format = TournamentFormat.roundRobin,
  int capacity = 8,
  int entryFee = 0,
  bool registrationOpen = true,
  DateTime? deadline,
}) {
  return Tournament(
    id: '',
    ownerId: 'owner',
    ownerName: 'Owner',
    name: 'Sunday Cup',
    sport: Sport.football,
    startDate: DateTime(2030, 1, 1),
    settings: const TournamentSettings(),
    kind: kind,
    format: format,
    capacity: capacity,
    entryFee: entryFee,
    upiId: entryFee > 0 ? 'owner@bank' : '',
    registrationOpen: registrationOpen,
    registrationDeadline: deadline,
  );
}

Registration reg(String uid, {String team = 'Falcons'}) => Registration(
      id: uid,
      userId: uid,
      userName: 'User $uid',
      teamName: team,
      phone: '9876543210',
      players: const ['P1', 'P2'],
    );

/// Matches a [ResultException], optionally one whose message has [text].
Matcher throwsResult([String? text]) => throwsA(
      isA<ResultException>().having(
        (e) => e.message,
        'message',
        text == null ? isNotEmpty : contains(text),
      ),
    );

void main() {
  late FakeFirebaseFirestore db;
  late TournamentRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = TournamentRepository(firestore: db);
  });

  Future<Tournament> create(Tournament t) async {
    final id = await repo.createTournament(t);
    return (await repo.watchTournament(id).first)!;
  }

  Future<Map<String, dynamic>?> doc(String path) async =>
      (await db.doc(path).get()).data();

  group('invite codes', () {
    test('a new tournament gets a code that leads back to it', () async {
      final t = await create(newTournament());
      expect(t.inviteCode, hasLength(6));
      expect(await repo.findTournamentIdByCode(t.inviteCode), t.id);
    });

    test('lookup tolerates case and spaces, rejects junk', () async {
      final t = await create(newTournament());
      final messy = ' ${t.inviteCode.toLowerCase()} ';
      expect(await repo.findTournamentIdByCode(messy), t.id);
      expect(await repo.findTournamentIdByCode('hello'), isNull);
      expect(await repo.findTournamentIdByCode(''), isNull);
    });

    test('two tournaments never share a code', () async {
      final codes = <String>{};
      for (var i = 0; i < 20; i++) {
        codes.add((await create(newTournament())).inviteCode);
      }
      expect(codes, hasLength(20));
    });

    test('ensureInviteCode adds a code to an old tournament', () async {
      final ref = db.collection(TournamentRepository.rootCollection).doc('old');
      await ref.set({...newTournament().toMap(), 'inviteCode': ''});
      final t = (await repo.watchTournament('old').first)!;
      final code = await repo.ensureInviteCode(t);
      expect(code, hasLength(6));
      expect(await repo.findTournamentIdByCode(code), 'old');
      expect((await ref.get()).data()!['inviteCode'], code);
    });
  });

  group('submitRegistration', () {
    test('free tournament: no payment needed, joined list updated', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      final r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['status'], 'pending');
      expect(r['paymentStatus'], PaymentStatus.notRequired.name);
      expect(await doc('sportsUsers/u1/joined/${t.id}'), isNotNull);
    });

    test('paid tournament starts as unpaid', () async {
      final t = await create(newTournament(entryFee: 500));
      await repo.submitRegistration(t, reg('u1'));
      final r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['paymentStatus'], PaymentStatus.unpaid.name);
    });

    test('registering twice keeps one registration', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await repo.submitRegistration(t, reg('u1', team: 'Renamed'));
      final all = await db
          .collection('sportsTournaments/${t.id}/registrations')
          .get();
      expect(all.docs, hasLength(1));
    });

    test('refused when closed, past the deadline, full or not hosted', () async {
      final closed = await create(newTournament(registrationOpen: false));
      await expectLater(
        repo.submitRegistration(closed, reg('u1')),
        throwsResult(),
      );

      final pastDeadline = await create(newTournament(deadline: DateTime(2020)));
      await expectLater(
        repo.submitRegistration(pastDeadline, reg('u1')),
        throwsResult(),
      );

      final friendly = await create(newTournament(kind: TournamentKind.friendly));
      await expectLater(
        repo.submitRegistration(friendly, reg('u1')),
        throwsResult(),
      );

      final full = await create(newTournament(capacity: 2));
      await db.doc('sportsTournaments/${full.id}').update({'teamCount': 2});
      final fullNow = (await repo.watchTournament(full.id).first)!;
      await expectLater(
        repo.submitRegistration(fullNow, reg('u1')),
        throwsResult(),
      );

      // Nothing was written by any refused attempt.
      for (final t in [closed, pastDeadline, friendly, full]) {
        final regs =
            await db.collection('sportsTournaments/${t.id}/registrations').get();
        expect(regs.docs, isEmpty);
      }
    });

    test('withdraw removes the registration and the joined entry', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await repo.withdrawRegistration(t.id, 'u1');
      expect(await doc('sportsTournaments/${t.id}/registrations/u1'), isNull);
      expect(await doc('sportsUsers/u1/joined/${t.id}'), isNull);
    });
  });

  group('payments', () {
    test('team reports, organizer confirms', () async {
      final t = await create(newTournament(entryFee: 500));
      await repo.submitRegistration(t, reg('u1'));

      await repo.submitPayment(
        tournamentId: t.id,
        uid: 'u1',
        method: PaymentMethod.upi,
        reference: '  UTR123  ',
      );
      var r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['paymentStatus'], PaymentStatus.submitted.name);
      expect(r['paymentMethod'], 'upi');
      expect(r['paymentRef'], 'UTR123');

      await repo.setPaymentStatus(
        tournamentId: t.id,
        registrationId: 'u1',
        status: PaymentStatus.paid,
      );
      r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['paymentStatus'], PaymentStatus.paid.name);
    });
  });

  group('approveRegistration', () {
    Future<void> approve(String tid, String uid) =>
        repo.approveRegistration(tournamentId: tid, registrationId: uid);

    test('creates the team, links it by id and counts it', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1', team: 'Red Falcons'));
      await approve(t.id, 'u1');

      final team = await doc('sportsTournaments/${t.id}/teams/u1');
      expect(team!['name'], 'Red Falcons');
      expect(team['seed'], 0);
      expect(team['players'], ['P1', 'P2']);
      final reg1 = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(reg1!['status'], 'approved');
      final tour = await doc('sportsTournaments/${t.id}');
      expect(tour!['teamCount'], 1);
    });

    test('seeds follow approval order', () async {
      final t = await create(newTournament());
      for (final u in ['u1', 'u2', 'u3']) {
        await repo.submitRegistration(t, reg(u, team: 'Team $u'));
        await approve(t.id, u);
      }
      final seeds = [
        for (final u in ['u1', 'u2', 'u3'])
          (await doc('sportsTournaments/${t.id}/teams/$u'))!['seed'],
      ];
      expect(seeds, [0, 1, 2]);
    });

    test('approving twice is refused and does not double count', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await approve(t.id, 'u1');
      await expectLater(approve(t.id, 'u1'), throwsResult('already'));
      expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 1);
    });

    test('refused when the tournament is full', () async {
      final t = await create(newTournament(capacity: 2));
      for (final u in ['u1', 'u2', 'u3']) {
        await repo.submitRegistration(t, reg(u, team: 'Team $u'));
      }
      await approve(t.id, 'u1');
      await approve(t.id, 'u2');
      await expectLater(approve(t.id, 'u3'), throwsResult('full'));
      expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 2);
      expect(await doc('sportsTournaments/${t.id}/teams/u3'), isNull);
    });

    test('refused once fixtures are drawn', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await db.doc('sportsTournaments/${t.id}').update({'matchCount': 3});
      await expectLater(approve(t.id, 'u1'), throwsResult('Fixtures'));
    });

    test('refused when the registration is gone', () async {
      final t = await create(newTournament());
      await expectLater(approve(t.id, 'ghost'), throwsResult('removed'));
    });
  });

  group('rejectRegistration', () {
    Future<void> reject(String tid, String uid) =>
        repo.rejectRegistration(tournamentId: tid, registrationId: uid);

    test('pending: marked rejected, no team involved', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await reject(t.id, 'u1');
      final r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['status'], 'rejected');
      expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 0);
    });

    test('approved: the team is taken back out', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await repo.approveRegistration(tournamentId: t.id, registrationId: 'u1');
      await reject(t.id, 'u1');
      expect(await doc('sportsTournaments/${t.id}/teams/u1'), isNull);
      expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 0);
      final r = await doc('sportsTournaments/${t.id}/registrations/u1');
      expect(r!['status'], 'rejected');
    });

    test('approved but fixtures drawn: refused', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await repo.approveRegistration(tournamentId: t.id, registrationId: 'u1');
      await db.doc('sportsTournaments/${t.id}').update({'matchCount': 3});
      await expectLater(reject(t.id, 'u1'), throwsResult('Fixtures'));
      expect(await doc('sportsTournaments/${t.id}/teams/u1'), isNotNull);
    });

    test('rejecting twice is harmless', () async {
      final t = await create(newTournament());
      await repo.submitRegistration(t, reg('u1'));
      await reject(t.id, 'u1');
      await reject(t.id, 'u1');
      expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 0);
    });
  });

  test('deleting an approved team rejects its registration', () async {
    final t = await create(newTournament());
    await repo.submitRegistration(t, reg('u1'));
    await repo.approveRegistration(tournamentId: t.id, registrationId: 'u1');
    await repo.deleteTeam(t.id, 'u1');
    final r = await doc('sportsTournaments/${t.id}/registrations/u1');
    expect(r!['status'], 'rejected');
    expect((await doc('sportsTournaments/${t.id}'))!['teamCount'], 0);
  });

  group('fixtures and results (knockout)', () {
    Future<(Tournament, List<TournamentMatch>)> startKnockout() async {
      final t = await create(
        newTournament(
          kind: TournamentKind.friendly,
          format: TournamentFormat.knockout,
        ),
      );
      await repo.addTeams(
        t.id,
        [
          for (final n in ['A', 'B', 'C', 'D'])
            Team(id: '', name: 'Team $n', shortName: n, colorValue: 0),
        ],
        startSeed: 0,
      );
      final teams = await repo.watchTeams(t.id).first;
      final fresh = (await repo.watchTournament(t.id).first)!;
      expect(fresh.teamCount, 4);
      await repo.generateFixtures(
        tournament: fresh,
        teams: teams,
        shuffle: false,
      );
      final matches = await repo.watchMatches(t.id).first;
      return (fresh, matches);
    }

    test('generating fixtures starts the tournament and closes entry', () async {
      final (t, matches) = await startKnockout();
      expect(matches, hasLength(3));
      final tour = await doc('sportsTournaments/${t.id}');
      expect(tour!['status'], 'live');
      expect(tour['matchCount'], 3);
      expect(tour['registrationOpen'], false);
    });

    test('winners advance and the final completes the tournament', () async {
      final (t, matches) = await startKnockout();
      final semis = matches.where((m) => m.round == 1).toList();
      final finalMatch = matches.firstWhere((m) => m.nextMatchId == null);
      expect(semis, hasLength(2));

      for (final semi in semis) {
        await repo.saveResult(
          tournamentId: t.id,
          matchId: semi.id,
          score: const MatchScore(goalsA: 2, goalsB: 1),
          winnerId: semi.teamAId,
        );
      }
      var updated = await repo.watchMatches(t.id).first;
      var fin = updated.firstWhere((m) => m.id == finalMatch.id);
      expect(fin.teamAId, isNotNull);
      expect(fin.teamBId, isNotNull);
      expect((await doc('sportsTournaments/${t.id}'))!['completedCount'], 2);

      await repo.saveResult(
        tournamentId: t.id,
        matchId: fin.id,
        score: const MatchScore(goalsA: 1, goalsB: 0),
        winnerId: fin.teamAId,
      );
      final tour = await doc('sportsTournaments/${t.id}');
      expect(tour!['status'], 'completed');
      expect(tour['completedCount'], 3);

      updated = await repo.watchMatches(t.id).first;
      fin = updated.firstWhere((m) => m.id == finalMatch.id);
      expect(fin.winnerId, fin.teamAId);
    });

    test('a knockout match needs a winner from its own two teams', () async {
      final (t, matches) = await startKnockout();
      final semi = matches.firstWhere((m) => m.round == 1);
      await expectLater(
        repo.saveResult(
          tournamentId: t.id,
          matchId: semi.id,
          score: const MatchScore(goalsA: 1, goalsB: 1),
          winnerId: null,
        ),
        throwsResult('winner'),
      );
      await expectLater(
        repo.saveResult(
          tournamentId: t.id,
          matchId: semi.id,
          score: const MatchScore(goalsA: 1, goalsB: 0),
          winnerId: 'someone-else',
        ),
        throwsResult('winner'),
      );
    });

    test('cannot change who advances once the next match started', () async {
      final (t, matches) = await startKnockout();
      final semis = matches.where((m) => m.round == 1).toList();
      for (final semi in semis) {
        await repo.saveResult(
          tournamentId: t.id,
          matchId: semi.id,
          score: const MatchScore(goalsA: 2, goalsB: 1),
          winnerId: semi.teamAId,
        );
      }
      final finalMatch = (await repo.watchMatches(t.id).first)
          .firstWhere((m) => m.nextMatchId == null);
      await repo.setMatchLive(t.id, finalMatch.id, live: true);

      await expectLater(
        repo.saveResult(
          tournamentId: t.id,
          matchId: semis.first.id,
          score: const MatchScore(goalsA: 0, goalsB: 1),
          winnerId: semis.first.teamBId,
        ),
        throwsResult('already started'),
      );
      await expectLater(
        repo.clearResult(tournamentId: t.id, matchId: semis.first.id),
        throwsResult('already started'),
      );
    });

    test('clearing a result takes the winner out of the next round', () async {
      final (t, matches) = await startKnockout();
      final semi = matches.firstWhere((m) => m.round == 1);
      await repo.saveResult(
        tournamentId: t.id,
        matchId: semi.id,
        score: const MatchScore(goalsA: 2, goalsB: 0),
        winnerId: semi.teamAId,
      );
      await repo.clearResult(tournamentId: t.id, matchId: semi.id);

      final after = await repo.watchMatches(t.id).first;
      final cleared = after.firstWhere((m) => m.id == semi.id);
      expect(cleared.status, MatchStatus.scheduled);
      expect(cleared.winnerId, isNull);
      final next = after.firstWhere((m) => m.id == semi.nextMatchId);
      expect(next.teamAId == semi.teamAId, isFalse);
      expect(next.teamBId == semi.teamAId, isFalse);
      expect((await doc('sportsTournaments/${t.id}'))!['completedCount'], 0);
    });

    test('resetting fixtures clears matches and returns to upcoming', () async {
      final (t, _) = await startKnockout();
      await repo.resetFixtures(t.id);
      expect(await repo.watchMatches(t.id).first, isEmpty);
      final tour = await doc('sportsTournaments/${t.id}');
      expect(tour!['status'], 'upcoming');
      expect(tour['matchCount'], 0);
    });
  });

  test('deleteTournament removes it and its subcollections', () async {
    final t = await create(newTournament());
    await repo.submitRegistration(t, reg('u1'));
    await repo.deleteTournament(t.id);
    expect(await doc('sportsTournaments/${t.id}'), isNull);
    final regs =
        await db.collection('sportsTournaments/${t.id}/registrations').get();
    expect(regs.docs, isEmpty);
  });
}
