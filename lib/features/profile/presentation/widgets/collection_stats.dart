import 'package:flutter/material.dart';

class CollectionStats extends StatelessWidget {
  final int totalCards;
  final int foilCards;
  final int nonFoilCards;
  final double collectionValue;

  const CollectionStats({
    super.key,
    required this.totalCards,
    required this.foilCards,
    required this.nonFoilCards,
    required this.collectionValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStatRow(
                context,
                'Total Cards',
                totalCards.toString(),
              ),
              const Divider(),
              _buildStatRow(
                context,
                'Foil Cards',
                foilCards.toString(),
              ),
              const Divider(),
              _buildStatRow(
                context,
                'Non-Foil Cards',
                nonFoilCards.toString(),
              ),
              const Divider(),
              _buildStatRow(
                context,
                'Collection Value',
                '\$${collectionValue.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
