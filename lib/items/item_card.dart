import 'package:flutter/material.dart';

/// Shows an item as a social feed card:
/// owner (avatar+name), image placeholder (for now), title/desc, like/favorite buttons.
class ItemCard extends StatelessWidget {
  final String ownerName;
  final String? ownerPhotoUrl; // later for network image
  final String title;
  final String? description;
  final String folder;
  final bool isExchange;
  final String? priceText;
  final bool isFavorite;
  final String? imageUrl;

  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onFavoriteTap;

  const ItemCard({
    super.key,
    required this.ownerName,
    required this.ownerPhotoUrl,
    required this.title,
    required this.description,
    required this.folder,
    required this.isExchange,
    required this.priceText,
    required this.onTap,
    required this.onLikeTap,
    required this.onFavoriteTap,
    required this.isFavorite,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isExchange
        ? "Exchange"
        : (priceText == null || priceText!.isEmpty ? "For sale" : priceText!);

    final initial = ownerName.isNotEmpty ? ownerName[0].toUpperCase() : "?";

    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Owner row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    // later: show ownerPhotoUrl
                    child: Text(initial),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ownerName,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    folder,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Container(
              height: 190,
              width: double.infinity,
              color: Colors.black12,
              child: imageUrl == null
                  ? const Icon(Icons.image, size: 54)
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),

            // Content + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(subtitle),
                      const Spacer(),
                      IconButton(
                        onPressed: onLikeTap,
                        icon: const Icon(Icons.favorite_border),
                        tooltip: "Like",
                      ),
                      IconButton(
                        onPressed: onFavoriteTap,
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                        tooltip: "Save",
                      ),
                    ],
                  ),

                  if (description != null &&
                      description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
