import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  Future<Map<String, dynamic>?> _getPublicProfile(String uid) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('public_profiles').doc(uid).get();
    return doc.data();
  }

  Future<void> acceptRequest({
    required BuildContext context,
    required String myUid,
    required String requestId,
    required String fromUid,
  }) async {
    final db = FirebaseFirestore.instance;
    final reqRef = db.collection('friend_requests').doc(requestId);

    try {
      // 1) Update request FIRST (თუ permissions არ აქვს, აქვე უნდა ჩავარდეს)
      await reqRef.update({
        'status': 'accepted',
      });

      // 2) Read both public profiles (allowed)
      final myProfile = await _getPublicProfile(myUid) ?? {};
      final fromProfile = await _getPublicProfile(fromUid) ?? {};

      final myUsername = (myProfile['username'] ?? '').toString();
      final myPhotoUrl = myProfile['photoUrl']?.toString();

      final fromUsername = (fromProfile['username'] ?? '').toString();
      final fromPhotoUrl = fromProfile['photoUrl']?.toString();

      // 3) Create friends on both sides
      final myFriendRef =
          db.collection('friends').doc(myUid).collection('list').doc(fromUid);
      final theirFriendRef =
          db.collection('friends').doc(fromUid).collection('list').doc(myUid);

      final batch = db.batch();

      batch.set(myFriendRef, {
        'uid': fromUid,
        'username': fromUsername,
        'photoUrl': fromPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(theirFriendRef, {
        'uid': myUid,
        'username': myUsername,
        'photoUrl': myPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request accepted.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Accept failed: $e")),
        );
      }
    }
  }

  Future<void> declineRequest({
    required BuildContext context,
    required String myUid,
    required String requestId,
  }) async {
    final db = FirebaseFirestore.instance;

    try {
      await db.collection('friend_requests').doc(requestId).update({
        'status': 'declined',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request declined.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Decline failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final query = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Friend requests")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No requests."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final requestId = doc.id;
              final fromUid = (data['senderId'] ?? '').toString();

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getPublicProfile(fromUid),
                builder: (context, profSnap) {
                  final prof = profSnap.data ?? {};
                  final fromUsername = (prof['username'] ?? '').toString();

                  return Material(
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(fromUsername.isNotEmpty
                            ? fromUsername[0].toUpperCase()
                            : "?"),
                      ),
                      title: Text(fromUsername.isEmpty ? "(no username)" : fromUsername),
                      subtitle: Text(fromUid),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Decline",
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await declineRequest(
                                context: context,
                                myUid: myUid,
                                requestId: requestId,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: "Accept",
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              await acceptRequest(
                                context: context,
                                myUid: myUid,
                                requestId: requestId,
                                fromUid: fromUid,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
