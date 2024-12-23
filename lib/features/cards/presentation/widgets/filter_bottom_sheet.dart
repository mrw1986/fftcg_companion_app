// lib/features/cards/presentation/widgets/filter_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../models/card_filter_options.dart';
import '../../providers/card_providers.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  final CardFilterOptions currentFilters;
  final ValueChanged<CardFilterOptions> onFilterChanged;

  const FilterBottomSheet({
    super.key,
    required this.currentFilters,
    required this.onFilterChanged,
  });

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late CardFilterOptions _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
  }

  @override
  Widget build(BuildContext context) {
    final elements = ref.watch(uniqueElementsProvider);
    final cardTypes = ref.watch(uniqueCardTypesProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return DraggableScrollableSheet(
      initialChildSize: isDesktop ? 0.8 : 0.9,
      minChildSize: isTablet ? 0.4 : 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(),
              Expanded(
                child: _buildFilterContent(
                  context,
                  scrollController,
                  elements,
                  cardTypes,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.titleLarge?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
    );
    final buttonStyle = textTheme.labelLarge?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
    );

    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _filters = const CardFilterOptions();
              });
            },
            child: Text('Reset', style: buttonStyle),
          ),
          Text('Filters', style: headerStyle),
          TextButton(
            onPressed: () {
              widget.onFilterChanged(_filters);
              Navigator.pop(context);
            },
            child: Text('Apply', style: buttonStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContent(
    BuildContext context,
    ScrollController scrollController,
    AsyncValue<List<String>> elements,
    AsyncValue<List<String>> cardTypes,
  ) {
    final isWideScreen =
        ResponsiveUtils.isTablet(context) || ResponsiveUtils.isDesktop(context);

    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildFilterList(
              scrollController,
              elements,
              cardTypes,
              startIndex: 0,
              endIndex: 2,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildFilterList(
              scrollController,
              elements,
              cardTypes,
              startIndex: 2,
              endIndex: 4,
            ),
          ),
        ],
      );
    }

    return _buildFilterList(
      scrollController,
      elements,
      cardTypes,
      startIndex: 0,
      endIndex: 4,
    );
  }

  Widget _buildFilterList(
    ScrollController scrollController,
    AsyncValue<List<String>> elements,
    AsyncValue<List<String>> cardTypes, {
    required int startIndex,
    required int endIndex,
  }) {
    final filterSections = [
      _buildElementsSection(elements),
      _buildCardTypesSection(cardTypes),
      _buildCostSection(),
      _buildPowerSection(),
    ].sublist(startIndex, endIndex);

    return ListView.separated(
      controller: scrollController,
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: filterSections.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => filterSections[index],
    );
  }

  Widget _buildElementsSection(AsyncValue<List<String>> elements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elements',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        const SizedBox(height: 8),
        elements.when(
          data: (elementList) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: elementList.map((element) {
              return FilterChip(
                label: Text(
                  element,
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 12),
                  ),
                ),
                selected: _filters.elements?.contains(element) ?? false,
                onSelected: (selected) {
                  setState(() {
                    final currentElements =
                        List<String>.from(_filters.elements ?? []);
                    if (selected) {
                      currentElements.add(element);
                    } else {
                      currentElements.remove(element);
                    }
                    _filters = _filters.copyWith(
                      elements:
                          currentElements.isEmpty ? null : currentElements,
                    );
                  });
                },
              );
            }).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Failed to load elements'),
        ),
      ],
    );
  }

  Widget _buildCardTypesSection(AsyncValue<List<String>> cardTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        const SizedBox(height: 8),
        cardTypes.when(
          data: (types) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              return ChoiceChip(
                label: Text(
                  type,
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 12),
                  ),
                ),
                selected: _filters.cardType == type,
                onSelected: (selected) {
                  setState(() {
                    _filters = _filters.copyWith(
                      cardType: selected ? type : null,
                    );
                  });
                },
              );
            }).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Failed to load card types'),
        ),
      ],
    );
  }

  Widget _buildCostSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cost',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(13, (index) {
            final cost = index.toString();
            return FilterChip(
              label: Text(
                cost,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                ),
              ),
              selected: _filters.costs?.contains(cost) ?? false,
              onSelected: (selected) {
                setState(() {
                  final currentCosts = List<String>.from(_filters.costs ?? []);
                  if (selected) {
                    currentCosts.add(cost);
                  } else {
                    currentCosts.remove(cost);
                  }
                  _filters = _filters.copyWith(
                    costs: currentCosts.isEmpty ? null : currentCosts,
                  );
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPowerSection() {
    final ranges = ['1000-5000', '5001-10000', '10001+'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Power Range',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ranges.map((range) {
            return ChoiceChip(
              label: Text(
                range,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                ),
              ),
              selected: _filters.powerRange == range,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    powerRange: selected ? range : null,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
