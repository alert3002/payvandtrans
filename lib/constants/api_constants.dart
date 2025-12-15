class ApiConstants {
  // Автоматическое определение базового URL в зависимости от платформы
  static String get baseUrl {
    return "https://app.payvandtrans.com";
  }

  // Helper методы для удобства
  static Uri getUri(String path) {
    // Убираем ведущий слэш, если есть, чтобы избежать двойных слэшей
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$cleanPath');
  }

  static String getUrl(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }
}
