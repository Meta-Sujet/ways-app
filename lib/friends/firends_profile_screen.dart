import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../profile/folder_items_screen.dart';

class FriendProfileScreen extends StatelessWidget {
  final String friendUid;

  const FriendProfileScreen({
    super.key,
    required this.friendUid,
  });

  Future<void> unfriend(BuildContext context) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final db = FirebaseFirestore.instance;

    final batch = db.batch();

    // remove both sides
    final a = db.collection('friends').doc(myUid).collection('list').doc(friendUid);
    final b = db.collection('friends').doc(friendUid).collection('list').doc(myUid);

    batch.delete(a);
    batch.delete(b);

    await batch.commit();

    if (context.mounted) {
      Navigator.pop(context); // go back after unfriend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unfriended.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    // friend meta
    final friendProfileRef =
        FirebaseFirestore.instance.collection('public_profiles').doc(friendUid);

    // friend items
    final itemsQuery = FirebaseFirestore.instance
        .collection('items')
        .where('ownerId', isEqualTo: friendUid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friend"),
        actions: [
          IconButton(
            tooltip: "Unfriend",
            icon: const Icon(Icons.person_remove),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Remove friend?"),
                  content: const Text("Are you sure you want to unfriend this user?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Unfriend"),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await unfriend(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // header
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: friendProfileRef.get(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final username = (data['username'] ?? 'Unknown').toString();
              final photoUrl = data['photoUrl']?.toString();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          (photoUrl != null && photoUrl.trim().isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                      child: (photoUrl == null || photoUrl.trim().isEmpty)
                          ? Text(username.isNotEmpty ? username[0].toUpperCase() : "?")
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        username,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // folders grid from friend's items
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: itemsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No items yet."));
                }

                final foldersSet = <String>{};
                for (final d in docs) {
                  final raw = (d.data()['folder'] ?? 'General').toString().trim();
                  foldersSet.add(raw.isEmpty ? 'General' : raw);
                }

                final folders = foldersSet.toList()..sort();

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: folders.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, index) {
                      final folderName = folders[index];

                      return _FolderTile(
                        name: folderName,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderItemsScreen(
                                ownerId: friendUid,
                                folderName: folderName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _FolderTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
