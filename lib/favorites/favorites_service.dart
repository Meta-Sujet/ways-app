import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _favRef(String itemId) {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('favorites').doc(itemId);
  }

  Stream<bool> isFavoriteStream(String itemId) {
    return _favRef(itemId).snapshots().map((doc) => doc.exists);
  }

  Future<void> toggleFavorite(String itemId) async {
    final ref = _favRef(itemId);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
