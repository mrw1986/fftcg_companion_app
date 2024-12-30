import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/logging/talker_service.dart';
import '../../models/fftcg_card.dart';
import '../screens/card_detail_screen.dart';
import '../../providers/card_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CardGridItem extends ConsumerWidget {
  final FFTCGCard card;
  final bool useHighRes;
  final TalkerService _talker = TalkerService();

  CardGridItem({
    super.key,
    required this.card,
    this.useHighRes = false,
  });

  Future<String> _getImageUrl(String url) async {
    try {
      if (url.isEmpty) {
        _talker.warning('Empty URL provided for image');
        return FFTCGCard.defaultImageUrl;
      }

      // If the URL is already a full download URL, return it
      if (url.startsWith('https://') && !url.contains('googleapis.com')) {
        return url;
      }

      // Extract the path after 'card-images/'
      final pathMatch = RegExp(r'card-images/(.+)').firstMatch(url);
      if (pathMatch == null) {
        _talker.warning('Invalid image path format: $url');
        return FFTCGCard.defaultImageUrl;
      }

      final imagePath = 'card-images/${pathMatch.group(1)}';

      try {
        final ref = FirebaseStorage.instance.ref(imagePath);
        final downloadUrl = await ref.getDownloadURL();
        _talker.debug('Generated download URL: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        _talker.warning('Error getting Firebase Storage download URL: $e');
        return FFTCGCard.defaultImageUrl;
      }
    } catch (e) {
      _talker.severe('Error processing image URL: $e');
      return FFTCGCard.defaultImageUrl;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheService = ref.watch(cardCacheServiceProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CardDetailScreen(card: card),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero(
                tag: 'card_${card.cardNumber}',
                child: FutureBuilder<String>(
                  future: _getImageUrl(
                    useHighRes
                        ? card.effectiveHighResUrl
                        : card.effectiveLowResUrl,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      _talker.severe('Error loading image: ${snapshot.error}');
                      return _buildErrorWidget(context);
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    return CachedNetworkImage(
                      cacheManager: cacheService.imageCacheManager,
                      imageUrl: snapshot.data!,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 300),
                      placeholder: (context, imageUrl) {
                        _talker.debug(
                          'Loading image for card: ${card.cardNumber} - URL: $imageUrl',
                        );
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorWidget: (context, imageUrl, error) {
                        _talker.severe(
                          'Error loading image for card: ${card.cardNumber}',
                          error,
                        );
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Theme.of(context).colorScheme.error,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Image Not Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                      memCacheHeight: useHighRes ? 1000 : 500,
                      memCacheWidth: useHighRes ? 1000 : 500,
                      useOldImageOnUrlChange: true,
                    );
                  },
                ),
              ),
            ),
            _buildCardInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            'Image Not Available',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleSmall?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
    );
    final subtitleStyle = textTheme.bodySmall?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
    );

    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.name,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (card.cardNumber != null)
                Text(
                  card.cardNumber!,
                  style: subtitleStyle,
                ),
              if (card.cost != null)
                Text(
                  'Cost: ${card.cost}',
                  style: subtitleStyle,
                ),
            ],
          ),
          if (card.elements.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: card.elements.map((element) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    element,
                    style: subtitleStyle?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
