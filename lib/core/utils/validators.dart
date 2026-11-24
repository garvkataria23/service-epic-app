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
}
