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

  // current favorite IDs (source of truth)
  Set<String> _favIdsSet = {};

  // keep uid for optional cleanup deletes
  String? _uid;

  void start() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _uid = uid;

    stop(clearUid: false);
    _itemsCtrl.add([]);

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
      final newIds = snap.docs.map((d) => d.id).toSet();

      // ✅ remove items from cache if they are no longer favorited
      final removed = _favIdsSet.difference(newIds);
      if (removed.isNotEmpty) {
        for (final id in removed) {
          _itemsById.remove(id);
        }
      }

      _favIdsSet = newIds;

      _rebuildItemListeners(_favIdsSet.toList());
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

    // also ensure cache only contains current favorites
    _itemsById.removeWhere((id, _) => !_favIdsSet.contains(id));

    if (itemIds.isEmpty) {
      isLoading = false;
      _itemsCtrl.add([]);
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < itemIds.length; i += chunkSize) {
      final end = (i + chunkSize) > itemIds.length ? itemIds.length : (i + chunkSize);
      chunks.add(itemIds.sublist(i, end));
    }

    // Listen items by id in chunks
    for (final chunk in chunks) {
      final sub = _db
          .collection('items')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .listen((snap) async {
        // ✅ REPLACE docs for this chunk:
        // first remove chunk ids from cache, then add back what exists
        for (final id in chunk) {
          _itemsById.remove(id);
        }

        // add existing docs
        for (final doc in snap.docs) {
          // only keep if still favorited
          if (_favIdsSet.contains(doc.id)) {
            _itemsById[doc.id] = doc;
          }
        }

        // ✅ OPTIONAL: cleanup dangling favorites (item deleted)
        // if an id is favorited but not returned by Firestore, it likely doesn't exist anymore.
        // We'll delete that favorite record to keep db clean.
        final returnedIds = snap.docs.map((d) => d.id).toSet();
        final missing = chunk.where((id) => _favIdsSet.contains(id) && !returnedIds.contains(id)).toList();

        if (missing.isNotEmpty && _uid != null) {
          final batch = _db.batch();
          for (final id in missing) {
            batch.delete(
              _db.collection('users').doc(_uid).collection('favorites').doc(id),
            );
          }
          try {
            await batch.commit();
          } catch (_) {
            // ignore cleanup failures (non-critical)
          }
        }

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

  void stop({bool clearUid = true}) {
    _favSub?.cancel();
    _favSub = null;

    for (final s in _itemSubs) {
      s.cancel();
    }
    _itemSubs.clear();

    _itemsById.clear();
    _favIdsSet = {};

    if (clearUid) _uid = null;

    _itemsCtrl.add([]);

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
