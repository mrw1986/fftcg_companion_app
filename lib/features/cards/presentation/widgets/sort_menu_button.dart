// lib/features/cards/presentation/widgets/sort_menu_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../models/card_filter_options.dart';
import '../../providers/card_providers.dart';

class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(cardNotifierProvider);
    final currentSort =
        cardState.filterOptions?.sortOption ?? CardSortOption.setNumber;
    final isAscending = cardState.filterOptions?.ascending ?? true;
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return PopupMenuButton<(CardSortOption, bool)>(
      initialValue: (currentSort, isAscending),
      tooltip: 'Sort cards',
      icon: const Icon(Icons.sort),
      itemBuilder: (context) {
        List<PopupMenuEntry<(CardSortOption, bool)>> items = [];

        // Set Number
        items.add(
          PopupMenuItem(
            value: (CardSortOption.setNumber, true),
            child: Row(
              children: [
                Text(
                  'Set Number',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                const SizedBox(width: 8),
                if (currentSort == CardSortOption.setNumber && isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );

        items.add(const PopupMenuDivider());

        // Name
        items.add(
          PopupMenuItem(
            value: (CardSortOption.nameAsc, true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Name (A-Z)',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                if (currentSort == CardSortOption.nameAsc && isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );
        items.add(
          PopupMenuItem(
            value: (CardSortOption.nameDesc, false),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Name (Z-A)',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                if (currentSort == CardSortOption.nameDesc && !isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );

        items.add(const PopupMenuDivider());

        // Cost
        items.add(
          PopupMenuItem(
            value: (CardSortOption.costAsc, true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cost (Low to High)',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                if (currentSort == CardSortOption.costAsc && isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );
        items.add(
          PopupMenuItem(
            value: (CardSortOption.costDesc, false),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cost (High to Low)',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                if (currentSort == CardSortOption.costDesc && !isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );

        // Power (Desktop only)
        if (isDesktop) {
          items.add(const PopupMenuDivider());
          items.add(
            PopupMenuItem(
              value: (CardSortOption.powerAsc, true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Power (Low to High)',
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                  if (currentSort == CardSortOption.powerAsc && isAscending)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
          );
          items.add(
            PopupMenuItem(
              value: (CardSortOption.powerDesc, false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Power (High to Low)',
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                  if (currentSort == CardSortOption.powerDesc && !isAscending)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
          );
        }

        // Release Date
        items.add(const PopupMenuDivider());
        items.add(
          PopupMenuItem(
            value: (CardSortOption.releaseDate, true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Release Date (Newest)',
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
                if (currentSort == CardSortOption.releaseDate && isAscending)
                  const Icon(Icons.check, size: 20),
              ],
            ),
          ),
        );

        return items;
      },
      onSelected: (value) {
        final currentFilters =
            cardState.filterOptions ?? const CardFilterOptions();
        ref.read(cardNotifierProvider.notifier).updateFilters(
              currentFilters.copyWith(
                sortOption: value.$1,
                ascending: value.$2,
              ),
            );
      },
    );
  }
}
