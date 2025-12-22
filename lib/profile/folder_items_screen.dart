import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../items/item_details_screen.dart';

class FolderItemsScreen extends StatelessWidget {
  final String ownerId;
  final String folderName;

  const FolderItemsScreen({
    super.key,
    required this.ownerId,
    required this.folderName,
  });

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('ownerId', isEqualTo: ownerId)
        .where('folder', isEqualTo: folderName)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
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
            return const Center(child: Text("No items in this folder."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = (data['title'] ?? '').toString();
              final isExchange = data['isExchange'] == true;
              final price = data['price']?.toString();

              final subtitle = isExchange
                  ? "Exchange"
                  : (price == null || price.isEmpty ? "For sale" : price);

              return Material(
                borderRadius: BorderRadius.circular(14),
                elevation: 1,
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailsScreen(itemId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
