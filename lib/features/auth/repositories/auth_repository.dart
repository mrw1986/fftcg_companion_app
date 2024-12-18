import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../services/auth_service.dart';
import '../../../core/logging/logger_service.dart';

class AuthRepository {
  static const String _guestPrefsKey = 'guest_session';
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
    return _authService.isGuestSession();
  }

  Stream<UserModel?> get authStateChanges => _authService.authStateChanges
      .asyncMap((user) => user != null ? _authService.getCurrentUser() : null);

  Future<UserModel?> getCurrentUser() async {
    try {
      // Check for guest session first
      final prefs = await SharedPreferences.getInstance();
      final guestData = prefs.getString(_guestPrefsKey);

      if (guestData != null) {
        _logger.info('Found guest session data');
        try {
          return UserModel.fromJson(guestData);
        } catch (e) {
          _logger.severe('Error parsing guest data', e);
          await prefs.remove(_guestPrefsKey);
        }
      }

      // Check for authenticated user
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
      return await _authService.signInAsGuest();
    } catch (e, stackTrace) {
      _logger.severe('Error signing in as guest in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> linkWithGoogle() async {
    await _authService.linkWithGoogle();
  }

  Future<void> linkWithEmailPassword(String email, String password) async {
    await _authService.linkWithEmailPassword(email, password);
  }

  Future<void> signOut() async {
    try {
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

}
