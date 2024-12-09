import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logging/logger_service.dart';
import '../../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggerService _logger = LoggerService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.error('Error getting current user', e, stackTrace);
      return null;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return await _createOrUpdateUser(userCredential.user!);
    } catch (e, stackTrace) {
      _logger.error('Error signing in with Google', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return await _createOrUpdateUser(userCredential.user!);
    } catch (e, stackTrace) {
      _logger.error('Error signing in with email/password', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(displayName);

      return await _createOrUpdateUser(userCredential.user!);
    } catch (e, stackTrace) {
      _logger.error('Error registering with email/password', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return await _createOrUpdateUser(
        userCredential.user!,
        isGuest: true,
      );
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest', e, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e, stackTrace) {
      _logger.error('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel> _createOrUpdateUser(User user,
      {bool isGuest = false}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final UserModel userData = UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      isGuest: isGuest,
      lastLoginAt: DateTime.now(),
    );

    try {
      final doc = await userDoc.get();
      if (!doc.exists) {
        await userDoc.set(userData.toMap());
      } else {
        await userDoc.update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      return userData;
    } catch (e, stackTrace) {
      _logger.error('Error creating/updating user', e, stackTrace);
      rethrow;
    }
  }

Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e, stackTrace) {
      _logger.error('Error sending email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e, stackTrace) {
      _logger.error('Error checking email verification', e, stackTrace);
      rethrow;
    }
  }

}
