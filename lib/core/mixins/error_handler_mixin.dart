import 'package:flutter/material.dart';
import '../error/app_error.dart';
import '../utils/error_utils.dart';

mixin ErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  void handleError(AppError error, {VoidCallback? onRetry}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ErrorUtils.getUserFriendlyMessage(error)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> handleAsyncOperation(
    Future<void> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onSuccess,
  }) async {
    try {
      if (loadingMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loadingMessage),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      await operation();

      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }

      onSuccess?.call();
    } catch (error, stackTrace) {
      final appError = ErrorUtils.handleError(error, stackTrace);
      handleError(appError);
    }
  }
}
