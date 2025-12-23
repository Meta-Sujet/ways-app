import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final Set<String> _ids = {};
  bool isLoading = true;
  String? error;

  bool isFav(String itemId) => _ids.contains(itemId);

  void start() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    stop();
    isLoading = true;
    error = null;
    notifyListeners();

    _sub = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .listen((snap) {
      _ids
        ..clear()
        ..addAll(snap.docs.map((d) => d.id));

      isLoading = false;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _ids.clear();
    isLoading = false;
    error = null;
    notifyListeners();
  }

  Future<void> toggle(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('users').doc(uid).collection('favorites').doc(itemId);

    if (_ids.contains(itemId)) {
      await ref.delete();
    } else {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
