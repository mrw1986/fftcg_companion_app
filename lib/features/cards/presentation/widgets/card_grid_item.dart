// lib/features/cards/presentation/widgets/card_grid_item.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                child: CachedNetworkImage(
                  cacheManager: cacheService.imageCacheManager,
                  imageUrl: useHighRes ? card.highResUrl : card.lowResUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) {
                    _talker.debug(
                        'Loading image for card: ${card.cardNumber} - URL: $url');
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorWidget: (context, url, error) {
                    _talker.severe(
                      'Error loading image for card: ${card.cardNumber}',
                      error,
                    );
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 4),
                          Text(
                            'Image Error',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                  memCacheHeight: useHighRes ? 1000 : 500,
                  memCacheWidth: useHighRes ? 1000 : 500,
                ),
              ),
            ),
            _buildCardInfo(context),
          ],
        ),
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
