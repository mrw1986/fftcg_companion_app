import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_service.dart';
import '../../../core/models/sync_status.dart';
import '../models/fftcg_card.dart';
import 'models/repository_models.dart';
import 'base_card_repository.dart';
import 'card_repository_local.dart';
import 'card_repository_firestore.dart';

class CardRepositorySync {
  final CardRepositoryLocal _localRepo;
  final CardRepositoryFirestore _firestoreRepo;
  final LoggerService _logger;

  final _syncController = StreamController<SyncStatus>.broadcast();
  Timer? _syncTimer;
  bool _isSyncing = false;

  static const Duration _syncInterval = Duration(minutes: 15);
  static const Duration _conflictCacheExpiration = Duration(hours: 24);

  // Keep track of conflict resolutions to avoid asking user repeatedly
  final Map<String, ConflictResolution> _conflictResolutionCache = {};
  final Map<String, DateTime> _lastConflictTime = {};

  CardRepositorySync({
    required CardRepositoryLocal localRepo,
    required CardRepositoryFirestore firestoreRepo,
    LoggerService? logger,
  })  : _localRepo = localRepo,
        _firestoreRepo = firestoreRepo,
        _logger = logger ?? LoggerService();

  Stream<SyncStatus> get syncStatus => _syncController.stream;

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => syncPendingChanges());
    _logger.info('Started periodic sync');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.info('Stopped periodic sync');
  }

  Future<void> syncPendingChanges({String? userId}) async {
    if (_isSyncing) {
      _logger.info('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _syncController.add(SyncStatus.pending);

    List<FFTCGCard> allCards = [];

    try {
      _logger.info('Starting sync of pending changes');

      // Get all cards with pending sync status
      allCards = await _localRepo.getCards(
        const CardQueryOptions(
          useCache: false,
        ),
      );

      final cardsToSync = allCards
          .where((card) => card.syncStatus == SyncStatus.pending)
          .toList();

      if (cardsToSync.isEmpty) {
        _logger.info('No cards need syncing');
        _syncController.add(SyncStatus.synced);
        return;
      }

      _logger.info('Found ${cardsToSync.length} cards to sync');

      // Process in batches
      for (var i = 0;
          i < cardsToSync.length;
          i += BaseCardRepository.defaultBatchSize) {
        final end =
            (i + BaseCardRepository.defaultBatchSize < cardsToSync.length)
                ? i + BaseCardRepository.defaultBatchSize
                : cardsToSync.length;

        final batch = cardsToSync.sublist(i, end);
        await _syncBatch(batch, userId);
      }

      _syncController.add(SyncStatus.synced);
      _logger.info('Sync completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error during sync', e, stackTrace);
      _syncController.add(SyncStatus.error);

      // Mark failed cards with error status
      for (final card in allCards) {
        if (card.syncStatus == SyncStatus.pending) {
          await _localRepo
              .saveBatch([card.copyWith(syncStatus: SyncStatus.error)]);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncBatch(List<FFTCGCard> cards, String? userId) async {
    final resolvedCards = <FFTCGCard>[];

    for (final localCard in cards) {
      try {
        // Skip cards without card numbers
        if (localCard.cardNumber == null) continue;

        // Get remote version if it exists
        final remoteCard = await _firestoreRepo.getCard(localCard.cardNumber!);

        if (remoteCard == null) {
          // No remote version exists, simply upload local version
          resolvedCards.add(localCard);
          continue;
        }

        // Check for conflicts
        if (_hasConflict(localCard, remoteCard)) {
          final resolvedCard = await _resolveConflict(localCard, remoteCard);
          if (resolvedCard != null) {
            resolvedCards.add(resolvedCard);
          }
        } else {
          // No conflict, use newer version
          resolvedCards.add(
            _selectNewerVersion(localCard, remoteCard),
          );
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Error syncing card ${localCard.cardNumber}',
          e,
          stackTrace,
        );
        // Mark individual card as failed
        await _localRepo.saveBatch(
          [localCard.copyWith(syncStatus: SyncStatus.error)],
        );
      }
    }

    if (resolvedCards.isNotEmpty) {
      // Save to Firestore
      if (userId != null) {
        final result = await _firestoreRepo.saveBatch(resolvedCards, userId);
        if (result.success) {
          // Update local versions as synced
          await _localRepo.saveBatch(
            resolvedCards
                .map((card) => card.copyWith(
                      syncStatus: SyncStatus.synced,
                      lastModifiedLocally: null,
                    ))
                .toList(),
          );
        } else {
          _logger.error(
            'Failed to sync cards to Firestore: ${result.failedIds}',
          );
        }
      }
    }
  }

  bool _hasConflict(FFTCGCard localCard, FFTCGCard remoteCard) {
    // Check if both versions have been modified
    if (localCard.lastModifiedLocally == null) return false;
    if (remoteCard.lastModifiedLocally == null) return false;

    // Compare modification times
    return localCard.lastModifiedLocally!
            .difference(remoteCard.lastModifiedLocally!)
            .abs() <
        const Duration(
            seconds: 1); // Consider near-simultaneous changes as conflicts
  }

  FFTCGCard _selectNewerVersion(FFTCGCard localCard, FFTCGCard remoteCard) {
    if (localCard.lastModifiedLocally == null) return remoteCard;
    if (remoteCard.lastModifiedLocally == null) return localCard;

    return localCard.lastModifiedLocally!
            .isAfter(remoteCard.lastModifiedLocally!)
        ? localCard
        : remoteCard;
  }

  Future<FFTCGCard?> _resolveConflict(
    FFTCGCard localCard,
    FFTCGCard remoteCard,
  ) async {
    final cardNumber = localCard.cardNumber!;

    // Check cache for previous resolution
    if (_hasValidCachedResolution(cardNumber)) {
      return _applyResolution(
        localCard,
        remoteCard,
        _conflictResolutionCache[cardNumber]!,
      );
    }

    // Implement your conflict resolution strategy here
    // For now, we'll use a simple "newest wins" strategy
    final resolution = _determineAutoResolution(localCard, remoteCard);

    // Cache the resolution
    _cacheResolution(cardNumber, resolution);

    return _applyResolution(localCard, remoteCard, resolution);
  }

  bool _hasValidCachedResolution(String cardNumber) {
    if (!_conflictResolutionCache.containsKey(cardNumber)) return false;

    final lastConflict = _lastConflictTime[cardNumber];
    if (lastConflict == null) return false;

    return DateTime.now().difference(lastConflict) < _conflictCacheExpiration;
  }

  void _cacheResolution(String cardNumber, ConflictResolution resolution) {
    _conflictResolutionCache[cardNumber] = resolution;
    _lastConflictTime[cardNumber] = DateTime.now();
  }

  ConflictResolution _determineAutoResolution(
    FFTCGCard localCard,
    FFTCGCard remoteCard,
  ) {
    // Compare modification timestamps
    if (localCard.lastModifiedLocally == null ||
        remoteCard.lastModifiedLocally == null) {
      return ConflictResolution.useLocal;
    }

    if (localCard.lastModifiedLocally!
        .isAfter(remoteCard.lastModifiedLocally!)) {
      return ConflictResolution.useLocal;
    } else {
      return ConflictResolution.useRemote;
    }
  }

  FFTCGCard? _applyResolution(
    FFTCGCard localCard,
    FFTCGCard remoteCard,
    ConflictResolution resolution,
  ) {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return localCard;
      case ConflictResolution.useRemote:
        return remoteCard;
      case ConflictResolution.merge:
        return _mergeCards(localCard, remoteCard);
      case ConflictResolution.skip:
        return null;
    }
  }

  FFTCGCard _mergeCards(FFTCGCard localCard, FFTCGCard remoteCard) {
    // Implement your merging logic here
    // For now, we'll use a simple strategy:
    // - Keep the newer metadata (timestamps, sync status)
    // - Preserve local changes for certain fields
    return localCard.copyWith(
      lastModifiedLocally: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  Future<void> revertFailedSync(String cardNumber) async {
    try {
      final card = await _localRepo.getCard(cardNumber);
      if (card != null && card.syncStatus == SyncStatus.error) {
        await _localRepo.saveBatch([
          card.copyWith(
            syncStatus: SyncStatus.pending,
            lastModifiedLocally: DateTime.now(),
          ),
        ]);
      }
    } catch (e, stackTrace) {
      _logger.error('Error reverting failed sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> forceSync(String cardNumber) async {
    try {
      final card = await _localRepo.getCard(cardNumber);
      if (card != null) {
        await _localRepo.saveBatch([
          card.copyWith(
            syncStatus: SyncStatus.pending,
            lastModifiedLocally: DateTime.now(),
          ),
        ]);
        await syncPendingChanges();
      }
    } catch (e, stackTrace) {
      _logger.error('Error forcing sync', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> isDataSynced() async {
    try {
      final cards = await _localRepo.getCards(const CardQueryOptions());
      return !cards.any((card) =>
          card.syncStatus == SyncStatus.pending ||
          card.syncStatus == SyncStatus.error);
    } catch (e, stackTrace) {
      _logger.error('Error checking sync status', e, stackTrace);
      return false;
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
      _logger.error('Error getting last sync time', e, stackTrace);
      return null;
    }
  }

  void clearConflictResolutionCache() {
    _conflictResolutionCache.clear();
    _lastConflictTime.clear();
  }

  void dispose() {
    stopPeriodicSync();
    _syncController.close();
    clearConflictResolutionCache();
  }
}

enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  skip,
}
