import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Map<String, dynamic>? _profile;
  bool isProfileLoading = false;
  String? error;

  Map<String, dynamic>? get profile => _profile;

  bool get isSetupComplete {
    final data = _profile;
    if (data == null) return false;
    final setupComplete = data['setupComplete'];
    if (setupComplete is bool) return setupComplete;
    return false;
  }

  void startListeningToProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    stopListening();

    isProfileLoading = true;
    error = null;
    notifyListeners();

    _sub = _db.collection('users').doc(uid).snapshots().listen(
      (snap) {
        _profile = snap.data();
        isProfileLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isProfileLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markSetupCompleteTrue() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'setupComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _profile = null;
    isProfileLoading = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
