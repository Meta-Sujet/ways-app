import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firends_profile_screen.dart';

class FriendsListScreen extends StatelessWidget {
  const FriendsListScreen({super.key});

  Future<void> _unfriend(BuildContext context, String myUid, String otherUid) async {
    final db = FirebaseFirestore.instance;

    final a = db.collection('friends').doc(myUid).collection('list').doc(otherUid);
    final b = db.collection('friends').doc(otherUid).collection('list').doc(myUid);

    final batch = db.batch();
    batch.delete(a);
    batch.delete(b);
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend removed.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final query = FirebaseFirestore.instance
        .collection('friends')
        .doc(myUid)
        .collection('list')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Friends")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No friends yet."));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final otherUid = doc.id;
              final username = (data['username'] ?? '').toString();
              final photoUrl = data['photoUrl']?.toString();

              return Material(
                borderRadius: BorderRadius.circular(14),
                elevation: 1,
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friendUid: otherUid),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundImage: (photoUrl != null && photoUrl.trim().isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.trim().isEmpty)
                        ? Text(username.isNotEmpty ? username[0].toUpperCase() : "?")
                        : null,
                  ),
                  title: Text(username.isEmpty ? "(no username)" : username),
                  subtitle: Text(otherUid),
                  trailing: IconButton(
                    tooltip: "Remove friend",
                    icon: const Icon(Icons.person_remove),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Remove friend?"),
                          content: Text("Remove ${username.isEmpty ? "this user" : username}?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Remove"),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        await _unfriend(context, myUid, otherUid);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
