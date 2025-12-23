import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'friends_feed_provider.dart';
import 'item_detail_screen.dart';
import '../favorites/favorites_provider.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _controller = ScrollController();
  bool _loadTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final feed = context.read<FriendsFeedProvider>();

    final nearBottom = _controller.position.pixels >
        (_controller.position.maxScrollExtent - 300);

    if (nearBottom && !_loadTriggered && feed.hasMore && !feed.isLoadingMore) {
      _loadTriggered = true;
      feed.loadMore().whenComplete(() {
        Future.delayed(const Duration(milliseconds: 400), () {
          _loadTriggered = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
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
    final feed = context.watch<FriendsFeedProvider>();
    final favs = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Feed")),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: feed.itemsStream,
        initialData: const [],
        builder: (context, snapshot) {
          if (feed.error != null) {
            return Center(child: Text("Error: ${feed.error}"));
          }

          final docs = snapshot.data ?? const [];

          if (docs.isEmpty) {
            if (feed.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text("No friends posts yet."));
          }

          return ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.all(12),
            itemCount: docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // bottom loader / end
              if (index == docs.length) {
                if (!feed.hasMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Text("No more posts.")),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: feed.isLoadingMore
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final doc = docs[index];
              final data = doc.data();

              final ownerId = (data['ownerId'] ?? '').toString();
              final username = feed.friendName(ownerId);

              final title = (data['title'] ?? data['name'] ?? 'Item').toString();
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
                      builder: (_) => ItemDetailScreen(itemId: doc.id),
                    ),
                  );
                },
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // header (friend)
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : "?",
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                username.isNotEmpty ? username : ownerId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              folder,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // image
                        if (img != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 1.4,
                              child: Image.network(
                                img,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // title
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            if (isGiveaway)
                              const Text(
                                "Giveaway",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              )
                            else if (price != null)
                              Text(
                                "Price: $price",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                            const Spacer(),

                            // favorite
                            IconButton(
                              tooltip: "Favorite",
                              onPressed: () async {
                                await context
                                    .read<FavoritesProvider>()
                                    .toggle(doc.id);
                              },
                              icon: Icon(
                                favs.isFav(doc.id)
                                    ? Icons.star
                                    : Icons.star_border,
                              ),
                            ),

                            const Icon(Icons.chevron_right),
                          ],
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
