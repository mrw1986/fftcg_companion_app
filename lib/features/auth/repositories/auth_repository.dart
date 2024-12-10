import '../../../models/user_model.dart';
import '../services/auth_service.dart';
import '../../../core/logging/logger_service.dart';

class AuthRepository {
  final AuthService _authService;
  final LoggerService _logger;

  Future<bool> isGuestSession() async {
    return _authService.isGuestSession();
  }

  AuthRepository({
    AuthService? authService,
    LoggerService? logger,
  })  : _authService = authService ?? AuthService(),
        _logger = logger ?? LoggerService();

  Stream<UserModel?> get authStateChanges => _authService.authStateChanges
      .asyncMap((user) => user != null ? _authService.getCurrentUser() : null);

  Future<UserModel?> getCurrentUser() async {
    try {
      return await _authService.getCurrentUser();
    } catch (e, stackTrace) {
      _logger.error('Error getting current user in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } catch (e, stackTrace) {
      _logger.error(
          'Error signing in with Google in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _authService.signInWithEmailPassword(email, password);
    } catch (e, stackTrace) {
      _logger.error(
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
      _logger.error(
          'Error registering with email/password in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      return await _authService.signInAsGuest();
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e, stackTrace) {
      _logger.error('Error signing out in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e, stackTrace) {
      _logger.error(
          'Error sending email verification in repository', e, stackTrace);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      await _authService.checkEmailVerification();
    } catch (e, stackTrace) {
      _logger.error(
          'Error checking email verification in repository', e, stackTrace);
      rethrow;
    }
  }

}
