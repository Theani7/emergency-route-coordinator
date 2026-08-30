import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize GoogleSignIn for mobile (skip web per firebase-auth skill)
  FirebaseAuthService() {
    if (!kIsWeb) {
      GoogleSignIn.instance.initialize();
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Google Sign-In - handles both Web (popup) and Mobile (authenticate)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        if (googleUser == null) return null; // cancelled

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        // Store/update user profile in Firestore
        await _ensureUserDocument(cred.user);
        return cred;
      }
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Ensure user doc exists in Firestore (for your backend)
  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'photoURL': user.photoURL,
        'role': 'driver', // default, can be updated later
        'createdAt': FieldValue.serverTimestamp(),
        'provider': 'google',
      });
    } else {
      await doc.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'photoURL': user.photoURL,
      });
    }
  }

  /// Email/Password sign-up via Firebase (also creates Firestore doc)
  Future<UserCredential> signUpWithEmail(String email, String password, String name, String role) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(name);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'provider': 'password',
    });
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('SignOut error: $e');
      await _auth.signOut();
    }
  }
}
