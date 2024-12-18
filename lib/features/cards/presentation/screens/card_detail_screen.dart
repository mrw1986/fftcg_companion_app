import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/fftcg_card.dart';
import '../../providers/card_providers.dart';
import '../../../../core/logging/logger_service.dart';

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
  final _logger = LoggerService();
  bool _isImageExpanded = false;

  @override
  void initState() {
    super.initState();
    _logger.info('Viewing card details: ${widget.card.cardNumber}');
    ref.read(cardCacheServiceProvider).addRecentCard(widget.card);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              setState(() {
                _isImageExpanded = !_isImageExpanded;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'card_${widget.card.cardNumber}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isImageExpanded ? 500 : 300,
                child: CachedNetworkImage(
                  imageUrl: _isImageExpanded
                      ? widget.card.highResUrl
                      : widget.card.lowResUrl,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Card Number', widget.card.cardNumber),
                  _buildInfoRow('Type', widget.card.cardType),
                  _buildInfoRow('Cost', widget.card.cost),
                  if (widget.card.power != null)
                    _buildInfoRow('Power', widget.card.power),
                  _buildInfoRow('Job', widget.card.job),
                  _buildInfoRow('Rarity', widget.card.rarity),
                  _buildInfoRow('Category', widget.card.category),
                  const SizedBox(height: 16),
                  if (widget.card.elements.isNotEmpty) ...[
                    Text(
                      'Elements',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: widget.card.elements.map((element) {
                        return Chip(
                          label: Text(element),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (widget.card.description != null) ...[
                    Text(
                      'Card Text',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.card.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
