class CustomAuthException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;

  CustomAuthException({
    required this.code,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AuthException: $message (Code: $code)';
}
