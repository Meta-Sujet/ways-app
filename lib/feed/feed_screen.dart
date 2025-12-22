import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../favorites/favorites_service.dart';
import '../items/item_card.dart';
import '../items/item_details_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    // ✅ v1: show only my items (easy to debug). Later -> friends.
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Feed")),
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
            return const Center(child: Text("No items yet. Add one!"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final ownerName = (data['ownerUsername'] ?? 'Unknown').toString();
              final ownerPhotoUrl = data['ownerPhotoUrl']?.toString();

              final title = (data['title'] ?? '').toString();
              final description = data['description']?.toString();

              final folderRaw = (data['folder'] ?? 'General').toString().trim();
              final folder = folderRaw.isEmpty ? 'General' : folderRaw;

              final isExchange = data['isExchange'] == true;
              final price = data['price']?.toString();

              final favorites = FavoritesService();

              return StreamBuilder<bool>(
                stream: favorites.isFavoriteStream(doc.id),
                builder: (context, favSnap) {
                  final isFav = favSnap.data == true;
                  final imageUrl = data['imageUrl']?.toString();
                  return ItemCard(
                    ownerName: ownerName,
                    ownerPhotoUrl: ownerPhotoUrl,
                    title: title,
                    description: description,
                    folder: folder,
                    isExchange: isExchange,
                    priceText: price,
                    isFavorite: isFav,
                    imageUrl: imageUrl,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailsScreen(itemId: doc.id),
                        ),
                      );
                    },
                    onLikeTap: () {
                      // TODO next: likes
                    },
                    onFavoriteTap: () async {
                      await favorites.toggleFavorite(doc.id);
                    },
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
