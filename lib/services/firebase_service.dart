import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logging/talker_service.dart';

final firebaseServiceProvider = Provider((ref) => FirebaseService());

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _talker = TalkerService();

  FirebaseService() {
    _talker.debug('FirebaseService initialized');
  }

  // Collection reference
  CollectionReference get cards => _firestore.collection('cards');

  // Test query to verify connection
  Future<bool> testConnection() async {
    try {
      final snapshot = await cards.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _talker.severe('Firebase connection error', e, stackTrace);
      return false;
    }
  }

  // Get card by ID
  Future<DocumentSnapshot?> getCard(String cardId) async {
    try {
      return await cards.doc(cardId).get();
    } catch (e, stackTrace) {
      _talker.severe('Error getting card', e, stackTrace);
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
    } catch (e, stackTrace) {
      _talker.severe('Error getting cards', e, stackTrace);
      rethrow;
    }
  }

  // Get image URL
  String getImageUrl(String path) {
    try {
      return _storage.ref(path).getDownloadURL().toString();
    } catch (e, stackTrace) {
      _talker.severe('Error getting image URL', e, stackTrace);
      return '';
    }
  }
}
