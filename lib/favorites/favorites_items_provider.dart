import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesItemsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favSub;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _itemSubs = [];

  final StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _itemsCtrl =
      StreamController.broadcast();

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get itemsStream => _itemsCtrl.stream;

  bool isLoading = true;
  String? error;

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _itemsById = {};

  void start() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  stop();
  _itemsCtrl.add([]); // ✅ დაამატე ეს

  isLoading = true;
  error = null;
  notifyListeners();

  _favSub = _db
      .collection('users')
      .doc(uid)
      .collection('favorites')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .listen((snap) {
    final ids = snap.docs.map((d) => d.id).toList();
    _rebuildItemListeners(ids);
  }, onError: (e) {
    error = e.toString();
    isLoading = false;
    notifyListeners();
  });
}

  void _rebuildItemListeners(List<String> itemIds) {
    for (final s in _itemSubs) {
      s.cancel();
    }
    _itemSubs.clear();
    _itemsById.clear();

    if (itemIds.isEmpty) {
      isLoading = false;
      _itemsCtrl.add([]);
      notifyListeners();
      return;
    }

    // Firestore whereIn limit => chunk
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < itemIds.length; i += chunkSize) {
      final end = (i + chunkSize) > itemIds.length ? itemIds.length : (i + chunkSize);
      chunks.add(itemIds.sublist(i, end));
    }

    // 2) listen items by id chunks
    for (final chunk in chunks) {
      final sub = _db
          .collection('items')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          _itemsById[doc.id] = doc;
        }

        // keep favorites order (roughly): sort by createdAt desc (fallback)
        final merged = _itemsById.values.toList();
        merged.sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          return bMillis.compareTo(aMillis);
        });

        isLoading = false;
        _itemsCtrl.add(merged);
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      });

      _itemSubs.add(sub);
    }
  }

  void stop() {
  _favSub?.cancel();
  _favSub = null;

  for (final s in _itemSubs) {
    s.cancel();
  }
  _itemSubs.clear();

  _itemsById.clear();

  _itemsCtrl.add([]); // ✅ დაამატე ეს

  isLoading = false;
  error = null;
  notifyListeners();
}


  @override
  void dispose() {
    stop();
    _itemsCtrl.close();
    super.dispose();
  }
}
