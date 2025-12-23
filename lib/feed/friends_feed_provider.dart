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

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _itemsById = {};

  // friend meta for UI
  final Map<String, Map<String, dynamic>> _friendMetaByUid = {};
  String friendName(String uid) => (_friendMetaByUid[uid]?['username'] ?? '').toString();
  String? friendPhotoUrl(String uid) => _friendMetaByUid[uid]?['photoUrl']?.toString();

  // pagination
  final int pageSize = 30;
  List<List<String>> _chunks = [];
  final Map<int, DocumentSnapshot<Map<String, dynamic>>?> _lastDocByChunk = {};
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  void start() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    stop();

    isLoading = true;
    isLoadingMore = false;
    error = null;
    _hasMore = true;
    notifyListeners();

    // listen friends list
    _friendsSub = _db
        .collection('friends')
        .doc(myUid)
        .collection('list')
        .snapshots()
        .listen((snap) {
      _friendMetaByUid.clear();
      for (final d in snap.docs) {
        _friendMetaByUid[d.id] = d.data();
      }

      final friendIds = snap.docs.map((d) => d.id).toList();
      _buildChunks(friendIds);
      _startLiveFirstPage();
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  void _buildChunks(List<String> friendIds) {
    _itemsById.clear();
    _lastDocByChunk.clear();
    _hasMore = true;

    // cancel old live
    for (final s in _liveSubs) {
      s.cancel();
    }
    _liveSubs.clear();

    if (friendIds.isEmpty) {
      _chunks = [];
      isLoading = false;
      _itemsCtrl.add([]);
      notifyListeners();
      return;
    }

    const chunkSize = 10; // whereIn limit safety
    final chunks = <List<String>>[];
    for (var i = 0; i < friendIds.length; i += chunkSize) {
      final end = (i + chunkSize) > friendIds.length ? friendIds.length : (i + chunkSize);
      chunks.add(friendIds.sublist(i, end));
    }
    _chunks = chunks;
  }

  void _startLiveFirstPage() {
    if (_chunks.isEmpty) return;

    // first page should be live (snapshots)
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
        if (snap.docs.isNotEmpty) {
          _lastDocByChunk[i] = snap.docs.last;
        } else {
          _lastDocByChunk[i] = null;
        }

        // merge docs
        for (final doc in snap.docs) {
          _itemsById[doc.id] = doc;
        }

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

        // if we never got a first page, skip
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
            _itemsById[doc.id] = doc;
          }
        } else {
          // no more for this chunk
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
    _itemsById.clear();
    _friendMetaByUid.clear();

    isLoading = false;
    isLoadingMore = false;
    error = null;
    _hasMore = true;

    // push empty so UI doesn't hang
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
