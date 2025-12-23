import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  String? _firstImageUrl(Map<String, dynamic> data) {
    final v1 = data['imageUrl'];
    if (v1 is String && v1.trim().isNotEmpty) return v1.trim();

    final v2 = data['photoUrl'];
    if (v2 is String && v2.trim().isNotEmpty) return v2.trim();

    final v3 = data['imageUrls'];
    if (v3 is List && v3.isNotEmpty && v3.first is String) return (v3.first as String).trim();

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('items').doc(itemId);

    return Scaffold(
      appBar: AppBar(title: const Text("Item")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text("Item not found."));

          final data = snap.data!.data() ?? {};
          final title = (data['title'] ?? data['name'] ?? 'Item').toString();
          final desc = (data['description'] ?? '').toString();
          final folder = (data['folder'] ?? 'General').toString();
          final price = data['price'];
          final isGiveaway = (data['isGiveaway'] == true);

          final img = _firstImageUrl(data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                const Text("Giveaway", style: TextStyle(fontWeight: FontWeight.bold))
              else if (price != null)
                Text("Price: $price", style: const TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 16),
              if (desc.isNotEmpty) Text(desc),
            ],
          );
        },
      ),
    );
  }
}
