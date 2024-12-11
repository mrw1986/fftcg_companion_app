import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'error_handler.dart';

final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  final logger = ref.watch(loggerProvider);
  return ErrorHandler(logger: logger);
});
