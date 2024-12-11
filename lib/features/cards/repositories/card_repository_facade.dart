// lib/features/cards/repositories/card_repository_facade.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/user_model.dart';
import '../models/fftcg_card.dart';
import 'base_card_repository.dart';
import 'card_repository_local.dart';
import 'card_repository_firestore.dart';
import 'card_repository_sync.dart';
import '../../../core/logging/logger_service.dart';
import 'models/repository_models.dart';

class CardRepository implements BaseCardRepository {
  final CardRepositoryLocal _localRepo;
  final CardRepositoryFirestore _firestoreRepo;
  final CardRepositorySync _syncRepo;
  final LoggerService _logger;

  CardRepository({
    CardRepositoryLocal? localRepo,
    CardRepositoryFirestore? firestoreRepo,
    CardRepositorySync? syncRepo,
    LoggerService? logger,
  })  : _localRepo = localRepo ?? CardRepositoryLocal(),
        _firestoreRepo = firestoreRepo ?? CardRepositoryFirestore(),
        _syncRepo = syncRepo ??
            CardRepositorySync(
              localRepo: localRepo ?? CardRepositoryLocal(),
              firestoreRepo: firestoreRepo ?? CardRepositoryFirestore(),
            ),
        _logger = logger ?? LoggerService() {
    _logger.info('CardRepository initialized');
  }

  @override
  Future<FFTCGCard?> getCard(String cardNumber) async {
    try {
      // Try local first
      final localCard = await _localRepo.getCard(cardNumber);
      if (localCard != null) {
        return localCard;
      }

      // If not found locally, try Firestore
      final remoteCard = await _firestoreRepo.getCard(cardNumber);
      if (remoteCard != null) {
        // Save to local storage for future use
        await _localRepo.saveBatch([remoteCard]);
      }
      return remoteCard;
    } catch (e) {
      _logger.error('Error getting card', e);
      rethrow;
    }
  }

  @override
  Future<List<FFTCGCard>> getCards(CardQueryOptions options) async {
    try {
      // Try local first
      final localCards = await _localRepo.getCards(options);
      if (localCards.isNotEmpty) {
        return localCards;
      }

      // If no local data, try Firestore
      final remoteCards =
          await _firestoreRepo.searchCards(options.searchQuery ?? '');
      if (remoteCards.isNotEmpty) {
        await _localRepo.saveBatch(remoteCards);
      }
      return remoteCards;
    } catch (e) {
      _logger.error('Error getting cards', e);
      rethrow;
    }
  }

  @override
  Stream<List<FFTCGCard>> watchCards(CardQueryOptions options) {
    try {
      return _localRepo.watchCards(options);
    } catch (e) {
      _logger.error('Error watching cards', e);
      rethrow;
    }
  }

  @override
  Future<List<FFTCGCard>> searchCards(String query) async {
    try {
      // Try local search first
      final localResults = await _localRepo.searchCards(query);
      if (localResults.isNotEmpty) {
        return localResults;
      }

      // If no local results, try Firestore
      final remoteResults = await _firestoreRepo.searchCards(query);
      if (remoteResults.isNotEmpty) {
        // Save to local storage for future use
        await _localRepo.saveBatch(remoteResults);
      }
      return remoteResults;
    } catch (e) {
      _logger.error('Error searching cards', e);
      rethrow;
    }
  }

  @override
  Future<BatchOperationResult> saveBatch(List<FFTCGCard> cards) async {
    try {
      // Save locally first
      final localResult = await _localRepo.saveBatch(cards);

      // If local save successful and we have a user ID, sync to Firestore
      if (localResult.success) {
        try {
          final userId = await _getCurrentUserId();
          if (userId != null) {
            await _firestoreRepo.saveBatch(cards, userId);
          }
        } catch (e) {
          _logger.error('Error syncing to Firestore', e);
          // Don't rethrow here - we've already saved locally
        }
      }
      return localResult;
    } catch (e) {
      _logger.error('Error saving batch', e);
      rethrow;
    }
  }

