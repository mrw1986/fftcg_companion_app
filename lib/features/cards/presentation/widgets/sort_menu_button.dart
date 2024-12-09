import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_filter_options.dart';
import '../../providers/card_providers.dart';
import '../../../../core/logging/logger_service.dart';

class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(cardNotifierProvider);
    final currentSort =
        cardState.filterOptions?.sortOption ?? CardSortOption.setNumber;
    final isAscending = cardState.filterOptions?.ascending ?? true;
    final logger = LoggerService();

    return PopupMenuButton<(CardSortOption, bool)>(
      initialValue: (currentSort, isAscending),
      tooltip: 'Sort cards',
      icon: const Icon(Icons.sort),
      onSelected: (value) {
        logger.info(
            'Changing sort option to: ${value.$1}, ascending: ${value.$2}');
        final currentFilters =
            cardState.filterOptions ?? const CardFilterOptions();
        ref.read(cardNotifierProvider.notifier).updateFilters(
              currentFilters.copyWith(
                sortOption: value.$1,
                ascending: value.$2,
              ),
            );
      },
      itemBuilder: (BuildContext context) => [
        ..._buildSortMenuItem(
          'Set Number',
          CardSortOption.setNumber,
          currentSort,
          isAscending,
          showAscDesc: false,
        ),
        const PopupMenuDivider(),
        ..._buildSortMenuItem(
          'Name',
          CardSortOption.nameAsc,
          currentSort,
          isAscending,
        ),
        const PopupMenuDivider(),
        ..._buildSortMenuItem(
          'Cost',
          CardSortOption.costAsc,
          currentSort,
          isAscending,
        ),
        const PopupMenuDivider(),
        ..._buildSortMenuItem(
          'Power',
          CardSortOption.powerAsc,
          currentSort,
          isAscending,
        ),
        const PopupMenuDivider(),
        ..._buildSortMenuItem(
          'Release Date',
          CardSortOption.releaseDate,
          currentSort,
          isAscending,
          showAscDesc: false,
        ),
      ],
    );
  }

  List<PopupMenuEntry<(CardSortOption, bool)>> _buildSortMenuItem(
    String title,
    CardSortOption option,
    CardSortOption currentOption,
    bool currentAscending, {
    bool showAscDesc = true,
  }) {
    if (!showAscDesc) {
      return [
        PopupMenuItem(
          value: (option, true),
          child: Row(
            children: [
              Text(title),
              const SizedBox(width: 8),
              if (currentOption == option && currentAscending)
                const Icon(Icons.check, size: 20),
            ],
          ),
        ),
      ];
    }

    return [
      PopupMenuItem(
        value: (option, true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$title (A-Z)'),
            if (currentOption == option && currentAscending)
              const Icon(Icons.check, size: 20),
          ],
        ),
      ),
      PopupMenuItem(
        value: (option, false),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$title (Z-A)'),
            if (currentOption == option && !currentAscending)
              const Icon(Icons.check, size: 20),
          ],
        ),
      ),
    ];
  }
}
