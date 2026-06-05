import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 🔹 Platform-aware Client IDs
  static const String _webClientId = '382033508368-tgeas4a4nne4o68tkmhachf4uue79od8.apps.googleusercontent.com';
  static const String _iosClientId = '382033508368-am6cpgl50rolb7188l2tvf88tqgi5gcb.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : _iosClientId,
  );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On Web, use the Firebase native popup to avoid google_sign_in plugin issues
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(authProvider);
      } else {
        // 1. Trigger the Google sign-in flow on Mobile
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) return null;

        // 2. Obtain details from the account
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // 3. Create a new credential
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // 4. Sign in to Firebase with the credential
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Error during Google Sign-In: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
