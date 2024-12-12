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

class SyncService {
  final HiveService _hiveService;
  final LoggerService _logger;
  final Ref _ref;
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService({
    required HiveService hiveService,
    required Ref ref,
    FirebaseFirestore? firestore,
    LoggerService? logger,
    AuthService? authService,
  })  : _hiveService = hiveService,
        _ref = ref,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService(),
        _authService = authService ?? AuthService();

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

  Future<void> syncPendingChanges() async {
    if (_isSyncing) {
      _logger.info('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _logger.info('Starting sync of pending changes');

    try {
      final isGuest = await _authService.isGuestSession();
      if (isGuest) {
        _logger.info('Skipping sync for guest user');
        return;
      }

      final user = _ref.read(currentUserProvider);
      if (user == null) {
        _logger.info('No user logged in, skipping sync');
        return;
      }

      final pendingCards = _hiveService
          .getAllCards()
          .where((card) => card.syncStatus == SyncStatus.pending)
          .toList();

      _logger.info('Found ${pendingCards.length} cards pending sync');

      if (pendingCards.isEmpty) {
        return;
      }

      // Process in batches of 500
      for (var i = 0; i < pendingCards.length; i += 500) {
        var batch = _firestore.batch();
        final end =
            (i + 500 < pendingCards.length) ? i + 500 : pendingCards.length;
        final currentBatch = pendingCards.sublist(i, end);

        final userCardsCollection =
            _firestore.collection('users').doc(user.id).collection('cards');

        for (final card in currentBatch) {
          final docRef = userCardsCollection.doc(card.cardNumber);
          batch.set(
              docRef,
              {
                ...card.toMap(),
                'lastModified': FieldValue.serverTimestamp(),
                'syncStatus': 'synced',
              },
              SetOptions(merge: true));
        }

        await batch.commit();
        await _updateLocalSyncStatus(currentBatch);
      }

      await _updateLastSyncTime();
      _logger.info('Sync completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error during sync', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
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

      // Delete uploaded data
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

      // Reset local sync status
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
      final timestamp = prefs.getInt('last_sync_timestamp');
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
        'last_sync_timestamp',
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
