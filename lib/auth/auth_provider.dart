import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _sub;

  User? user;
  bool isLoading = true;
  String? error;

  bool get isLoggedIn => user != null;

  AuthProvider() {
    _sub = _auth.authStateChanges().listen((u) {
      user = u;
      isLoading = false;
      notifyListeners();
    }, onError: (_) {
      isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    try {
      error = null;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      error = e.message ?? e.code;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    error = null;
    await _auth.signOut();
  }

  Future<void> registerWithUsername({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      error = null;

      final usernameLower = _normalizeUsername(username);
      if (usernameLower.isEmpty) {
        error = "Invalid username.";
        notifyListeners();
        return;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        error = "Failed to create user.";
        notifyListeners();
        return;
      }

      await _db.runTransaction((tx) async {
        final unameRef = _db.collection('usernames').doc(usernameLower);
        final unameSnap = await tx.get(unameRef);

        if (unameSnap.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-taken',
            message: 'Username already taken.',
          );
        }

        tx.set(unameRef, {
          'uid': uid,
          'username': usernameLower,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(_db.collection('public_profiles').doc(uid), {
          'uid': uid,
          'username': usernameLower,
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(_db.collection('users').doc(uid), {
          'email': email,
          'username': usernameLower,
          'photoUrl': null,
          'setupComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseAuthException catch (e) {
      error = e.message ?? e.code;
      notifyListeners();
    } on FirebaseException catch (e) {
      if (e.code == 'username-taken') {
        error = "Username is already taken.";
        await _tryDeleteCurrentUser();
      } else {
        error = e.message ?? e.code;
        await _tryDeleteCurrentUser();
      }
      notifyListeners();
    } catch (e) {
      error = e.toString();
      await _tryDeleteCurrentUser();
      notifyListeners();
    }
  }

  String _normalizeUsername(String input) {
    var u = input.trim().toLowerCase();
    u = u.replaceAll(RegExp(r'\s+'), '');
    u = u.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if (u.length < 3) return '';
    if (u.length > 20) u = u.substring(0, 20);
    return u;
  }

  Future<void> _tryDeleteCurrentUser() async {
    try {
      final u = _auth.currentUser;
      if (u != null) await u.delete();
    } catch (_) {}
  }
}
