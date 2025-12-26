import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../profile/folder_items_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailsScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(), // ✅ LIVE updates
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

        final data = snap.data!.data()!;
        final ownerId = (data['ownerId'] ?? '').toString();
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        final isOwner = myUid != null && myUid == ownerId;

        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();

        final folderRaw = (data['folder'] ?? 'General').toString().trim();
        final folder = folderRaw.isEmpty ? 'General' : folderRaw;

        final isExchange = data['isExchange'] == true;
        final price = data['price']?.toString();
        final subtitle =
            isExchange ? "Exchange" : (price == null || price.isEmpty ? "For sale" : price);

        final imageUrl = data['imageUrl']?.toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text("Item"),
            actions: [
              if (isOwner)
                PopupMenuButton<_OwnerMenu>(
                  tooltip: "More",
                  onSelected: (v) async {
                    switch (v) {
                      case _OwnerMenu.edit:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditItemScreen(itemId: itemId),
                          ),
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
              if (imageUrl == null || imageUrl.trim().isEmpty)
                const Icon(Icons.image, size: 60)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              Text(
                title.isEmpty ? "Item" : title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text("$subtitle • $folder"),

              const SizedBox(height: 12),

              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: ownerId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderItemsScreen(
                                ownerId: ownerId,
                                folderName: folder,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.folder_open),
                  label: const Text("View this folder"),
                ),
              ),

              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(description),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _OwnerMenu { edit, delete }
