import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/fftcg_card.dart';
import '../screens/card_detail_screen.dart';

class CardListItem extends StatelessWidget {
  final FFTCGCard card;

  const CardListItem({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CardDetailScreen(card: card),
            ),
          );
        },
        leading: Hero(
          tag: 'card_${card.cardNumber}',
          child: SizedBox(
            width: 50,
            child: CachedNetworkImage(
              imageUrl: card.lowResUrl,
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
        title: Text(card.name),
        subtitle: Row(
          children: [
            Text(card.cardNumber ?? ''),
            if (card.elements.isNotEmpty) ...[
              const SizedBox(width: 8),
              ...card.elements.map(
                (element) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    element,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (card.cost != null)
              Text(
                'Cost: ${card.cost}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (card.power != null)
              Text(
                'Power: ${card.power}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
