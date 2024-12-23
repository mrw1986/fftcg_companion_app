// lib/features/cards/presentation/widgets/card_grid_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../models/fftcg_card.dart';
import '../screens/card_detail_screen.dart';

class CardGridItem extends StatelessWidget {
  final FFTCGCard card;
  final bool useHighRes;

  const CardGridItem({
    super.key,
    required this.card,
    this.useHighRes = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = ResponsiveUtils.isPhone(context);
    final elevation = isPhone ? 2.0 : 4.0;
    final borderRadius = isPhone ? 8.0 : 12.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CardDetailScreen(card: card),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero(
                tag: 'card_${card.cardNumber}',
                child: CachedNetworkImage(
                  imageUrl: useHighRes ? card.highResUrl : card.lowResUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error),
                  ),
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
              Text(
                card.cardNumber ?? '',
                style: subtitleStyle,
              ),
              if (card.cost != null)
                Text(
                  'Cost: ${card.cost}',
                  style: subtitleStyle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
