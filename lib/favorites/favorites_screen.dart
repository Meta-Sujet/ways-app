import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../items/item_details_screen.dart';
import 'favorites_items_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ start only once when screen is first shown
    if (!_started) {
      _started = true;
      context.read<FavoritesItemsProvider>().start();
    }
  }

  @override
  void dispose() {
    // optional: stop listening when leaving screen
    // (if you want favorites list to keep updating in background, remove this)
    context.read<FavoritesItemsProvider>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favItems = context.watch<FavoritesItemsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: favItems.itemsStream,
        initialData: const [],
        builder: (context, snapshot) {
          if (favItems.error != null) {
            return Center(child: Text("Error: ${favItems.error}"));
          }

          final docs = snapshot.data ?? const [];

          if (docs.isEmpty) {
            if (favItems.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text("No favorites yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = (data['title'] ?? data['name'] ?? 'Item').toString();
              final ownerId = (data['ownerId'] ?? '').toString();

              return Material(
                borderRadius: BorderRadius.circular(14),
                elevation: 1,
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(ownerId.isEmpty ? doc.id : "owner: $ownerId"),
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
