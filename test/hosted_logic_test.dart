import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/logic/invite_code.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';

Tournament hosted({
  int capacity = 8,
  int teamCount = 0,
  int matchCount = 0,
  bool registrationOpen = true,
  DateTime? deadline,
  int entryFee = 0,
  String upiId = '',
  bool acceptCash = false,
  String inviteCode = 'K7M2QX',
  TournamentFormat format = TournamentFormat.roundRobin,
  String venue = '',
}) {
  return Tournament(
    id: 't1',
    ownerId: 'owner',
    ownerName: 'Owner',
    name: 'Sunday Smash Cup',
    sport: Sport.badminton,
    startDate: DateTime(2026, 12, 20),
    settings: const TournamentSettings(),
    kind: TournamentKind.hosted,
    format: format,
    capacity: capacity,
    teamCount: teamCount,
    matchCount: matchCount,
    registrationOpen: registrationOpen,
    registrationDeadline: deadline,
    entryFee: entryFee,
    upiId: upiId,
    acceptCash: acceptCash,
    inviteCode: inviteCode,
    venue: venue,
  );
}

void main() {
  group('InviteCode', () {
    test('generates codes of the right length from the safe alphabet', () {
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final code = InviteCode.generate(random);
        expect(code.length, InviteCode.length);
        expect(InviteCode.isValid(code), isTrue, reason: code);
      }
    });

    test('alphabet has no look-alike characters', () {
      for (final c in ['0', 'O', '1', 'I', 'L']) {
        expect(InviteCode.alphabet.contains(c), isFalse, reason: c);
      }
    });

    test('normalize ignores case, spaces and dashes', () {
      expect(InviteCode.normalize('k7m-2qx'), 'K7M2QX');
      expect(InviteCode.normalize(' K7M 2QX '), 'K7M2QX');
    });

    test('isValid accepts typed forms and rejects bad ones', () {
      expect(InviteCode.isValid('K7M-2QX'), isTrue);
      expect(InviteCode.isValid('k7m2qx'), isTrue);
      expect(InviteCode.isValid('K7M2Q'), isFalse); // too short
      expect(InviteCode.isValid('K7M2QXY'), isFalse); // too long
      expect(InviteCode.isValid('K7M2QO'), isFalse); // O is not allowed
      expect(InviteCode.isValid(''), isFalse);
    });

    test('format adds a dash for display', () {
      expect(InviteCode.format('K7M2QX'), 'K7M-2QX');
      expect(InviteCode.format('abc'), 'abc');
    });
  });

  group('buildInviteMessage', () {
    test('hosted tournament with fee, deadline and code', () {
      final message = buildInviteMessage(
        hosted(
          entryFee: 500,
          deadline: DateTime(2026, 12, 10),
          venue: 'City Arena',
        ),
      );
      expect(message, contains('Sunday Smash Cup'));
      expect(message, contains('Badminton'));
      expect(message, contains('City Arena'));
      expect(message, contains('Entry fee: ₹500 per team'));
      expect(message, contains('Register by 10 Dec 2026'));
      expect(message, contains('K7M-2QX'));
    });

    test('free hosted tournament says so', () {
      expect(buildInviteMessage(hosted()), contains('Free entry'));
    });

    test('friendly tournament has no fee or registration lines', () {
      final friendly = Tournament(
        id: 't2',
        ownerId: 'o',
        ownerName: 'O',
        name: 'Evening Kickabout',
        sport: Sport.football,
        startDate: DateTime.utc(2026, 12, 1),
        settings: TournamentSettings(),
        inviteCode: 'ABC234',
      );
      final message = buildInviteMessage(friendly);
      expect(message, contains('ABC-234'));
      expect(message, isNot(contains('Entry fee')));
      expect(message, isNot(contains('Free entry')));
      expect(message, contains('Follow along'));
    });

    test('omits the code line when there is no code', () {
      final message = buildInviteMessage(hosted(inviteCode: ''));
      expect(message, isNot(contains('invite code')));
    });
  });

  group('formatRupees', () {
    test('uses Indian digit grouping', () {
      expect(formatRupees(0), '₹0');
      expect(formatRupees(500), '₹500');
      expect(formatRupees(1500), '₹1,500');
      expect(formatRupees(150000), '₹1,50,000');
    });
  });

  group('Payments', () {
    test('valid and invalid UPI ids', () {
      expect(Payments.isValidUpiId('name@okbank'), isTrue);
      expect(Payments.isValidUpiId('john.doe-1@ybl'), isTrue);
      expect(Payments.isValidUpiId('9876543210@paytm'), isTrue);
      expect(Payments.isValidUpiId(' name@okbank '), isTrue);

      expect(Payments.isValidUpiId('name'), isFalse);
      expect(Payments.isValidUpiId('@bank'), isFalse);
      expect(Payments.isValidUpiId('name@'), isFalse);
      expect(Payments.isValidUpiId('a@b'), isFalse);
      expect(Payments.isValidUpiId('na me@bank'), isFalse);
    });

    test('phone numbers', () {
      expect(Payments.isValidPhone('98765 43210'), isTrue);
      expect(Payments.isValidPhone('+91 98765-43210'), isTrue);
      expect(Payments.isValidPhone('(987) 654 3210'), isTrue);
      expect(Payments.isValidPhone('12345'), isFalse);
      expect(Payments.isValidPhone('abcdefghij'), isFalse);
      expect(Payments.normalizePhone('+91 98765-43210'), '+919876543210');
    });

    test('payment references', () {
      expect(Payments.isValidReference(''), isTrue);
      expect(Payments.isValidReference('123456789012'), isTrue);
      expect(Payments.isValidReference('T2611201234ABC'), isTrue);
      expect(Payments.isValidReference('12 34'), isFalse);
      expect(Payments.isValidReference('abc'), isFalse);
    });

    test('fee set-up validation', () {
      String? check(int fee, {String upi = '', bool cash = false}) =>
          Payments.validateFeeSetup(fee: fee, upiId: upi, acceptCash: cash);

      expect(check(0), isNull); // free needs nothing
      expect(check(0, upi: 'garbage'), isNull);
      expect(check(100), isNotNull); // fee but no way to pay
      expect(check(100, cash: true), isNull);
      expect(check(100, upi: 'name@okbank'), isNull);
      expect(check(100, upi: 'name@okbank', cash: true), isNull);
      expect(check(100, upi: 'garbage'), isNotNull);
      expect(check(100, upi: 'garbage', cash: true), isNotNull);
      expect(check(-5, cash: true), isNotNull);
      expect(check(Payments.maxEntryFee + 1, cash: true), isNotNull);
    });

    test('describes the accepted options', () {
      expect(
        Payments.describeOptions(hosted(upiId: 'a1@bank', acceptCash: true)),
        'UPI or cash',
      );
      expect(Payments.describeOptions(hosted(upiId: 'a1@bank')), 'UPI');
      expect(Payments.describeOptions(hosted(acceptCash: true)), 'Cash');
      expect(Payments.describeOptions(hosted()), '');
    });
  });

  group('Tournament capacity and registration', () {
    test('capacity limits teams but never beyond the format maximum', () {
      expect(hosted(capacity: 8).maxTeams, 8);
      expect(hosted(capacity: 50).maxTeams, 24); // league max
      expect(
        hosted(capacity: 50, format: TournamentFormat.knockout).maxTeams,
        32,
      );
      expect(hosted(capacity: 0).maxTeams, 24);
    });

    test('friendly tournaments ignore capacity', () {
      final friendly = Tournament(
        id: 'f',
        ownerId: 'o',
        ownerName: 'O',
        name: 'F',
        sport: Sport.cricket,
        startDate: DateTime.utc(2026, 1, 1),
        settings: TournamentSettings(),
        capacity: 4,
      );
      expect(friendly.maxTeams, 24);
      expect(friendly.isHosted, isFalse);
    });

    test('open hosted tournament can be registered for', () {
      final now = DateTime(2026, 12, 1, 12);
      final t = hosted(deadline: DateTime(2026, 12, 10));
      expect(t.registrationBlockedReason(now), isNull);
      expect(t.canRegister(now), isTrue);
    });

    test('registration is blocked when closed, full, drawn or friendly', () {
      final now = DateTime(2026, 12, 1, 12);

      expect(hosted(registrationOpen: false).canRegister(now), isFalse);
      expect(hosted(capacity: 4, teamCount: 4).canRegister(now), isFalse);
      expect(hosted(matchCount: 6).canRegister(now), isFalse);

      final friendly = Tournament(
        id: 'f',
        ownerId: 'o',
        ownerName: 'O',
        name: 'F',
        sport: Sport.football,
        startDate: DateTime.utc(2026, 1, 1),
        settings: TournamentSettings(),
        registrationOpen: true,
      );
      expect(friendly.canRegister(now), isFalse);
    });

    test('the deadline day itself is still open', () {
      final t = hosted(deadline: DateTime(2026, 12, 10));
      expect(t.canRegister(DateTime(2026, 12, 10, 23, 30)), isTrue);
      expect(t.canRegister(DateTime(2026, 12, 11, 0, 1)), isFalse);
      expect(
        t.registrationBlockedReason(DateTime(2026, 12, 11)),
        contains('deadline'),
      );
    });
  });

  group('Tournament map', () {
    test('round-trips the hosted fields', () {
      final original = hosted(
        capacity: 12,
        entryFee: 750,
        upiId: 'club@okbank',
        acceptCash: true,
        deadline: DateTime(2026, 12, 15),
      );
      final copy = Tournament.fromMap('t1', original.toMap());

      expect(copy.kind, TournamentKind.hosted);
      expect(copy.capacity, 12);
      expect(copy.entryFee, 750);
      expect(copy.upiId, 'club@okbank');
      expect(copy.acceptCash, isTrue);
      expect(copy.registrationOpen, isTrue);
      expect(copy.inviteCode, 'K7M2QX');
      expect(copy.registrationDeadline, DateTime(2026, 12, 15));
    });

    test('older documents without the new fields load as friendly', () {
      final t = Tournament.fromMap('old', {
        'name': 'Old one',
        'sport': 'football',
        'ownerId': 'u',
      });
      expect(t.kind, TournamentKind.friendly);
      expect(t.inviteCode, '');
      expect(t.entryFee, 0);
      expect(t.registrationOpen, isFalse);
      expect(t.registrationDeadline, isNull);
    });

    test('TournamentKind.fromName falls back to friendly', () {
      expect(TournamentKind.fromName('hosted'), TournamentKind.hosted);
      expect(TournamentKind.fromName(null), TournamentKind.friendly);
      expect(TournamentKind.fromName('nonsense'), TournamentKind.friendly);
    });
  });

  group('Registration', () {
    test('round-trips through a map', () {
      const reg = Registration(
        id: 'u1',
        userId: 'u1',
        userName: 'Asha',
        teamName: 'Royal Strikers',
        phone: '9876543210',
        players: ['Asha', 'Ben'],
        paymentStatus: PaymentStatus.submitted,
        paymentMethod: PaymentMethod.upi,
        paymentRef: 'T2611201234ABC',
        note: 'Doubles',
      );
      final copy = Registration.fromMap('u1', reg.toMap());

      expect(copy.teamName, 'Royal Strikers');
      expect(copy.players, ['Asha', 'Ben']);
      expect(copy.status, RegistrationStatus.pending);
      expect(copy.paymentStatus, PaymentStatus.submitted);
      expect(copy.paymentMethod, PaymentMethod.upi);
      expect(copy.paymentRef, 'T2611201234ABC');
    });

    test('missing and unknown values get safe defaults', () {
      final reg = Registration.fromMap('u2', {
        'status': 'weird',
        'paymentStatus': 'weird',
        'paymentMethod': 'bitcoin',
      });
      expect(reg.userId, 'u2');
      expect(reg.status, RegistrationStatus.pending);
      expect(reg.paymentStatus, PaymentStatus.notRequired);
      expect(reg.paymentMethod, isNull);
      expect(reg.players, isEmpty);
    });

    test('owesFee is true only while a fee is outstanding', () {
      Registration regWith(PaymentStatus s) => Registration(
            id: 'u',
            userId: 'u',
            userName: 'U',
            teamName: 'T',
            phone: '9876543210',
            paymentStatus: s,
          );
      expect(regWith(PaymentStatus.unpaid).owesFee, isTrue);
      expect(regWith(PaymentStatus.submitted).owesFee, isTrue);
      expect(regWith(PaymentStatus.paid).owesFee, isFalse);
      expect(regWith(PaymentStatus.notRequired).owesFee, isFalse);
    });
  });
}
