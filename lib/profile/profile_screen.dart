import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../favorites/favorites_screen.dart';
import '../friends/add_friend_screen.dart';
import '../friends/friends_list_screen.dart';
import '../friends/requests_screen.dart';
import 'folder_items_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final query = FirebaseFirestore.instance
        .collection('items')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
    
   
    return Scaffold(
      appBar: AppBar(
        title:  Text("Profile:"),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
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
                          ownerId: uid,
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
