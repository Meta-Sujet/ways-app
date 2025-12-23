import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../items/item_card.dart';
import '../items/item_details_screen.dart';
import '../favorites/favorites_service.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final friendsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .limit(10);

    return Scaffold(
      appBar: AppBar(title: const Text("Feed")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: friendsQuery.snapshots(),
        builder: (context, friendsSnap) {
          if (friendsSnap.hasError) {
            return Center(child: Text("Error: ${friendsSnap.error}"));
          }
          if (!friendsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final friendDocs = friendsSnap.data!.docs;

          // Build list of friend UIDs + include myself (optional)
          final ownerIds = <String>[
            myUid,
            ...friendDocs.map((d) => d.id),
          ];

          // No friends yet -> show empty state
          if (ownerIds.length == 1) {
            return const Center(
              child: Text("No friends yet. Add friends to see their items."),
            );
          }

          final itemsQuery = FirebaseFirestore.instance
              .collection('items')
              .where('ownerId', whereIn: ownerIds)
              .orderBy('createdAt', descending: true);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: itemsQuery.snapshots(),
            builder: (context, itemsSnap) {
              if (itemsSnap.hasError) {
                return Center(child: Text("Error: ${itemsSnap.error}"));
              }
              if (!itemsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = itemsSnap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No items yet."));
              }

              final favorites = FavoritesService();

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
                  final imageUrl = data['imageUrl']?.toString();

                  return StreamBuilder<bool>(
                    stream: favorites.isFavoriteStream(doc.id),
                    builder: (context, favSnap) {
                      final isFav = favSnap.data == true;

                      return ItemCard(
                        ownerName: ownerName,
                        ownerPhotoUrl: ownerPhotoUrl,
                        title: title,
                        description: description,
                        folder: folder,
                        isExchange: isExchange,
                        priceText: price,
                        imageUrl: imageUrl,
                        isFavorite: isFav,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailsScreen(itemId: doc.id),
                            ),
                          );
                        },
                        onLikeTap: () {}, // next stage
                        onFavoriteTap: () async {
                          await favorites.toggleFavorite(doc.id);
                        },
                      );
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
