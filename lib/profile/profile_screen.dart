import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../favorites/favorites_screen.dart';
import '../friends/add_friend_screen.dart';
import '../friends/friends_list_screen.dart';
import '../friends/requests_screen.dart';
import '../friends/sent_request_screen.dart';
import 'folder_items_screen.dart';
import 'user_profile_provider.dart';

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
        title: Consumer<UserProfileProvider>(
          builder: (context, profileProv, _) {
            final username = profileProv.profile?['username']?.toString();
            if (username == null || username.isEmpty)
              return const Text("Profile");
            return Text("Profile: $username");
          },
        ),
        actions: [
          // ✅ Quick access (friends list)
          IconButton(
            tooltip: "Friends",
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),

          // ✅ Everything else in one menu
          PopupMenuButton<_ProfileMenu>(
            tooltip: "More",
            onSelected: (v) {
              switch (v) {
                case _ProfileMenu.favorites:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                  break;

                case _ProfileMenu.addFriend:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                  );
                  break;

                case _ProfileMenu.requests:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RequestsScreen()),
                  );
                  break;
                case _ProfileMenu.sentRequests:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SentRequestsScreen(),
                    ),
                  );
                  break;

                case _ProfileMenu.logout:
                  FirebaseAuth.instance.signOut();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ProfileMenu.favorites,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.star),
                  title: Text("Favorites"),
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenu.addFriend,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_add),
                  title: Text("Add friend"),
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenu.requests,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.mail_outline),
                  title: Text("Requests"),
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenu.sentRequests,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.outbox),
                  title: Text("Sent requests"),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _ProfileMenu.logout,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout),
                  title: Text("Logout"),
                ),
              ),
            ],
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

enum _ProfileMenu { favorites, addFriend, requests, sentRequests, logout }

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
