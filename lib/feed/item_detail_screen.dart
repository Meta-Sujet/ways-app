import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../friends/firends_profile_screen.dart';
// TODO next step: import '../items/edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  String? _firstImageUrl(Map<String, dynamic> data) {
    final v1 = data['imageUrl'];
    if (v1 is String && v1.trim().isNotEmpty) return v1.trim();

    final v2 = data['photoUrl'];
    if (v2 is String && v2.trim().isNotEmpty) return v2.trim();

    final v3 = data['imageUrls'];
    if (v3 is List && v3.isNotEmpty && v3.first is String) {
      return (v3.first as String).trim();
    }

    return null;
  }

  Future<void> _deleteItem(BuildContext context) async {
    await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('items').doc(itemId);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text("Item")),
              body: Center(child: Text("Error: ${snap.error}")),
            );
          }
          if (!snap.hasData) {
            return  Scaffold(
              appBar: AppBar(title: Text("Item")),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.data!.exists) {
            return  Scaffold(
              appBar: AppBar(title: Text("Item")),
              body: Center(child: Text("Item not found.")),
            );
          }

          final data = snap.data!.data() ?? {};
          final ownerId = (data['ownerId'] ?? '').toString();
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwner = (myUid != null && ownerId == myUid);

          final title = (data['title'] ?? data['name'] ?? 'Item').toString();
          final desc = (data['description'] ?? '').toString();
          final folder = (data['folder'] ?? 'General').toString();
          final price = data['price'];
          final isGiveaway = (data['isGiveaway'] == true);

          final img = _firstImageUrl(data);

          return Scaffold(
            appBar: AppBar(
              title: const Text("Item"),
              actions: [
                if (isOwner)
                  PopupMenuButton<_OwnerMenu>(
                    onSelected: (v) async {
                      switch (v) {
                        case _OwnerMenu.edit:
                          // next step: open EditItemScreen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Edit screen: next step")),
                          );
                          break;

                        case _OwnerMenu.delete:
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete post?"),
                              content: const Text("This action can't be undone."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _deleteItem(context);
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _OwnerMenu.edit,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit),
                          title: Text("Edit"),
                        ),
                      ),
                      PopupMenuItem(
                        value: _OwnerMenu.delete,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete),
                          title: Text("Delete"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // owner header (tap -> FriendProfile if not me)
                if (ownerId.isNotEmpty) ...[
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('public_profiles')
                        .doc(ownerId)
                        .get(),
                    builder: (context, ownerSnap) {
                      final p = ownerSnap.data?.data() ?? {};
                      final ownerUsername =
                          (p['username'] ?? (ownerId.isNotEmpty ? ownerId : 'User'))
                              .toString();
                      final ownerPhotoUrl = p['photoUrl']?.toString();
                      final isMe = (myUid != null && ownerId == myUid);

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isMe
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FriendProfileScreen(friendUid: ownerId),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: (ownerPhotoUrl != null &&
                                        ownerPhotoUrl.trim().isNotEmpty)
                                    ? NetworkImage(ownerPhotoUrl)
                                    : null,
                                child: (ownerPhotoUrl == null ||
                                        ownerPhotoUrl.trim().isEmpty)
                                    ? Text(
                                        ownerUsername.isNotEmpty
                                            ? ownerUsername[0].toUpperCase()
                                            : "?",
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isMe ? "$ownerUsername (You)" : ownerUsername,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isMe) const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 18),
                ],

                if (img != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text("Folder: $folder"),

                const SizedBox(height: 10),
                if (isGiveaway)
                  const Text("Giveaway",
                      style: TextStyle(fontWeight: FontWeight.bold))
                else if (price != null)
                  Text("Price: $price",
                      style: const TextStyle(fontWeight: FontWeight.bold)),

                const SizedBox(height: 16),
                if (desc.isNotEmpty) Text(desc),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _OwnerMenu { edit, delete }
