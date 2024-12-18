import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

final firebaseServiceProvider = Provider((ref) => FirebaseService());

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _logger = Logger('FirebaseService');

  FirebaseService() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // In development, you might want to print to console
      // In production, this could be integrated with a proper logging service
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  // Collection reference
  CollectionReference get cards => _firestore.collection('cards');

  // Test query to verify connection
  Future<bool> testConnection() async {
    try {
      final snapshot = await cards.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _logger.severe('Firebase connection error: $e');
      return false;
    }
  }

  // Get card by ID
  Future<DocumentSnapshot?> getCard(String cardId) async {
    try {
      return await cards.doc(cardId).get();
    } catch (e) {
      _logger.severe('Error getting card: $e');
      return null;
    }
  }

  // Get paginated cards
  Future<QuerySnapshot> getCards({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query query = cards.orderBy('name').limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      return await query.get();
    } catch (e) {
      _logger.severe('Error getting cards: $e');
      rethrow;
    }
  }

  // Get image URL
  String getImageUrl(String path) {
    try {
      return _storage.ref(path).getDownloadURL().toString();
    } catch (e) {
      _logger.severe('Error getting image URL: $e');
      return '';
    }
  }
}
