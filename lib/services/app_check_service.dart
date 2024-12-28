// lib/services/app_check_service.dart

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
      // Initialize App Check with appropriate provider
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );

      // Set up token change listener
      _tokenSubscription = FirebaseAppCheck.instance.onTokenChange.listen(
        _handleTokenRefresh,
        onError: (error) {
          _talker.warning('App Check token refresh error: $error');
        },
      );

      // Request initial token
      if (kDebugMode) {
        final token = await FirebaseAppCheck.instance.getToken();
        if (token != null) {
          await _updateTokenTimestamp();
          _talker.info('Initial debug token obtained');
        }
      }

      _talker.info('App Check service initialized successfully');
    } catch (e) {
      _talker.severe('Failed to initialize App Check service: $e');
      rethrow;
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
      // Check if we need to refresh the token
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

      // If we don't need a refresh, verify the existing token
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

  Future<Map<String, dynamic>> getTokenStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getInt(_tokenTimestampKey);
      final hasToken = await FirebaseAppCheck.instance.getToken() != null;

      return {
        'hasValidToken': hasToken,
        'lastRefresh': lastRefresh != null
            ? DateTime.fromMillisecondsSinceEpoch(lastRefresh)
            : null,
        'needsRefresh': await _needsTokenRefresh(),
      };
    } catch (e) {
      _talker.severe('Error getting token status: $e');
      return {
        'hasValidToken': false,
        'lastRefresh': null,
        'needsRefresh': true,
        'error': e.toString(),
      };
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _talker.info('App Check service disposed');
  }
}

// Provider for app-wide access
final appCheckServiceProvider = Provider<AppCheckService>((ref) {
  final service = AppCheckService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider for monitoring token status
final tokenStatusProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final service = ref.watch(appCheckServiceProvider);

  while (true) {
    yield await service.getTokenStatus();
    await Future.delayed(const Duration(minutes: 5));
  }
});
