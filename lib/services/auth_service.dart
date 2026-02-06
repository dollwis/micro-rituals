import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication service handling Google and Facebook sign-in
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user's UID (null if not logged in)
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (e) {
        if (e.toString().contains('Future already completed')) {
          print('Google Sign-In error: Future already completed. Ignoring.');
          return null;
        }
        rethrow;
      }

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign in with Facebook
  /// Note: Facebook sign-in requires flutter_facebook_auth package
  /// and additional setup. For now, this is a placeholder.
  Future<UserCredential?> signInWithFacebook() async {
    // Facebook sign-in requires more complex setup including:
    // 1. Facebook Developer App configuration
    // 2. flutter_facebook_auth package
    // 3. Platform-specific setup (AndroidManifest.xml, Info.plist)
    // For web, we can use Firebase's built-in popup method
    try {
      final facebookProvider = FacebookAuthProvider();
      facebookProvider.addScope('email');
      facebookProvider.addScope('public_profile');

      // Use popup for web
      return await _auth.signInWithPopup(facebookProvider);
    } catch (e) {
      print('Error signing in with Facebook: $e');
      rethrow;
    }
  }

  /// Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Create specific error for rethrowing or handling in UI
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  /// Create account with Email and Password
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error creating account: $e');
      rethrow;
    }
  }

  /// Sign in anonymously (Guest)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
