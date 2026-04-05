import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 🔹 Explicitly providing the Client ID found in your project config
  // This prevents crashes (Lost connection to device) when native files are missing/incomplete
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '382033508368-am6cpgl50rolb7188l2tvf88tqgi5gcb.apps.googleusercontent.com',
  );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google sign-in flow
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
    } catch (e) {
      debugPrint("Error during Google Sign-In: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
