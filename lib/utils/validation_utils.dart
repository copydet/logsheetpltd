class ValidationUtils {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName harus diisi';
    }
    return null;
  }

  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName harus diisi';
    }

    if (double.tryParse(value) == null) {
      return '$fieldName harus berupa angka';
    }

    return null;
  }

  static String? validatePositiveNumber(String? value, String fieldName) {
    final numberValidation = validateNumber(value, fieldName);
    if (numberValidation != null) return numberValidation;

    final number = double.parse(value!);
    if (number < 0) {
      return '$fieldName harus berupa angka positif';
    }

    return null;
  }

  static String? validateRange(
    String? value,
    String fieldName,
    double min,
    double max,
  ) {
    final numberValidation = validateNumber(value, fieldName);
    if (numberValidation != null) return numberValidation;

    final number = double.parse(value!);
    if (number < min || number > max) {
      return '$fieldName harus antara $min dan $max';
    }

    return null;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-\s\(\)]+$').hasMatch(phone);
  }
}
