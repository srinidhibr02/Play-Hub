import 'package:play_hub/models/tournament.dart';

/// Validation and wording for entry fees and contact details.
///
/// Play Hub does not process payments. Teams pay the organizer directly by
/// UPI or in cash, and the organizer records that the money arrived.
class Payments {
  const Payments._();

  static final RegExp _upi =
      RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$');

  /// Most fees are small; this stops typos like an extra zero.
  static const int maxEntryFee = 100000;

  /// A UPI ID such as `name@okbank`.
  static bool isValidUpiId(String value) => _upi.hasMatch(value.trim());

  /// Phone numbers as people type them: spaces and dashes allowed, an
  /// optional leading +, 10 to 13 digits.
  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-()]'), '');

  static bool isValidPhone(String value) =>
      RegExp(r'^\+?[0-9]{10,13}$').hasMatch(normalizePhone(value));

  /// A UPI transaction reference is optional, but if given it should look
  /// like one (letters and digits only).
  static bool isValidReference(String value) {
    final ref = value.trim();
    if (ref.isEmpty) return true;
    return RegExp(r'^[A-Za-z0-9]{6,30}$').hasMatch(ref);
  }

  /// Returns a message for the first problem with the fee set-up, or null.
  static String? validateFeeSetup({
    required int fee,
    required String upiId,
    required bool acceptCash,
  }) {
    if (fee < 0) return 'The entry fee cannot be negative.';
    if (fee > maxEntryFee) return 'That entry fee looks like a typo.';
    if (fee == 0) return null;

    final hasUpi = upiId.trim().isNotEmpty;
    if (!hasUpi && !acceptCash) {
      return 'Choose how teams can pay: add a UPI ID, accept cash, or both.';
    }
    if (hasUpi && !isValidUpiId(upiId)) {
      return 'That UPI ID does not look right. It should be like name@bank.';
    }
    return null;
  }

  /// "UPI or cash", "UPI", "Cash" or an empty string.
  static String describeOptions(Tournament t) {
    final upi = t.upiId.trim().isNotEmpty;
    if (upi && t.acceptCash) return 'UPI or cash';
    if (upi) return 'UPI';
    if (t.acceptCash) return 'Cash';
    return '';
  }

  /// A `upi://pay` link that opens the person's UPI app with the payee,
  /// amount and note filled in. Returns null if the UPI ID is not valid.
  static String? upiPayLink({
    required String upiId,
    required String payeeName,
    required int amount,
    required String note,
  }) {
    final id = upiId.trim();
    if (!isValidUpiId(id) || amount <= 0) return null;
    String enc(String v) => Uri.encodeComponent(v).replaceAll('%40', '@');
    final name = payeeName.trim();
    return 'upi://pay?pa=${enc(id)}'
        '${name.isEmpty ? '' : '&pn=${enc(name)}'}'
        '&am=$amount&cu=INR&tn=${enc(note.trim())}';
  }
}
