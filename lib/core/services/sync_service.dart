// lib/core/services/sync_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/logger_service.dart';
import '../models/sync_status.dart';
import 'hive_service.dart';
import '../../features/cards/models/fftcg_card.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/services/auth_service.dart';
import 'connectivity_service.dart';

class SyncResult {
  final bool success;
  final String? error;
  final int itemsSynced;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    this.error,
    this.itemsSynced = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SyncService {
  final HiveService _hiveService;
  final LoggerService _logger;
  final Ref _ref;
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final ConnectivityService _connectivityService;

  Timer? _syncTimer;
  bool _isSyncing = false;

  static const int _batchSize = 500;
  static const String _lastSyncKey = 'last_sync_timestamp';

  SyncService({
    required HiveService hiveService,
    required Ref ref,
    FirebaseFirestore? firestore,
    LoggerService? logger,
    AuthService? authService,
    ConnectivityService? connectivityService,
  })  : _hiveService = hiveService,
        _ref = ref,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService(),
        _authService = authService ?? AuthService(),
        _connectivityService = connectivityService ?? ConnectivityService();

  void dispose() {
    stopPeriodicSync();
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => syncPendingChanges(),
    );
    _logger.info('Started periodic sync');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.info('Stopped periodic sync');
  }

  Future<SyncResult> syncPendingChanges() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    _logger.info('Starting sync of pending changes');

    try {
      if (!await _connectivityService.hasStableConnection()) {
        return SyncResult(
          success: false,
          error: 'No stable connection available',
        );
      }

      final isGuest = await _authService.isGuestSession();
      if (isGuest) {
        _logger.info('Skipping sync for guest user');
        return SyncResult(
          success: true,
          error: 'Guest user, sync skipped',
        );
      }

      final user = _ref.read(currentUserProvider);
      if (user == null) {
        return SyncResult(
          success: false,
          error: 'No user logged in',
        );
      }

      final pendingCards = _hiveService
          .getAllCards()
          .where((card) => card.syncStatus == SyncStatus.pending)
          .toList();

      _logger.info('Found ${pendingCards.length} cards pending sync');

      if (pendingCards.isEmpty) {
        return SyncResult(success: true);
      }

      // Process in batches
      int totalSynced = 0;
      for (var i = 0; i < pendingCards.length; i += _batchSize) {
        final end = (i + _batchSize < pendingCards.length)
            ? i + _batchSize
            : pendingCards.length;
        final currentBatch = pendingCards.sublist(i, end);

        await _syncBatch(user.id, currentBatch);
        totalSynced += currentBatch.length;
      }

      await _updateLastSyncTime();
      _logger.info('Sync completed successfully');

      return SyncResult(
        success: true,
        itemsSynced: totalSynced,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error during sync', e, stackTrace);
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncBatch(String userId, List<FFTCGCard> cards) async {
    final batch = _firestore.batch();
    final userCardsCollection =
        _firestore.collection('users').doc(userId).collection('cards');

    for (final card in cards) {
      final docRef = userCardsCollection.doc(card.cardNumber);
      batch.set(
        docRef,
        {
          ...card.toMap(),
          'lastModified': FieldValue.serverTimestamp(),
          'syncStatus': 'synced',
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await _updateLocalSyncStatus(cards);
  }

  Future<void> _updateLocalSyncStatus(List<FFTCGCard> cards) async {
    for (final card in cards) {
      card.markSynced();
      await _hiveService.saveCard(card);
    }
  }

  Future<void> revertFailedConversion(String userId) async {
    try {
      _logger.info('Starting conversion revert for user: $userId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      final localCards = _hiveService.getAllCards();
      for (final card in localCards) {
        card.markForSync();
        await _hiveService.saveCard(card);
      }

      _logger.info('Conversion revert completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error reverting conversion', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> isDataSynced() async {
    try {
      final localCards = _hiveService.getAllCards();
      return !localCards.any((card) =>
          card.syncStatus == SyncStatus.pending ||
          card.syncStatus == SyncStatus.error);
    } catch (e, stackTrace) {
      _logger.severe('Error checking sync status', e, stackTrace);
      return false;
    }
  }

  Future<void> resetSyncStatus() async {
    try {
      final localCards = _hiveService.getAllCards();
      for (final card in localCards) {
        card.markForSync();
        await _hiveService.saveCard(card);
      }
      _logger.info('Reset sync status for all cards');
    } catch (e, stackTrace) {
      _logger.severe('Error resetting sync status', e, stackTrace);
      rethrow;
    }
  }

  int getCardCount() {
    try {
      return _hiveService.getAllCards().length;
    } catch (e, stackTrace) {
      _logger.severe('Error getting card count', e, stackTrace);
      return 0;
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e, stackTrace) {
      _logger.severe('Error getting last sync time', e, stackTrace);
      return null;
    }
  }

  Future<void> _updateLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error updating last sync time', e, stackTrace);
    }
  }

  Future<SyncStatus> getSyncStatus() async {
    try {
      final localCards = _hiveService.getAllCards();
      if (localCards.isEmpty) return SyncStatus.synced;

      if (localCards.any((card) => card.syncStatus == SyncStatus.error)) {
        return SyncStatus.error;
      }

      if (localCards.any((card) => card.syncStatus == SyncStatus.pending)) {
        return SyncStatus.pending;
      }

      return SyncStatus.synced;
    } catch (e, stackTrace) {
      _logger.severe('Error getting sync status', e, stackTrace);
      return SyncStatus.error;
    }
  }
}

// Providers
final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return SyncService(
    hiveService: hiveService,
    ref: ref,
    authService: AuthService(),
  );
});

final syncStatusProvider = FutureProvider<bool>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.isDataSynced();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getLastSyncTime();
});

final cardCountProvider = Provider<int>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getCardCount();
});
