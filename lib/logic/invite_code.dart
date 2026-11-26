import 'dart:math';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/models/tournament.dart';

/// Short codes people type or paste to find a tournament, for example
/// "K7M-2QX". Pure Dart so it can be tested without Firebase.
class InviteCode {
  const InviteCode._();

  /// Letters and digits that cannot be mistaken for each other when read
  /// aloud or typed from a screenshot: no 0/O, 1/I/L.
  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int length = 6;

  /// Makes a random code. Pass `Random.secure()` in production.
  static String generate(Random random) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Upper-cases and removes spaces, dashes and anything else typed by
  /// accident, so "k7m 2qx" and "K7M-2QX" are the same code.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String input) {
    final code = normalize(input);
    if (code.length != length) return false;
    for (final char in code.split('')) {
      if (!alphabet.contains(char)) return false;
    }
    return true;
  }

  /// Pulls an invite code out of whatever a QR scanner read: the bare code,
  /// or text that contains one such as "Join with code K7M-2QX". Returns the
  /// normalized code, or null if there is no valid code in it.
  static String? fromScan(String raw) {
    final text = raw.trim().toUpperCase();
    if (isValid(text) && text.length <= length + 1) return normalize(text);
    for (final m in RegExp(r'\b[A-Z0-9]{3}-?[A-Z0-9]{3}\b').allMatches(text)) {
      final candidate = normalize(m.group(0)!);
      if (isValid(candidate)) return candidate;
    }
    return null;
  }

  /// "K7M2QX" -> "K7M-2QX" for display.
  static String format(String code) {
    if (code.length != length) return code;
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }
}

/// Plain-text invitation the organizer can paste into WhatsApp, SMS and so
/// on. It includes the invite code when the tournament has one.
String buildInviteMessage(Tournament t) {
  final lines = <String>[
    t.name,
    '${t.sport.label} | ${t.format.label}',
    'Starts ${formatDate(t.startDate)}'
        '${t.venue.isEmpty ? '' : ' at ${t.venue}'}',
  ];

  if (t.isHosted) {
    lines.add(
      t.hasEntryFee
          ? 'Entry fee: ${formatRupees(t.entryFee)} per team'
          : 'Free entry',
    );
    final deadline = t.registrationDeadline;
    if (deadline != null) {
      lines.add('Register by ${formatDate(deadline)}');
    }
  }

  if (t.inviteCode.isNotEmpty) {
    lines.add('');
    lines.add(
      t.isHosted
          ? 'Register in the Play Hub app with invite code '
              '${InviteCode.format(t.inviteCode)}'
          : 'Follow along in the Play Hub app with code '
              '${InviteCode.format(t.inviteCode)}',
    );
  }
  return lines.join('\n');
}
