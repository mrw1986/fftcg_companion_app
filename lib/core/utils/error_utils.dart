import '../error/app_error.dart';
import '../logging/logger_service.dart';
import 'dart:async'; // Add this at the top of error_utils.dart

class ErrorUtils {
  static final LoggerService _logger = LoggerService();

  static AppError handleError(dynamic error, [StackTrace? stackTrace]) {
    _logger.error('Error occurred', error, stackTrace);

    if (error is AppError) {
      return error;
    }

    // Determine error type and convert to appropriate AppError
    final appError = _convertError(error, stackTrace);
    _logger.error(
      'Converted error: ${appError.message}',
      appError.originalError ?? error,
      appError.stackTrace ?? stackTrace,
    );

    return appError;
  }

  static AppError _convertError(dynamic error, StackTrace? stackTrace) {
    if (error is TimeoutException) {
      return NetworkError.timeout();
    }

    if (error is FormatException) {
      return ValidationError(
        message: error.message,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Add more specific error type conversions as needed

    return UnknownError(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static String getUserFriendlyMessage(AppError error) {
    return switch (error) {
      NetworkError _ =>
        'Connection problem. Please check your internet connection and try again.',
      AuthError _ => error.message,
      ValidationError _ => 'Invalid input: ${error.message}',
      DatabaseError _ => 'Database error. Please try again later.',
      SyncError _ =>
        'Sync failed. Your changes will be saved locally and synced later.',
      _ => 'An unexpected error occurred. Please try again.',
    };
  }
}
