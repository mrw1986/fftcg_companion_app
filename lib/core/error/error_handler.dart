import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../logging/logger_service.dart';
import 'app_error.dart';

class ErrorHandler {
  final LoggerService _logger;

  ErrorHandler({LoggerService? logger}) : _logger = logger ?? LoggerService();

  Future<T> handleError<T>(
    Future<T> Function() operation, {
    String? context,
    bool shouldRethrow = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final appError = _convertError(error, stackTrace);
      _logger.error(
        '${context ?? 'Operation'} failed: ${appError.message}',
        appError.originalError ?? error,
        stackTrace,
      );

      if (shouldRethrow) {
        throw appError;
      }

      // Return a default value if we shouldn't rethrow
      return _getDefaultValue<T>();
    }
  }

  AppError _convertError(dynamic error, StackTrace stackTrace) {
    if (error is AppError) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return AuthError.fromFirebase(error, stackTrace);
    }

    if (error is FirebaseException) {
      return DatabaseError(
        message: error.message ?? 'Database operation failed',
        code: error.code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return NetworkError.timeout();
    }

    return UnknownError(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  T _getDefaultValue<T>() {
    if (T == int) {
      return 0 as T;
    } else if (T == double) {
      return 0.0 as T;
    } else if (T == bool) {
      return false as T;
    } else if (T == String) {
      return '' as T;
    } else if (T == List) {
      return <dynamic>[] as T;
    } else if (T == Map) {
      return <dynamic, dynamic>{} as T;
    }
    return null as T;
  }
}
