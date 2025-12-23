import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'favorites_items_provider.dart';
import '../items/item_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ✅ Always start here so it works even if AuthGate sync is missing
      context.read<FavoritesItemsProvider>().start();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final favItems = context.watch<FavoritesItemsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: favItems.itemsStream,
        // ✅ makes snapshot.hasData true immediately
        initialData: const [],
        builder: (context, snapshot) {
          if (favItems.error != null) {
            return Center(child: Text("Error: ${favItems.error}"));
          }

          final docs = snapshot.data ?? const [];
          if (docs.isEmpty) {
            // show spinner only while provider is loading
            if (favItems.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text("No favorites yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = (data['title'] ?? data['name'] ?? 'Item').toString();
              final ownerId = (data['ownerId'] ?? '').toString();
              final folder = (data['folder'] ?? 'General').toString();
              final price = data['price'];
              final isGiveaway = (data['isGiveaway'] == true);

              final img = _firstImageUrl(data);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ItemDetailsScreen(itemId: doc.id),
                    ),
                  );
                },
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 84,
                            height: 84,
                            color: Colors.black12,
                            child: img == null
                                ? const Icon(Icons.image_not_supported)
                                : Image.network(
                                    img,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Folder: $folder",
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (isGiveaway)
                                    const Text("Giveaway",
                                        style: TextStyle(fontWeight: FontWeight.bold))
                                  else if (price != null)
                                    Text("Price: $price",
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "owner: $ownerId",
                                style: const TextStyle(color: Colors.black38),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
