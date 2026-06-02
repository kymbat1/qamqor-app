class AuthValidators {
  static final RegExp _emailRegExp = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  static final RegExp _codeRegExp = RegExp(r'^\d{6}$');

  static bool isValidEmail(String value) {
    return _emailRegExp.hasMatch(value.trim());
  }

  static String normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  static bool isValidPhone(String value) {
    final normalized = normalizePhone(value);
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized);
  }

  static String normalizePhone(String value) {
    final trimmed = value.trim();
    final buffer = StringBuffer();

    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }

    final digits = buffer.toString();
    if (trimmed.startsWith('+')) {
      return '+$digits';
    }
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    return '+$digits';
  }

  static bool isValidCode(String value) {
    return _codeRegExp.hasMatch(value.trim());
  }
}
