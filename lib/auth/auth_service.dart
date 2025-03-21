// lib/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart'; // FIX: So we can refresh user data from here
import '../models/user_model.dart';

// Define AuthException
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // SIGN-IN WITH EMAIL + LOAD USER
 Future<void> signInWithEmail(String email, String password, BuildContext context) async {
  try {
    // Sign in the user.
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    print("User signed in: ${_auth.currentUser?.uid}");

    // Get the current Firebase user.
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Reference to the user document in Firestore.
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final userDoc = await userDocRef.get();
      
      // If the user document does not exist, create it.
      if (!userDoc.exists) {
        await userDocRef.set({
          'name': currentUser.email, // Or use a proper name if available
          'role': 'user', // Set a default role
          // Add any additional fields as required.
        });
        print("User document created for UID: ${currentUser.uid}");
      }
      
      // Load the user data into the provider.
      await Provider.of<UserProvider>(context, listen: false).loadCurrentUser(currentUser.uid);
    }
    notifyListeners();

  } on FirebaseAuthException catch (e) {
    // … your error handling …
    throw AuthException('login_failed');
  } catch (e) {
    throw AuthException('login_failed');
  }
}
  // Sign out
  Future<void> signOut(BuildContext context) async {
    await _auth.signOut();
    // Clear the user from provider
    Provider.of<UserProvider>(context, listen: false).clearUser();
    print("User signed out.");
    notifyListeners(); // Notify listeners about sign-out
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
