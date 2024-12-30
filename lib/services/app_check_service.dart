import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/logging/talker_service.dart';

class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  final TalkerService _talker = TalkerService();
  StreamSubscription<String?>? _tokenSubscription;
  static const String _tokenTimestampKey = 'app_check_token_timestamp';
  static const Duration _tokenRefreshBuffer = Duration(minutes: 30);

  factory AppCheckService() {
    return _instance;
  }

  AppCheckService._internal();

  Future<void> initialize() async {
    try {
      // Initialize App Check with appropriate provider based on build mode
      if (kDebugMode) {
        _talker.info('Initializing App Check in debug mode');
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
        );

        _tokenSubscription = FirebaseAppCheck.instance.onTokenChange.listen(
          _handleTokenRefresh,
          onError: (error) {
            _talker.warning('App Check token refresh error: $error');
          },
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
        );
      }

      _talker.info('App Check service initialized successfully');
    } catch (e) {
      _talker.severe('Failed to initialize App Check service', e);
      if (!kDebugMode) rethrow;
    }
  }

  Future<void> _handleTokenRefresh(String? token) async {
    if (token != null) {
      await _updateTokenTimestamp();
      _talker.info('App Check token refreshed automatically');
    }
  }

  Future<void> _updateTokenTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _tokenTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _talker.warning('Failed to update token timestamp: $e');
    }
  }

  Future<bool> validateToken() async {
    try {
      final needsRefresh = await _needsTokenRefresh();

      if (needsRefresh) {
        _talker.info('Token refresh needed, requesting new token');
        final token = await FirebaseAppCheck.instance.getToken(true);
        if (token != null) {
          await _updateTokenTimestamp();
          return true;
        }
        return false;
      }

      final token = await FirebaseAppCheck.instance.getToken();
      return token != null;
    } catch (e) {
      _talker.severe('Token validation failed: $e');
      return false;
    }
  }

  Future<bool> _needsTokenRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getInt(_tokenTimestampKey);

      if (lastRefresh == null) return true;

      final lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(lastRefresh);
      final timeSinceRefresh = DateTime.now().difference(lastRefreshTime);

      return timeSinceRefresh > _tokenRefreshBuffer;
    } catch (e) {
      _talker.warning('Error checking token refresh need: $e');
      return true;
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _talker.info('App Check service disposed');
  }
}

final appCheckServiceProvider = Provider<AppCheckService>((ref) {
  final service = AppCheckService();
  ref.onDispose(() => service.dispose());
  return service;
});
