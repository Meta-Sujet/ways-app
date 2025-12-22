import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UsernameTakenException implements Exception {}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? user;
  bool isLoading = true;
  String? error;

  AuthProvider() {
    _auth.authStateChanges().listen((u) {
      debugPrint("AUTH STATE => ${u?.uid ?? 'SIGNED OUT'}");
      user = u;
      isLoading = false;
      notifyListeners();
    });
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    error = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      error = _humanMessage(e);
      notifyListeners();
    } catch (_) {
      error = "Something went wrong.";
      notifyListeners();
    }
  }

  Future<void> registerWithUsername({
    required String email,
    required String password,
    required String username,
  }) async {
    error = null;
    notifyListeners();

    final usernameLower = username.trim().toLowerCase();

    // Basic username validation
    final valid = RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(usernameLower);
    if (!valid) {
      error = "Username must be 3–20 chars: a-z, 0-9, underscore.";
      notifyListeners();
      return;
    }

    try {
      // ✅ PRE-CHECK (better UX): if taken, stop BEFORE creating auth user
      final snap = await _db.collection('usernames').doc(usernameLower).get();
      if (snap.exists) {
        error = "Username is taken. Try another.";
        notifyListeners();
        return;
      }

      // 1) Create Auth user (now very likely to succeed)
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;

      // 2) Transaction for safety (still needed)
      await _db.runTransaction((tx) async {
        final usernameRef = _db.collection('usernames').doc(usernameLower);
        final userRef = _db.collection('users').doc(uid);

        final usernameSnap = await tx.get(usernameRef);
        if (usernameSnap.exists) {
          throw UsernameTakenException();
        }

        tx.set(usernameRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(userRef, {
          'email': email.trim(),
          'username': username.trim(),
          'usernameLower': usernameLower,
          'photoUrl': null,
          'setupComplete': false,
          'itemsCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseAuthException catch (e) {
      error = _humanMessage(e);
      notifyListeners();
    } on UsernameTakenException {
      // If it somehow got taken between pre-check and transaction
      try {
        await _auth.currentUser?.delete();
      } catch (_) {}
      error = "Username is taken. Try another.";
      notifyListeners();
    } catch (e, st) {
      debugPrint("REGISTER ERROR => $e");
      debugPrintStack(stackTrace: st);

      // Do NOT delete the auth user for random errors.
      // Keep it logged in so you can retry or fix rules.
      error = "Profile creation failed. Try again.";
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _humanMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email is invalid.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password is too weak (min 6 chars).';
      case 'too-many-requests':
        return 'Too many requests. Try later.';
      default:
        return e.message ?? 'Auth error.';
    }
  }
}
