// lib/features/cards/presentation/widgets/search_bar_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/card_providers.dart';

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref
        .read(cardNotifierProvider.notifier)
        .updateSearchQuery(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SearchBar(
        controller: _searchController,
        focusNode: _focusNode,
        hintText: 'Search cards...',
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 16.0),
        ),
        leading: Icon(
          _isSearching ? Icons.search_off : Icons.search,
          color: theme.colorScheme.onSurface,
        ),
        trailing: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
            ),
        ],
        onTap: () {
          setState(() => _isSearching = true);
        },
        onChanged: (_) {
          setState(() {}); // Update to show/hide clear button
        },
        onSubmitted: (_) {
          setState(() => _isSearching = false);
          _focusNode.unfocus();
        },
      ),
    );
  }
}
