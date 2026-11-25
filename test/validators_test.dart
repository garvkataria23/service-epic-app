import 'package:flutter_test/flutter_test.dart';
import 'package:service_epic/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('title validation enforces min length', () {
      expect(Validators.title(''), isNotNull);
      expect(Validators.title('Fix'), isNotNull);
      expect(Validators.title('Fix leaking pipe'), isNull);
    });

    test('email validation rejects malformed emails', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('garv@example.com'), isNull);
    });

    test('budgetRange detects max < min', () {
      expect(Validators.budgetRange('200', '100'), isNotNull);
      expect(Validators.budgetRange('100', '200'), isNull);
    });

    test('preferredDate rejects past dates', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(Validators.preferredDate(yesterday), isNotNull);
      expect(Validators.preferredDate(tomorrow), isNull);
    });

    test('strongPassword and PasswordStrength enforce complexity', () {
      expect(Validators.strongPassword('weak'), isNotNull);
      expect(Validators.strongPassword('alllowercase1!'), isNotNull);
      expect(Validators.strongPassword('StrongPass1!'), isNull);

      final weak = PasswordStrength.evaluate('abc');
      expect(weak.label, 'Weak');

      final strong = PasswordStrength.evaluate('StrongPass1!');
      expect(strong.label, 'Strong');
      expect(strong.progress, 1.0);
    });
  });
}
