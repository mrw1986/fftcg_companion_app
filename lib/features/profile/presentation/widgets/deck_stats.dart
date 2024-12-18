import 'package:flutter/material.dart';

class DeckStats extends StatelessWidget {
  final int totalDecks;
  final String? favoriteElement;
  final Map<String, int> elementUsage;

  const DeckStats({
    super.key,
    required this.totalDecks,
    required this.favoriteElement,
    required this.elementUsage,
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
                'Total Decks',
                totalDecks.toString(),
              ),
              if (favoriteElement != null) ...[
                const Divider(),
                _buildStatRow(
                  context,
                  'Favorite Element',
                  favoriteElement!,
                ),
              ],
              const Divider(),
              const Text('Element Usage'),
              const SizedBox(height: 8),
              ...elementUsage.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: LinearProgressIndicator(
                    value: entry.value / totalDecks,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }),
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
