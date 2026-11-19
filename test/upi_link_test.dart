import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/payments.dart';

void main() {
  group('Payments.upiPayLink', () {
    test('builds a link with payee, amount and note', () {
      final link = Payments.upiPayLink(
        upiId: 'ravi@okbank',
        payeeName: 'Ravi Kumar',
        amount: 500,
        note: 'City Cup entry',
      );
      expect(
        link,
        'upi://pay?pa=ravi@okbank&pn=Ravi%20Kumar&am=500&cu=INR'
        '&tn=City%20Cup%20entry',
      );
    });

    test('omits the payee name when empty', () {
      final link = Payments.upiPayLink(
        upiId: 'ravi@okbank',
        payeeName: '  ',
        amount: 100,
        note: 'Entry',
      );
      expect(link, 'upi://pay?pa=ravi@okbank&am=100&cu=INR&tn=Entry');
    });

    test('returns null for a bad UPI id or a zero amount', () {
      expect(
        Payments.upiPayLink(
            upiId: 'nope', payeeName: 'A', amount: 100, note: 'x'),
        isNull,
      );
      expect(
        Payments.upiPayLink(
            upiId: 'a@bank', payeeName: 'A', amount: 0, note: 'x'),
        isNull,
      );
    });

    test('escapes characters that would break the link', () {
      final link = Payments.upiPayLink(
        upiId: 'a@bank',
        payeeName: 'A&B',
        amount: 10,
        note: 'x=y',
      )!;
      expect(link, contains('pn=A%26B'));
      expect(link, contains('tn=x%3Dy'));
    });
  });
}
