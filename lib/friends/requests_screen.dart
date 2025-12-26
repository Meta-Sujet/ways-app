import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  Future<void> acceptRequest({
    required String requestId,
    required String myUid,
    required String senderId,
  }) async {
    final db = FirebaseFirestore.instance;

    // my public snapshot for friend meta on other side
    final mePublic = await db.collection('public_profiles').doc(myUid).get();
    final me = mePublic.data() ?? {};
    final myUsername = (me['username'] ?? '').toString();
    final myPhotoUrl = me['photoUrl']?.toString();

    // sender public snapshot for my side meta
    final senderPublic = await db.collection('public_profiles').doc(senderId).get();
    final s = senderPublic.data() ?? {};
    final senderUsername = (s['username'] ?? '').toString();
    final senderPhotoUrl = s['photoUrl']?.toString();

    final batch = db.batch();

    // 1) mark request accepted (receiver does this -> allowed by rules)
    final reqRef = db.collection('friend_requests').doc(requestId);
    batch.update(reqRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) create friends on both sides (this is what your feed uses)
    final myFriendRef =
        db.collection('friends').doc(myUid).collection('list').doc(senderId);
    final theirFriendRef =
        db.collection('friends').doc(senderId).collection('list').doc(myUid);

    batch.set(myFriendRef, {
      'uid': senderId,
      'username': senderUsername,
      'photoUrl': senderPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(theirFriendRef, {
      'uid': myUid,
      'username': myUsername,
      'photoUrl': myPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineRequest({
    required String requestId,
  }) async {
    final db = FirebaseFirestore.instance;

    // receiver updates status -> allowed by rules
    await db.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    // ✅ top-level friend_requests for me as receiver
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
              final senderId = (data['senderId'] ?? '').toString();

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('public_profiles')
                    .doc(senderId)
                    .get(),
                builder: (context, snap) {
                  final p = snap.data?.data() ?? {};
                  final username = (p['username'] ?? 'Unknown').toString();
                  final photoUrl = p['photoUrl']?.toString();

                  return Material(
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (photoUrl != null && photoUrl.trim().isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                        child: (photoUrl == null || photoUrl.trim().isEmpty)
                            ? Text(username.isNotEmpty ? username[0].toUpperCase() : "?")
                            : null,
                      ),
                      title: Text(username),
                      subtitle: Text(senderId),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Decline",
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await declineRequest(requestId: requestId);
                            },
                          ),
                          IconButton(
                            tooltip: "Accept",
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              await acceptRequest(
                                requestId: requestId,
                                myUid: myUid,
                                senderId: senderId,
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
