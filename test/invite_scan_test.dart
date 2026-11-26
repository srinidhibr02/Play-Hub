import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/invite_code.dart';

void main() {
  test('reads a bare code in any style', () {
    expect(InviteCode.fromScan('K7M2QX'), 'K7M2QX');
    expect(InviteCode.fromScan('k7m-2qx'), 'K7M2QX');
    expect(InviteCode.fromScan('  K7M 2QX '), 'K7M2QX');
  });

  test('finds a code inside longer text', () {
    expect(InviteCode.fromScan('Join Play Hub with code K7M-2QX now'), 'K7M2QX');
  });

  test('rejects things that are not invite codes', () {
    expect(InviteCode.fromScan(''), isNull);
    expect(InviteCode.fromScan('https://example.com/page'), isNull);
    expect(InviteCode.fromScan('HELLO WORLD'), isNull);
    // 0, 1, I, L and O are not in the alphabet.
    expect(InviteCode.fromScan('K0M-1QX'), isNull);
  });
}
