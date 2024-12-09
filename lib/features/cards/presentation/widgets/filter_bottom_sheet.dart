import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = const CardFilterOptions();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onFilterChanged(_filters);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Elements',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    elements.when(
                      data: (elements) => Wrap(
                        spacing: 8,
                        children: elements.map((element) {
                          return FilterChip(
                            label: Text(element),
                            selected:
                                _filters.elements?.contains(element) ?? false,
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
                                  elements: currentElements.isEmpty
                                      ? null
                                      : currentElements,
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Failed to load elements'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Card Type',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    cardTypes.when(
                      data: (types) => Wrap(
                        spacing: 8,
                        children: types.map((type) {
                          return ChoiceChip(
                            label: Text(type),
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
                    const SizedBox(height: 16),
                    Text(
                      'Cost',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: List.generate(13, (index) {
                        final cost = index.toString();
                        return FilterChip(
                          label: Text(cost),
                          selected: _filters.costs?.contains(cost) ?? false,
                          onSelected: (selected) {
                            setState(() {
                              final currentCosts =
                                  List<String>.from(_filters.costs ?? []);
                              if (selected) {
                                currentCosts.add(cost);
                              } else {
                                currentCosts.remove(cost);
                              }
                              _filters = _filters.copyWith(
                                costs:
                                    currentCosts.isEmpty ? null : currentCosts,
                              );
                            });
                          },
                        );
                      }),
                    ),
                    // Additional filter sections will be added here
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
