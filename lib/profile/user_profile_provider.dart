import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? userProfile;
  bool isProfileLoading = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  /// Starts listening to the logged-in user's profile in Firestore.
  void startListeningToProfile() {
    _profileSub?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      userProfile = null;
      isProfileLoading = false;
      notifyListeners();
      return;
    }

    isProfileLoading = true;
    notifyListeners();

    _profileSub = _db.collection('users').doc(uid).snapshots().listen((doc) {
      userProfile = doc.data();
      isProfileLoading = false;
      notifyListeners();
    });
  }

  /// Stop listening (clean up).
  void stopListening() {
    _profileSub?.cancel();
    _profileSub = null;
  }

  /// True when the user has completed the "first item added" setup.
  bool get isSetupComplete => userProfile?['setupComplete'] == true;

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
