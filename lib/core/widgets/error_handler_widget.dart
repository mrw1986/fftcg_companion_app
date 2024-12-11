import 'package:flutter/material.dart';
import '../error/app_error.dart';
import '../utils/error_utils.dart';

class ErrorHandlerWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final Widget? customError;

  const ErrorHandlerWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customError,
  });

  @override
  Widget build(BuildContext context) {
    if (customError != null) {
      return customError!;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(),
              size: 48,
              color: _getErrorColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              ErrorUtils.getUserFriendlyMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getErrorColor(context),
                  ),
            ),
            if (error.code.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Error Code: ${error.code}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    return switch (error) {
      NetworkError _ => Icons.cloud_off,
      AuthError _ => Icons.security,
      ValidationError _ => Icons.warning,
      DatabaseError _ => Icons.storage,
      SyncError _ => Icons.sync_problem,
      _ => Icons.error_outline,
    };
  }

  Color _getErrorColor(BuildContext context) {
    return switch (error) {
      NetworkError _ => Colors.orange,
      AuthError _ => Colors.red,
      ValidationError _ => Colors.yellow,
      DatabaseError _ => Colors.red,
      SyncError _ => Colors.orange,
      _ => Theme.of(context).colorScheme.error,
    };
  }
}
