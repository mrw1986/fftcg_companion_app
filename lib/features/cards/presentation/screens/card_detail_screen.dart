// lib/features/cards/presentation/screens/card_detail_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/logging/talker_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../models/fftcg_card.dart';
import '../../providers/card_providers.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final FFTCGCard card;

  const CardDetailScreen({
    super.key,
    required this.card,
  });

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  final _talker = TalkerService();
  bool _isImageExpanded = false;

  @override
  void initState() {
    super.initState();
    _talker.info('Viewing card details: ${widget.card.cardNumber}');
    ref.read(cardCacheServiceProvider).preCacheCard(widget.card);
    ref.read(cardCacheServiceProvider).addRecentCard(widget.card);
  }

  Future<String> _getImageUrl(String url) async {
    try {
      if (!url.contains('firebasestorage')) return url;

      // Extract the path from the URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Get the path after 'card-images/'
      final cardImagesIndex = pathSegments.indexOf('card-images');
      if (cardImagesIndex == -1 || cardImagesIndex + 1 >= pathSegments.length) {
        return url;
      }

      final storagePath = pathSegments.sublist(cardImagesIndex).join('/');

      // Get download URL using the path
      final ref = FirebaseStorage.instance.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      _talker.severe('Error getting image URL: $e');
      return url; // Return original URL on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card.name),
        actions: [
          IconButton(
            icon: Icon(
                _isImageExpanded ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () =>
                setState(() => _isImageExpanded = !_isImageExpanded),
          ),
        ],
      ),
      body: ResponsiveUtils.buildResponsiveLayout(
        context: context,
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    final imageHeight = ResponsiveUtils.isLandscape(context)
        ? ResponsiveUtils.getScreenHeight(context) * 0.5
        : ResponsiveUtils.getScreenHeight(context) *
            (_isImageExpanded ? 0.6 : 0.4);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardImage(imageHeight),
          Padding(
            padding: ResponsiveUtils.getScreenPadding(context),
            child: _buildCardDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildCardImage(
            ResponsiveUtils.getScreenHeight(context) *
                (_isImageExpanded ? 0.8 : 0.6),
          ),
        ),
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: ResponsiveUtils.getScreenPadding(context),
            child: _buildCardDetails(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _buildCardImage(
            ResponsiveUtils.getScreenHeight(context) *
                (_isImageExpanded ? 0.9 : 0.7),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: ResponsiveUtils.getScreenPadding(context),
            child: ResponsiveUtils.wrapWithMaxWidth(
              _buildCardDetails(),
              context,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardImage(double height) {
    final cacheService = ref.watch(cardCacheServiceProvider);

    return Hero(
      tag: 'card_${widget.card.cardNumber}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        child: FutureBuilder<String>(
          future: _getImageUrl(_isImageExpanded
              ? widget.card.highResUrl
              : widget.card.lowResUrl),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error,
                        color: Theme.of(context).colorScheme.error),
                    const Text('Failed to load image'),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return CachedNetworkImage(
              cacheManager: cacheService.imageCacheManager,
              imageUrl: snapshot.data!,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) {
                _talker.severe('Error loading detail image', error);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error,
                          color: Theme.of(context).colorScheme.error),
                      const Text('Error loading image'),
                    ],
                  ),
                );
              },
              memCacheHeight: _isImageExpanded ? 1000 : 500,
              memCacheWidth: _isImageExpanded ? 1000 : 500,
              maxHeightDiskCache: _isImageExpanded ? 2000 : 1000,
              useOldImageOnUrlChange: true,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardDetails() {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
    );
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
            'Card Number', widget.card.cardNumber, titleStyle, bodyStyle),
        _buildInfoRow('Type', widget.card.cardType, titleStyle, bodyStyle),
        _buildInfoRow('Cost', widget.card.cost, titleStyle, bodyStyle),
        if (widget.card.power != null)
          _buildInfoRow('Power', widget.card.power, titleStyle, bodyStyle),
        _buildInfoRow('Job', widget.card.job, titleStyle, bodyStyle),
        _buildInfoRow('Rarity', widget.card.rarity, titleStyle, bodyStyle),
        _buildInfoRow('Category', widget.card.category, titleStyle, bodyStyle),
        const SizedBox(height: 16),
        if (widget.card.elements.isNotEmpty) ...[
          Text('Elements', style: titleStyle),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.card.elements.map((element) {
              return Chip(
                label: Text(
                  element,
                  style: TextStyle(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (widget.card.description != null) ...[
          const SizedBox(height: 16),
          Text('Card Text', style: titleStyle),
          const SizedBox(height: 8),
          Text(
            widget.card.description!,
            style: bodyStyle,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  ) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: labelStyle),
          Expanded(
            child: Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
