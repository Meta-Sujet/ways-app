import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FriendsFeedProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendsSub;

  // per chunk subscriptions (page1 only is realtime)
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _liveSubs = [];

  final StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _itemsCtrl =
      StreamController.broadcast();
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get itemsStream => _itemsCtrl.stream;

  bool isLoading = true;
  bool isLoadingMore = false;
  String? error;

  /// merged cache for UI
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _itemsById = {};

  /// friend meta for UI
  final Map<String, Map<String, dynamic>> _friendMetaByUid = {};
  String friendName(String uid) => (_friendMetaByUid[uid]?['username'] ?? '').toString();
  String? friendPhotoUrl(String uid) => _friendMetaByUid[uid]?['photoUrl']?.toString();

  /// current friends set (for filtering + instant removal on unfriend)
  Set<String> _friendIdsSet = {};

  /// pagination
  final int pageSize = 30;
  List<List<String>> _chunks = [];
  final Map<int, DocumentSnapshot<Map<String, dynamic>>?> _lastDocByChunk = {};
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  /// Track which ids came from FIRST PAGE live for each chunk.
  /// This lets us "replace" page1 data instead of merge-only (so removed docs disappear).
  final Map<int, Set<String>> _page1IdsByChunk = {};

  void start() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    stop();

    isLoading = true;
    isLoadingMore = false;
    error = null;
    _hasMore = true;
    notifyListeners();

    _friendsSub = _db
        .collection('friends')
        .doc(myUid)
        .collection('list')
        .snapshots()
        .listen((snap) {
      // Build new set + meta
      final newMeta = <String, Map<String, dynamic>>{};
      final newIds = <String>{};

      for (final d in snap.docs) {
        newMeta[d.id] = d.data();
        newIds.add(d.id);
      }

      // Update meta
      _friendMetaByUid
        ..clear()
        ..addAll(newMeta);

      // ✅ IMPORTANT: instantly remove posts that no longer belong to friends
      // (unfriend should remove from feed immediately)
      final removedFriends = _friendIdsSet.difference(newIds);
      if (removedFriends.isNotEmpty) {
        _itemsById.removeWhere((_, doc) {
          final ownerId = (doc.data()['ownerId'] ?? '').toString();
          return removedFriends.contains(ownerId);
        });
        _emitSorted(); // immediate UI update
      }

      _friendIdsSet = newIds;

      // Rebuild feed listeners based on new friends list
      final friendIds = newIds.toList();
      _rebuild(friendIds);
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  void _rebuild(List<String> friendIds) {
    // cancel old listeners FIRST to avoid late events re-filling cache
    for (final s in _liveSubs) {
      s.cancel();
    }
    _liveSubs.clear();

    _chunks = [];
    _lastDocByChunk.clear();
    _page1IdsByChunk.clear();
    _hasMore = true;

    // also drop any cached items not belonging to current friends set
    _itemsById.removeWhere((_, doc) {
      final ownerId = (doc.data()['ownerId'] ?? '').toString();
      return !_friendIdsSet.contains(ownerId);
    });

    if (friendIds.isEmpty) {
      isLoading = false;
      _itemsCtrl.add([]);
      notifyListeners();
      return;
    }

    // chunk friends to satisfy whereIn limit
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < friendIds.length; i += chunkSize) {
      final end = (i + chunkSize) > friendIds.length ? friendIds.length : (i + chunkSize);
      chunks.add(friendIds.sublist(i, end));
    }
    _chunks = chunks;

    isLoading = true;
    notifyListeners();

    _startLiveFirstPage();
  }

  void _startLiveFirstPage() {
    if (_chunks.isEmpty) return;

    for (var i = 0; i < _chunks.length; i++) {
      final chunk = _chunks[i];

      final sub = _db
          .collection('items')
          .where('ownerId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .snapshots()
          .listen((snap) {
        // cache last doc for pagination
        _lastDocByChunk[i] = snap.docs.isNotEmpty ? snap.docs.last : null;

        // ✅ REPLACE page1 docs for this chunk (not merge-only)
        // remove old page1 docs of this chunk from cache
        final oldIds = _page1IdsByChunk[i];
        if (oldIds != null && oldIds.isNotEmpty) {
          for (final id in oldIds) {
            _itemsById.remove(id);
          }
        }

        // set new ids
        final newIds = <String>{};

        for (final doc in snap.docs) {
          final ownerId = (doc.data()['ownerId'] ?? '').toString();

          // Safety: if friend list changed quickly, ignore docs from non-friends
          if (!_friendIdsSet.contains(ownerId)) continue;

          _itemsById[doc.id] = doc;
          newIds.add(doc.id);
        }

        _page1IdsByChunk[i] = newIds;

        _emitSorted();
        isLoading = false;
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      });

      _liveSubs.add(sub);
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore) return;
    if (!_hasMore) return;
    if (_chunks.isEmpty) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      bool anyAdded = false;

      for (var i = 0; i < _chunks.length; i++) {
        final chunk = _chunks[i];
        final last = _lastDocByChunk[i];

        // no more for this chunk
        if (last == null) continue;

        final q = await _db
            .collection('items')
            .where('ownerId', whereIn: chunk)
            .orderBy('createdAt', descending: true)
            .startAfterDocument(last)
            .limit(pageSize)
            .get();

        if (q.docs.isNotEmpty) {
          anyAdded = true;
          _lastDocByChunk[i] = q.docs.last;

          for (final doc in q.docs) {
            final ownerId = (doc.data()['ownerId'] ?? '').toString();
            if (!_friendIdsSet.contains(ownerId)) continue; // safety
            _itemsById[doc.id] = doc;
          }
        } else {
          _lastDocByChunk[i] = null;
        }
      }

      if (!anyAdded) {
        _hasMore = false;
      }

      _emitSorted();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void _emitSorted() {
    final merged = _itemsById.values.toList();
    merged.sort((a, b) {
      final aTs = a.data()['createdAt'];
      final bTs = b.data()['createdAt'];
      final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
      final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
      return bMillis.compareTo(aMillis);
    });
    _itemsCtrl.add(merged);
  }

  void stop() {
    _friendsSub?.cancel();
    _friendsSub = null;

    for (final s in _liveSubs) {
      s.cancel();
    }
    _liveSubs.clear();

    _chunks = [];
    _lastDocByChunk.clear();
    _page1IdsByChunk.clear();

    _itemsById.clear();
    _friendMetaByUid.clear();
    _friendIdsSet = {};

    isLoading = false;
    isLoadingMore = false;
    error = null;
    _hasMore = true;

    _itemsCtrl.add([]);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _itemsCtrl.close();
    super.dispose();
  }
}
