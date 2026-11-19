import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:play_hub/models/parse_utils.dart';

/// Where a registration stands with the organizer.
enum RegistrationStatus {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        RegistrationStatus.pending => 'Pending',
        RegistrationStatus.approved => 'Approved',
        RegistrationStatus.rejected => 'Rejected',
      };

  static RegistrationStatus fromName(Object? name) =>
      parseEnum(RegistrationStatus.values, name, RegistrationStatus.pending);
}

/// Entry-fee state for one registration.
///
/// The app does not move money. A team pays the organizer directly (UPI or
/// cash), tells the app it has paid, and the organizer confirms.
enum PaymentStatus {
  /// The tournament has no entry fee.
  notRequired,

  /// A fee is due and nothing has been reported yet.
  unpaid,

  /// The team says it has paid and is waiting for the organizer to confirm.
  submitted,

  /// The organizer confirmed the payment (or waived the fee).
  paid;

  String get label => switch (this) {
        PaymentStatus.notRequired => 'No fee',
        PaymentStatus.unpaid => 'Unpaid',
        PaymentStatus.submitted => 'Verify payment',
        PaymentStatus.paid => 'Paid',
      };

  static PaymentStatus fromName(Object? name) =>
      parseEnum(PaymentStatus.values, name, PaymentStatus.notRequired);
}

enum PaymentMethod {
  upi,
  cash;

  String get label => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.cash => 'Cash',
      };

  static PaymentMethod? tryFromName(Object? name) {
    for (final m in PaymentMethod.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// A team's request to join a hosted tournament.
///
/// The document id is the registrant's user id, so a person can register
/// only once per tournament.
class Registration {
  const Registration({
    required this.id,
    required this.userId,
    required this.userName,
    required this.teamName,
    required this.phone,
    this.players = const [],
    this.status = RegistrationStatus.pending,
    this.paymentStatus = PaymentStatus.notRequired,
    this.paymentMethod,
    this.paymentRef = '',
    this.note = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String teamName;
  final String phone;
  final List<String> players;
  final RegistrationStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod? paymentMethod;

  /// UPI transaction reference (UTR) the team typed in, if any.
  final String paymentRef;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == RegistrationStatus.pending;
  bool get isApproved => status == RegistrationStatus.approved;
  bool get isRejected => status == RegistrationStatus.rejected;

  /// True when a fee is due and not yet confirmed by the organizer.
  bool get owesFee =>
      paymentStatus == PaymentStatus.unpaid ||
      paymentStatus == PaymentStatus.submitted;

  /// Map written when the registration is first created. Timestamps are
  /// added by the repository as server timestamps.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'teamName': teamName,
        'phone': phone,
        'players': players,
        'status': status.name,
        'paymentStatus': paymentStatus.name,
        'paymentMethod': paymentMethod?.name,
        'paymentRef': paymentRef,
        'note': note,
      };

  factory Registration.fromMap(String id, Map<String, dynamic> map) {
    final playersRaw = map['players'];
    return Registration(
      id: id,
      userId: parseString(map['userId'], id),
      userName: parseString(map['userName']),
      teamName: parseString(map['teamName'], 'Team'),
      phone: parseString(map['phone']),
      players: playersRaw is List
          ? playersRaw.whereType<String>().toList()
          : const [],
      status: RegistrationStatus.fromName(map['status']),
      paymentStatus: PaymentStatus.fromName(map['paymentStatus']),
      paymentMethod: PaymentMethod.tryFromName(map['paymentMethod']),
      paymentRef: parseString(map['paymentRef']),
      note: parseString(map['note']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
