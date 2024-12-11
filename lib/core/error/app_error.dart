import 'package:firebase_auth/firebase_auth.dart';

abstract class AppError implements Exception {
  final String message;
  final String code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppError({
    required this.message,
    this.code = 'unknown',
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'Error[$code]: $message';
}

class AuthError extends AppError {
  AuthError({
    required super.message,
    super.code = 'auth_error',
    super.originalError,
    super.stackTrace,
  });

  factory AuthError.fromFirebase(dynamic error, [StackTrace? stackTrace]) {
    if (error is FirebaseAuthException) {
      return AuthError(
        message: _getFirebaseAuthErrorMessage(error.code),
        code: error.code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    return AuthError(
      message: 'Authentication failed',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account exists with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'weak-password':
        return 'Please enter a stronger password';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'email-not-verified':
        return 'Please verify your email before signing in';
      default:
        return 'Authentication failed: $code';
    }
  }
}

class NetworkError extends AppError {
  NetworkError({
    required super.message,
    super.code = 'network_error',
    super.originalError,
    super.stackTrace,
  });

  factory NetworkError.noConnection() {
    return NetworkError(
      message: 'No internet connection available',
      code: 'no_connection',
    );
  }

  factory NetworkError.timeout() {
    return NetworkError(
      message: 'Request timed out',
      code: 'timeout',
    );
  }
}

class DatabaseError extends AppError {
  DatabaseError({
    required super.message,
    super.code = 'database_error',
    super.originalError,
    super.stackTrace,
  });
}

class ValidationError extends AppError {
  ValidationError({
    required super.message,
    super.code = 'validation_error',
    super.originalError,
    super.stackTrace,
  });
}

class CacheError extends AppError {
  CacheError({
    required super.message,
    super.code = 'cache_error',
    super.originalError,
    super.stackTrace,
  });
}

class SyncError extends AppError {
  SyncError({
    required super.message,
    super.code = 'sync_error',
    super.originalError,
    super.stackTrace,
  });
}

class UnknownError extends AppError {
  UnknownError({
    required super.message,
    super.code = 'unknown_error',
    super.originalError,
    super.stackTrace,
  });
}
