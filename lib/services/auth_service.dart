import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update online status
      if (credential.user != null) {
        await _updateOnlineStatus(credential.user!.uid, true);
      }
      
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // After registering, create a user document in Firestore
      await _createUserDocument(userCredential.user!.uid, name, email);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(
    String uid,
    String name,
    String email,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
  }
  
  // Update user's online status
  Future<void> _updateOnlineStatus(String uid, bool status) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': status,
      'lastSeen': status ? null : FieldValue.serverTimestamp(),
    });
  }

  // Set up presence system
  Future<void> setupPresence() async {
    // Get the current user
    final User? user = _auth.currentUser;
    if (user == null) return;
    
    // Set user as online
    await _updateOnlineStatus(user.uid, true);
    
    // Set up offline detection
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // User signed out
        // No need to update status as they're already signed out
      }
    });
  }

  // Sign out
  Future<void> signOut() async {
    // Set user as offline before signing out
    final String? uid = currentUserId;
    if (uid != null) {
      await _updateOnlineStatus(uid, false);
    }
    return await _auth.signOut();
  }
}
