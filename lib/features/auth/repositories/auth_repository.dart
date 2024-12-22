import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../services/auth_service.dart';
import '../../../core/logging/logger_service.dart';

class AuthRepository {
  final AuthService _authService;
  final LoggerService _logger;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AuthRepository({
    AuthService? authService,
    LoggerService? logger,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _authService = authService ?? AuthService(),
        _logger = logger ?? LoggerService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<bool> isGuestSession() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      return doc.exists && (doc.data()?['isGuest'] ?? false);
    } catch (e, stackTrace) {
      _logger.severe('Error checking guest session', e, stackTrace);
      return false;
    }
  }

  Stream<UserModel?> get authStateChanges => _auth.authStateChanges().asyncMap(
        (user) async {
          if (user == null) return null;
          try {
            final doc =
                await _firestore.collection('users').doc(user.uid).get();
            if (doc.exists) {
              return UserModel.fromFirestore(doc);
            }
            return null;
          } catch (e, stackTrace) {
            _logger.severe('Error in auth state changes stream', e, stackTrace);
            return null;
          }
        },
      );

  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.severe('Error getting current user', e, stackTrace);
      return null;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } catch (e, stackTrace) {
      _logger.severe(
          'Error signing in with Google in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _authService.signInWithEmailPassword(email, password);
    } catch (e, stackTrace) {
      _logger.severe(
          'Error signing in with email/password in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      return await _authService.registerWithEmailPassword(
        email,
        password,
        displayName,
      );
    } catch (e, stackTrace) {
      _logger.severe(
          'Error registering with email/password in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'guest-session-failed',
          message: 'Failed to create guest session',
        );
      }

      final guestUser = UserModel(
        id: user.uid,
        displayName: 'Guest User',
        isGuest: true,
        isEmailVerified: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(
        {
          ...guestUser.toMap(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _logger.info('Guest session created successfully: ${user.uid}');
      return guestUser;
    } catch (e, stackTrace) {
      _logger.severe('Error signing in as guest in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> linkWithGoogle() async {
    try {
      return await _authService.linkWithGoogle();
    } catch (e, stackTrace) {
      _logger.severe('Error linking with Google', e, stackTrace);
      rethrow;
    }
  }

  Future<void> linkWithEmailPassword(String email, String password) async {
    await _authService.linkWithEmailPassword(email, password);
  }

  Future<void> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      final isGuest = await isGuestSession();

      if (isGuest && currentUser != null) {
        // Clean up guest user data before signing out
        await _firestore.collection('users').doc(currentUser.uid).delete();
        await currentUser.delete();
        _logger.info('Guest user data cleaned up: ${currentUser.uid}');
      }

      await _authService.signOut();
    } catch (e, stackTrace) {
      _logger.severe('Error signing out in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e, stackTrace) {
      _logger.severe(
          'Error sending email verification in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      await _authService.checkEmailVerification();
    } catch (e, stackTrace) {
      _logger.severe(
          'Error checking email verification in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
      _logger.info('User data updated: ${user.id}');
    } catch (e, stackTrace) {
      _logger.severe('Error updating user data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteUserData(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      _logger.info('User data deleted: $userId');
    } catch (e, stackTrace) {
      _logger.severe('Error deleting user data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> convertGuestToPermananet(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        ...user.toMap(),
        'isGuest': false,
        'convertedAt': FieldValue.serverTimestamp(),
      });
      _logger.info('Guest user converted to permanent: ${user.id}');
    } catch (e, stackTrace) {
      _logger.severe('Error converting guest user', e, stackTrace);
      rethrow;
    }
  }
}
