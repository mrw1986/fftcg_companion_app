import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logging/logger_service.dart';
import '../models/fftcg_card.dart';

class CardRepository {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;
  static const String _collectionName = 'cards';

  CardRepository({
    FirebaseFirestore? firestore,
    LoggerService? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService();

  Stream<List<FFTCGCard>> watchCards({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
  }) {
    try {
      Query query = _firestore.collection(_collectionName);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('cleanName', isGreaterThanOrEqualTo: searchQuery)
            .where('cleanName', isLessThan: '${searchQuery}z');
      }

      if (cardType != null) {
        query = query.where('extendedData', arrayContains: {
          'name': 'CardType',
          'value': cardType,
        });
      }

      // Note: Element filtering will need to be done in memory due to Firestore limitations
      // with array-contains queries

      return query.snapshots().map((snapshot) {
        final cards = snapshot.docs
            .map((doc) => FFTCGCard.fromFirestore(doc))
            .where((card) {
          // Apply element filter in memory if specified
          if (elements != null && elements.isNotEmpty) {
            return elements.any((element) => card.elements.contains(element));
          }
          return true;
        }).toList();

        _logger.info('Fetched ${cards.length} cards');
        return cards;
      });
    } catch (e, stackTrace) {
      _logger.error('Error watching cards', e, stackTrace);
      rethrow;
    }
  }

  Future<FFTCGCard?> getCardByNumber(String cardNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('extendedData', arrayContains: {
            'name': 'Number',
            'value': cardNumber,
          })
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _logger.warning('Card not found: $cardNumber');
        return null;
      }

      return FFTCGCard.fromFirestore(querySnapshot.docs.first);
    } catch (e, stackTrace) {
      _logger.error('Error getting card by number', e, stackTrace);
      rethrow;
    }
  }

  Future<List<FFTCGCard>> searchCards(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('cleanName', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('cleanName', isLessThan: '${query.toLowerCase()}z')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Error searching cards', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getUniqueElements() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final elements = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .expand((card) => card.elements)
          .toSet()
          .toList();

      _logger.info('Found ${elements.length} unique elements');
      return elements;
    } catch (e, stackTrace) {
      _logger.error('Error getting unique elements', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getUniqueCardTypes() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final cardTypes = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .map((card) => card.cardType)
          .where((type) => type != null)
          .toSet()
          .cast<String>()
          .toList();

      _logger.info('Found ${cardTypes.length} unique card types');
      return cardTypes;
    } catch (e, stackTrace) {
      _logger.error('Error getting unique card types', e, stackTrace);
      rethrow;
    }
  }

Future<List<FFTCGCard>> getAllCards() async {
    try {
      final querySnapshot = await _firestore.collection(_collectionName).get();
      return querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting all cards', e, stackTrace);
      rethrow;
    }
  }

}
