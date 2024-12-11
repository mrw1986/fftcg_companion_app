import 'package:hive_flutter/hive_flutter.dart';
import '../logging/logger_service.dart';
import '../../features/cards/models/fftcg_card.dart';
import '../../features/cards/models/card_extended_data.dart';
import '../../features/cards/models/card_image_metadata.dart';
import '../models/sync_status.dart';

class HiveService {
  static const String cardsBoxName = 'cards';
  static const String userBoxName = 'user';
  static const String syncStatusBoxName = 'sync_status';

  final LoggerService _logger;
  bool _isInitialized = false;

  // Add this getter to expose the initialization status
  bool get isInitialized => _isInitialized;

  HiveService({LoggerService? logger}) : _logger = logger ?? LoggerService();

  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.info('Hive already initialized');
      return;
    }

    try {
      await Hive.initFlutter();

      // Register adapters in a try-catch block
      try {
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(SyncStatusAdapter());
        }
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(FFTCGCardAdapter());
        }
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(CardExtendedDataAdapter());
        }
        if (!Hive.isAdapterRegistered(3)) {
          Hive.registerAdapter(CardImageMetadataAdapter());
        }
      } catch (e) {
        _logger.warning('Error registering adapters: $e');
        // Continue anyway as adapters might already be registered
      }

      // Open boxes with better error handling
      try {
        await Future.wait([
          Hive.openBox<FFTCGCard>(cardsBoxName),
          Hive.openBox(userBoxName),
          Hive.openBox(syncStatusBoxName),
        ]);
      } catch (e) {
        _logger.error('Error opening boxes: $e');
        // Try to delete and recreate boxes
        await Hive.deleteBoxFromDisk(cardsBoxName);
        await Hive.deleteBoxFromDisk(userBoxName);
        await Hive.deleteBoxFromDisk(syncStatusBoxName);

        await Future.wait([
          Hive.openBox<FFTCGCard>(cardsBoxName),
          Hive.openBox(userBoxName),
          Hive.openBox(syncStatusBoxName),
        ]);
      }

      _isInitialized = true;
      _logger.info('Hive initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Hive', e, stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> closeBoxes() async {
    try {
      await Future.wait([
        Hive.box<FFTCGCard>(cardsBoxName).close(),
        Hive.box(userBoxName).close(),
        Hive.box(syncStatusBoxName).close(),
      ]);
      _isInitialized = false;
      _logger.info('Hive boxes closed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error closing Hive boxes', e, stackTrace);
      rethrow;
    }
  }

  Box<FFTCGCard> getCardsBox() {
    if (!_isInitialized) {
      throw StateError('HiveService not initialized. Call initialize() first.');
    }
    final box = Hive.box<FFTCGCard>(cardsBoxName);
    if (!box.isOpen) {
      throw StateError('Cards box is not open');
    }
    return box;
  }

  Box getUserBox() {
    if (!_isInitialized) {
      throw StateError('HiveService not initialized. Call initialize() first.');
    }
    final box = Hive.box(userBoxName);
    if (!box.isOpen) {
      throw StateError('User box is not open');
    }
    return box;
  }

  Box getSyncStatusBox() {
    if (!_isInitialized) {
      throw StateError('HiveService not initialized. Call initialize() first.');
    }
    final box = Hive.box(syncStatusBoxName);
    if (!box.isOpen) {
      throw StateError('Sync status box is not open');
    }
    return box;
  }

  Future<void> clearAll() async {
    try {
      await Future.wait([
        getCardsBox().clear(),
        getUserBox().clear(),
        getSyncStatusBox().clear(),
      ]);
      _logger.info('All Hive boxes cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('Error clearing Hive boxes', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteBoxes() async {
    try {
      await closeBoxes();
      await Future.wait([
        Hive.deleteBoxFromDisk(cardsBoxName),
        Hive.deleteBoxFromDisk(userBoxName),
        Hive.deleteBoxFromDisk(syncStatusBoxName),
      ]);
      _isInitialized = false;
      _logger.info('All Hive boxes deleted successfully');
    } catch (e, stackTrace) {
      _logger.error('Error deleting Hive boxes', e, stackTrace);
      rethrow;
    }
  }

  // Card-specific methods
  Future<void> saveCard(FFTCGCard card) async {
    try {
      final box = getCardsBox();
      await box.put(card.cardNumber, card);
      _logger.info('Card saved successfully: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.error('Error saving card', e, stackTrace);
      rethrow;
    }
  }

  Future<void> saveCards(List<FFTCGCard> cards) async {
    try {
      final box = getCardsBox();
      final cardsMap = {for (var card in cards) card.cardNumber: card};
      await box.putAll(cardsMap);
      _logger.info('${cards.length} cards saved successfully');
    } catch (e, stackTrace) {
      _logger.error('Error saving cards', e, stackTrace);
      rethrow;
    }
  }

  FFTCGCard? getCard(String cardNumber) {
    try {
      final box = getCardsBox();
      return box.get(cardNumber);
    } catch (e, stackTrace) {
      _logger.error('Error getting card', e, stackTrace);
      rethrow;
    }
  }

  List<FFTCGCard> getAllCards() {
    try {
      final box = getCardsBox();
      return box.values.toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting all cards', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCard(String cardNumber) async {
    try {
      final box = getCardsBox();
      await box.delete(cardNumber);
      _logger.info('Card deleted successfully: $cardNumber');
    } catch (e, stackTrace) {
      _logger.error('Error deleting card', e, stackTrace);
      rethrow;
    }
  }

  Future<void> reinitialize() async {
    _isInitialized = false;
    await initialize();
  }
}
