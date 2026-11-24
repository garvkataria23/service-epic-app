/// Comprehensive form validators for Service Requirement Submission,
/// Request Editing, and Quote Negotiation.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _phoneRegex = RegExp(
    r'^\+?[0-9\s\-()]{7,18}$',
  );

  static String? requiredText(
    String? value, {
    required String fieldName,
    int minLength = 2,
    int? maxLength,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldName is required.';
    }
    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return '$fieldName must be at most $maxLength characters.';
    }
    return null;
  }

  static String? title(String? value) {
    return requiredText(
      value,
      fieldName: 'Request title',
      minLength: 5,
      maxLength: 90,
    );
  }

  static String? description(String? value) {
    return requiredText(
      value,
      fieldName: 'Detailed requirements',
      minLength: 20,
      maxLength: 1200,
    );
  }

  static String? location(String? value) {
    return requiredText(
      value,
      fieldName: 'Service location',
      minLength: 3,
      maxLength: 120,
    );
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Contact email is required.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address (e.g., name@example.com).';
    }
    return null;
  }

  static String? phone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Contact phone number is required.';
    }
    if (!_phoneRegex.hasMatch(trimmed)) {
      return 'Enter a valid phone number (7–18 digits).';
    }
    return null;
  }

  static String? budgetAmount(
    String? value, {
    required String label,
    double minAllowed = 5,
    double maxAllowed = 100000,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$label is required.';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid numeric amount.';
    }
    if (parsed < minAllowed) {
      return '$label must be at least \$${minAllowed.toStringAsFixed(0)}.';
    }
    if (parsed > maxAllowed) {
      return '$label cannot exceed \$${maxAllowed.toStringAsFixed(0)}.';
    }
    return null;
  }

  static String? budgetRange(String? minVal, String? maxVal) {
    final minNum = double.tryParse(minVal?.trim() ?? '');
    final maxNum = double.tryParse(maxVal?.trim() ?? '');
    if (minNum == null || maxNum == null) return null;
    if (maxNum < minNum) {
      return 'Maximum budget must be greater than or equal to minimum budget.';
    }
    return null;
  }

  static String? preferredDate(DateTime? date) {
    if (date == null) {
      return 'Please select a preferred service date.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today)) {
      return 'Preferred date cannot be in the past.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? cardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Card number is required.';
    if (digits.length < 13 || digits.length > 19) {
      return 'Enter a valid 13–19 digit card number.';
    }
    if (!_luhnCheck(digits)) {
      return 'Invalid card number (failed checksum).';
    }
    return null;
  }

  static String detectCardBrand(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'Mastercard';
    if (digits.startsWith('34') || digits.startsWith('37')) return 'Amex';
    if (digits.startsWith('6')) return 'Discover';
    return 'Card';
  }

  static bool _luhnCheck(String digits) {
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static String? cardExpiry(String? value) {
    final trimmed = value?.trim() ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(trimmed)) {
      return 'Use MM/YY format.';
    }
    final parts = trimmed.split('/');
    final month = int.tryParse(parts[0]) ?? 0;
    final year = 2000 + (int.tryParse(parts[1]) ?? 0);
    if (month < 1 || month > 12) return 'Invalid month (01–12).';
    final now = DateTime.now();
    final expiryEnd = DateTime(year, month + 1, 0);
    if (expiryEnd.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Card has expired.';
    }
    return null;
  }

  static String? cardCvv(String? value) {
    final trimmed = value?.trim() ?? '';
    if (!RegExp(r'^\d{3,4}$').hasMatch(trimmed)) {
      return 'Enter 3 or 4 digit CVV.';
    }
    return null;
  }

  static String? upiId(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'UPI ID is required.';
    if (!RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$').hasMatch(trimmed)) {
      return 'Enter a valid UPI ID (e.g., garv@okaxis).';
    }
    return null;
  }
}
