import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/logging/logger_service.dart';
import 'features/auth/presentation/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = LoggerService();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('Firebase initialized successfully');
  } catch (e, stackTrace) {
    logger.error('Failed to initialize Firebase', e, stackTrace);
  }

  runApp(
    const ProviderScope(
      child: FFTCGCompanionApp(),
    ),
  );
}

class FFTCGCompanionApp extends StatelessWidget {
  const FFTCGCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFTCG Companion',
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}
