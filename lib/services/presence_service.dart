import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> updatePresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // We check both collections because we don't know the role here, 
    // or we could pass it. But checking both is safe.
    
    final userRef = _db.collection('users').doc(user.uid);
    final providerRef = _db.collection('providers').doc(user.uid);

    // Use a helper to check which one exists might be better, 
    // but a try-catch or just updating both is okay for a simple implementation.
    // Actually, we can check the current user's role from our local state if available.
    
    try {
      await userRef.set({
        'isOnline': isOnline, 
        'lastSeen': FieldValue.serverTimestamp()
      }, SetOptions(merge: true)).catchError((_) {});
      
      await providerRef.set({
        'isOnline': isOnline, 
        'lastSeen': FieldValue.serverTimestamp()
      }, SetOptions(merge: true)).catchError((_) {});
    } catch (e) {
      // Ignore errors
    }
  }
}
