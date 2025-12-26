import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SentRequestsScreen extends StatelessWidget {
  const SentRequestsScreen({super.key});

  Future<void> cancelRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final query = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Sent requests")),
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
            return const Center(child: Text("No sent requests."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final requestId = doc.id;
              final receiverId = (data['receiverId'] ?? '').toString();

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('public_profiles')
                    .doc(receiverId)
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
                      subtitle: Text(receiverId),
                      trailing: TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Cancel request?"),
                              content: Text("Cancel request to $username?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("No"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            await cancelRequest(requestId);
                          }
                        },
                        child: const Text("Cancel"),
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
