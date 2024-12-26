// lib/features/cards/presentation/widgets/card_list_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../models/fftcg_card.dart';
import '../screens/card_detail_screen.dart';

class CardListItem extends StatelessWidget {
  final FFTCGCard card;
  final double height;

  const CardListItem({
    super.key,
    required this.card,
    this.height = 72.0,
  });

  @override
  Widget build(BuildContext context) {
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
            child: CachedNetworkImage(
              imageUrl: card.lowResUrl,
              fit: BoxFit.contain,
              memCacheWidth: 120,
              memCacheHeight: 168,
              placeholderFadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error),
              ),
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
