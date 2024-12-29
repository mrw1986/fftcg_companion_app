import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/logging/talker_service.dart';
import '../../models/fftcg_card.dart';
import '../screens/card_detail_screen.dart';
import '../../providers/card_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CardListItem extends ConsumerWidget {
  final FFTCGCard card;
  final double height;
  final TalkerService _talker = TalkerService();

  CardListItem({
    super.key,
    required this.card,
    this.height = 72.0,
  });

  Future<String> _getImageUrl(String url) async {
    try {
      if (url.isEmpty) {
        _talker.warning('Empty URL provided for image');
        return FFTCGCard.defaultImageUrl;
      }

      if (!url.contains('firebasestorage')) return url;

      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        return await ref.getDownloadURL();
      } catch (e) {
        _talker.severe('Error getting Firebase Storage URL: $e');
        return FFTCGCard.defaultImageUrl;
      }
    } catch (e) {
      _talker.severe('Error getting image URL: $e');
      return FFTCGCard.defaultImageUrl;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheService = ref.watch(cardCacheServiceProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final imageSize = isDesktop ? 80.0 : 60.0;
    final elevation = ResponsiveUtils.isPhone(context) ? 2.0 : 4.0;

    return Card(
      elevation: elevation,
      margin: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.isPhone(context) ? 4.0 : 8.0,
        horizontal: ResponsiveUtils.getResponsivePadding(context).horizontal,
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CardDetailScreen(card: card),
            ),
          );
        },
        contentPadding: EdgeInsets.all(
          ResponsiveUtils.isPhone(context) ? 8.0 : 12.0,
        ),
        leading: Hero(
          tag: 'card_${card.cardNumber}',
          child: SizedBox(
            width: imageSize,
            child: FutureBuilder<String>(
              future: _getImageUrl(card.effectiveLowResUrl),
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
                  placeholder: (context, url) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorWidget: (context, url, error) {
                    _talker.severe(
                      'Error loading list image for card: ${card.cardNumber}',
                      error,
                    );
                    return _buildErrorWidget(context);
                  },
                  useOldImageOnUrlChange: true,
                );
              },
            ),
          ),
        ),
        title: Text(
          card.name,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
          ),
        ),
        subtitle: _buildSubtitle(context),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Theme.of(context).colorScheme.error),
          Text(
            'No Image',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.cardNumber != null)
          Text(card.cardNumber!, style: subtitleStyle),
        if (card.elements.isNotEmpty)
          Row(
            children: card.elements.map((element) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  element,
                  style: subtitleStyle.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final isTabletOrLarger = !ResponsiveUtils.isPhone(context);
    final trailingStyle = TextStyle(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (card.cost != null)
          Text(
            'Cost: ${card.cost}',
            style: trailingStyle,
          ),
        if (card.power != null && isTabletOrLarger)
          Text(
            'Power: ${card.power}',
            style: trailingStyle,
          ),
      ],
    );
  }
}
