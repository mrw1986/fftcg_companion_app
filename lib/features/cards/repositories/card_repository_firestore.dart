import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logging/logger_service.dart';
import '../models/fftcg_card.dart';
import 'models/repository_models.dart';
import 'base_card_repository.dart';

class CardRepositoryFirestore {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  final Map<String, StreamController<List<FFTCGCard>>> _activeStreams = {};
  final Map<String, Query> _queryCache = {};

  CardRepositoryFirestore({
    FirebaseFirestore? firestore,
    LoggerService? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService();

  Future<FFTCGCard?> getCard(String cardNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(BaseCardRepository.collectionName)
          .where('extendedData', arrayContains: {
            'name': 'Number',
            'value': cardNumber,
          })
          .limit(1)
          .get()
          .timeout(BaseCardRepository.defaultTimeout);

      if (querySnapshot.docs.isEmpty) {
        _logger.warning('Card not found: $cardNumber');
        return null;
      }

      if (!CardRepositoryHelper.isValidCardData(querySnapshot.docs.first)) {
        throw CardRepositoryException(
          'Invalid card data for $cardNumber',
          code: 'invalid_card_data',
        );
      }

      return FFTCGCard.fromFirestore(querySnapshot.docs.first);
    } catch (e, stackTrace) {
      _logger.error('Error getting card from Firestore', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to get card $cardNumber',
        stackTrace: stackTrace,
      );
    }
  }

  Stream<List<FFTCGCard>> watchCards(CardQueryOptions options) {
    final streamController = StreamController<List<FFTCGCard>>();
    final queryKey = _generateQueryKey(options);

    _activeStreams[queryKey] = streamController;

    try {
      Query query = _getOrBuildQuery(options);

      // Set up the stream subscription
      final subscription = query.snapshots().listen(
        (snapshot) async {
          try {
            final List<FFTCGCard> cards = [];
            final List<String> processingErrors = [];

            for (final doc in snapshot.docs) {
              try {
                if (!CardRepositoryHelper.isValidCardData(doc)) {
                  continue;
                }

                _logger.info('Processing card document: ${doc.id}');
                final card = FFTCGCard.fromFirestore(doc);
                cards.add(card);
              } catch (e) {
                processingErrors.add('Failed to process card ${doc.id}: $e');
                continue;
              }
            }

            // Log processing summary
            if (processingErrors.isNotEmpty) {
              _logger.warning(
                'Completed processing with ${processingErrors.length} errors',
              );
              for (final error in processingErrors) {
                _logger.warning(error);
              }
            }

            // Apply element filters if specified
            final filteredCards =
                CardRepositoryHelper.filterByElements(cards, options.elements);

            // Add to stream if it's still active
            if (!streamController.isClosed) {
              streamController.add(filteredCards);
            }
          } catch (e, stackTrace) {
            _logger.error('Error processing snapshot', e, stackTrace);
            streamController.addError(e, stackTrace);
          }
        },
        onError: (error, stackTrace) {
          _logger.error('Error in Firestore stream', error, stackTrace);
          streamController.addError(error, stackTrace);
        },
      );

      // Clean up when the stream is cancelled
      streamController.onCancel = () {
        subscription.cancel();
        _activeStreams.remove(queryKey);
        _logger.info('Stream cancelled for query: $queryKey');
      };
    } catch (e, stackTrace) {
      _logger.error('Error setting up Firestore stream', e, stackTrace);
      streamController.addError(e, stackTrace);
    }

    return streamController.stream;
  }

  Future<List<FFTCGCard>> searchCards(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(BaseCardRepository.collectionName)
          .where('cleanName',
              isGreaterThanOrEqualTo: query.toLowerCase().trim())
          .where('cleanName', isLessThan: '${query.toLowerCase().trim()}z')
          .limit(20)
          .get()
          .timeout(BaseCardRepository.defaultTimeout);

      return querySnapshot.docs
          .where((doc) => CardRepositoryHelper.isValidCardData(doc))
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Error searching cards in Firestore', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to search cards',
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<String>> getUniqueFieldValues(String fieldPath) async {
    try {
      final querySnapshot = await _firestore
          .collection(BaseCardRepository.collectionName)
          .get()
          .timeout(BaseCardRepository.defaultTimeout);

      final values = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .expand((card) {
            switch (fieldPath) {
              case 'elements':
                return card.elements;
              case 'cardType':
                return [card.cardType];
              default:
                return [];
            }
          })
          .where((value) => value != null && value.isNotEmpty)
          .toSet()
          .cast<String>()
          .toList();

      values.sort();
      return values;
    } catch (e, stackTrace) {
      _logger.error('Error getting unique field values', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to get unique values for $fieldPath',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> saveCard(FFTCGCard card, String userId) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(card.cardNumber);

      await docRef.set(
        {
          ...card.toMap(),
          'lastModified': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(BaseCardRepository.defaultTimeout);

      _logger.info('Card saved successfully: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.error('Error saving card to Firestore', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to save card ${card.cardNumber}',
        stackTrace: stackTrace,
      );
    }
  }

  Future<BatchOperationResult> saveBatch(
    List<FFTCGCard> cards,
    String userId,
  ) async {
    final processedIds = <String>[];
    final failedIds = <String>[];

    try {
      // Process in batches of 500 (Firestore limit)
      for (var i = 0; i < cards.length; i += 500) {
        final batch = _firestore.batch();
        final end = (i + 500 < cards.length) ? i + 500 : cards.length;
        final currentBatch = cards.sublist(i, end);

        for (final card in currentBatch) {
          if (card.cardNumber == null) {
            failedIds.add('unknown_$i');
            continue;
          }

          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(card.cardNumber);

          batch.set(
            docRef,
            {
              ...card.toMap(),
              'lastModified': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit().timeout(BaseCardRepository.defaultTimeout);
        processedIds.addAll(
          currentBatch
              .where((card) => card.cardNumber != null)
              .map((card) => card.cardNumber!),
        );
      }

      return BatchOperationResult(
        success: failedIds.isEmpty,
        processedIds: processedIds,
        failedIds: failedIds,
      );
    } catch (e, stackTrace) {
      _logger.error('Error saving batch to Firestore', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to save batch of cards',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> deleteCard(String cardNumber, String userId) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(cardNumber);

      await docRef.delete().timeout(BaseCardRepository.defaultTimeout);

      _logger.info('Card deleted successfully: $cardNumber');
    } catch (e, stackTrace) {
      _logger.error('Error deleting card from Firestore', e, stackTrace);
      throw CardRepositoryHelper.wrapError(
        e,
        'Failed to delete card $cardNumber',
        stackTrace: stackTrace,
      );
    }
  }

  Query _getOrBuildQuery(CardQueryOptions options) {
    final queryKey = _generateQueryKey(options);

    if (_queryCache.containsKey(queryKey)) {
      return _queryCache[queryKey]!;
    }

    final query = CardRepositoryHelper.buildBaseQuery(_firestore, options);
    _queryCache[queryKey] = query;
    return query;
  }

  String _generateQueryKey(CardQueryOptions options) {
    return '${options.searchQuery}_${options.cardType}_${options.elements?.join()}_${options.cost}';
  }

  void dispose() {
    for (final controller in _activeStreams.values) {
      controller.close();
    }
    _activeStreams.clear();
    _queryCache.clear();
  }
}