  @override
  Future<BatchOperationResult> deleteBatch(List<String> cardNumbers) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId != null) {
        // Delete from Firestore first
        for (final cardNumber in cardNumbers) {
          await _firestoreRepo.deleteCard(cardNumber, userId);
        }
      }

      // Then delete locally
      // Note: Implement local batch delete in CardRepositoryLocal first
      _logger.warning('Local batch delete not yet implemented');
      return BatchOperationResult(
        success: true,
        processedIds: cardNumbers,
      );
    } catch (e) {
      _logger.error('Error deleting batch', e);
      return BatchOperationResult(
        success: false,
        failedIds: cardNumbers,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<List<String>> getUniqueElements() async {
    try {
      // Try local first
      final localElements = await _localRepo.getUniqueElements();
      if (localElements.isNotEmpty) {
        return localElements;
      }

      // If no local data, get from Firestore
      return await _firestoreRepo.getUniqueFieldValues('elements');
    } catch (e) {
      _logger.error('Error getting unique elements', e);
      rethrow;
    }
  }

  @override
  Future<List<String>> getUniqueCardTypes() async {
    try {
      // Try local first
      final localTypes = await _localRepo.getUniqueCardTypes();
      if (localTypes.isNotEmpty) {
        return localTypes;
      }

      // If no local data, get from Firestore
      return await _firestoreRepo.getUniqueFieldValues('cardType');
    } catch (e) {
      _logger.error('Error getting unique card types', e);
      rethrow;
    }
  }

  @override
  Future<int> getTotalCardCount() async {
    try {
      return await _localRepo.getCardCount();
    } catch (e) {
      _logger.error('Error getting total card count', e);
      rethrow;
    }
  }

  @override
  Future<bool> isCacheValid() async {
    try {
      return await _localRepo.isCacheValid();
    } catch (e) {
      _logger.error('Error checking cache validity', e);
      return false;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _localRepo.clearAll();
    } catch (e) {
      _logger.error('Error clearing cache', e);
      rethrow;
    }
  }

  @override
  Future<void> updateCacheTimestamp() async {
    try {
      await _localRepo.compact();
    } catch (e) {
      _logger.error('Error updating cache timestamp', e);
      rethrow;
    }
  }

  @override
  Future<void> syncCards(List<FFTCGCard> cards) async {
    try {
      await _syncRepo.syncPendingChanges();
    } catch (e) {
      _logger.error('Error syncing cards', e);
      rethrow;
    }
  }

  @override
  Future<bool> needsSync() async {
    try {
      return !await _syncRepo.isDataSynced();
    } catch (e) {
      _logger.error('Error checking sync status', e);
      return true;
    }
  }

  @override
  Future<void> markForSync(List<String> cardNumbers) async {
    try {
      final cards = await Future.wait(
        cardNumbers.map((number) => _localRepo.getCard(number)),
      );

      for (final card in cards) {
        if (card != null) {
          card.markForSync();
          await _localRepo.saveCard(card);
        }
      }
    } catch (e) {
      _logger.error('Error marking cards for sync', e);
      rethrow;
    }
  }

  @override
  Future<bool> exists(String cardNumber) async {
    try {
      final card = await getCard(cardNumber);
      return card != null;
    } catch (e) {
      _logger.error('Error checking if card exists', e);
      return false;
    }
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    try {
      return await _syncRepo.getLastSyncTime();
    } catch (e) {
      _logger.error('Error getting last update time', e);
      return null;
    }
  }

  @override
  Future<T> withErrorHandling<T>({
    required Future<T> Function() operation,
    required CardRepositoryOperation operationType,
    String? context,
    bool shouldRethrow = true,
    T? defaultValue,
    int maxRetries = BaseCardRepository.maxRetryAttempts,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        _logger.error(
          'Operation failed (Attempt $attempts/$maxRetries): ${context ?? operationType}',
          e,
        );
        if (attempts >= maxRetries) {
          if (shouldRethrow) rethrow;
          return defaultValue as T;
        }
        await Future.delayed(
          Duration(seconds: attempts * 2), // Exponential backoff
        );
      }
    }
    throw StateError('Unexpected end of retry loop');
  }

  Future<List<FFTCGCard>> getAllCards() async {
    try {
      return await _localRepo.getCards(const CardQueryOptions());
    } catch (e) {
      _logger.error('Error getting all cards', e);
      rethrow;
    }
  }

  Future<FFTCGCard?> getCardByNumber(String cardNumber) async {
    try {
      return await getCard(cardNumber);
    } catch (e) {
      _logger.error('Error getting card by number', e);
      rethrow;
    }
  }

  // Helper method to get current user ID - implement this based on your auth setup
  Future<String?> _getCurrentUserId() async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser != null) {
        return currentUser.uid;
      }

      // Check for guest session
      final prefs = await SharedPreferences.getInstance();
      final guestData = prefs.getString('guest_session');
      if (guestData != null) {
        final guestUser = UserModel.fromJson(guestData);
        return guestUser.id;
      }

      return null;
    } catch (e, stackTrace) {
      _logger.error('Error getting current user ID', e, stackTrace);
      return null;
    }
  }
}
