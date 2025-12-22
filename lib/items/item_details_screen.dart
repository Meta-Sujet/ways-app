import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../profile/folder_items_screen.dart';

class ItemDetailsScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('items').doc(itemId);

    return Scaffold(
      appBar: AppBar(title: const Text("Item")),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text("Item not found."));
          }

          final ownerId = (data['ownerId'] ?? '').toString();

          final title = (data['title'] ?? '').toString();
          final description = (data['description'] ?? '').toString();

          final folderRaw = (data['folder'] ?? 'General').toString().trim();
          final folder = folderRaw.isEmpty ? 'General' : folderRaw;

          final isExchange = data['isExchange'] == true;
          final price = data['price']?.toString();

          final subtitle = isExchange
              ? "Exchange"
              : (price == null || price.isEmpty ? "For sale" : price);

          final imageUrl = data['imageUrl']?.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // image placeholder for now
                imageUrl == null
                    ? const Icon(Icons.image, size: 60)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                const SizedBox(height: 16),

                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text("$subtitle • $folder"),
                const SizedBox(height: 12),

                // View folder of this user
                SizedBox(
                  width: double.infinity,
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
      ),
    );
  }
}
