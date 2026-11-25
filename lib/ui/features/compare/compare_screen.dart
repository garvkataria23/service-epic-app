import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_item.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen.services({
    super.key,
    required List<ServiceItem> this.services,
    required ValueChanged<ServiceItem> this.onSelectService,
  })  : quotes = null,
        clientMaxBudget = null,
        onAcceptQuote = null;

  const CompareScreen.quotes({
    super.key,
    required List<ProviderResponse> this.quotes,
    required double this.clientMaxBudget,
    required ValueChanged<ProviderResponse> this.onAcceptQuote,
  })  : services = null,
        onSelectService = null;

  final List<ServiceItem>? services;
  final ValueChanged<ServiceItem>? onSelectService;
  final List<ProviderResponse>? quotes;
  final double? clientMaxBudget;
  final ValueChanged<ProviderResponse>? onAcceptQuote;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyController>();
    final isServiceMode = services != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isServiceMode ? 'Compare Services' : 'Compare Provider Quotes',
        ),
      ),
      body: isServiceMode
          ? _buildServicesMatrix(context, currency, services!)
          : _buildQuotesMatrix(context, currency, quotes!),
    );
  }

  Widget _buildServicesMatrix(
    BuildContext context,
    CurrencyController currency,
    List<ServiceItem> list,
  ) {
    final lowestPrice = list.map((s) => s.basePrice).reduce(min);
    final highestRating = list.map((s) => s.rating).reduce(max);
    final fastestMins = list.map((s) => s.responseTimeMinutes).reduce(min);
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.map((srv) {
          final badges = <String>[];
          if (srv.basePrice == lowestPrice) badges.add('Best Value');
          if (srv.rating == highestRating) badges.add('Top Rated');
          if (srv.responseTimeMinutes == fastestMins) badges.add('Fastest');

          return Container(
            width: 245,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badges.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: badges
                            .map(
                              (b) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  b,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      srv.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      srv.providerName,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 20),
                    _CompareRow(
                      'Starting Price',
                      '${currency.format(srv.basePrice)} / ${srv.priceUnit}',
                      highlight: srv.basePrice == lowestPrice,
                    ),
                    _CompareRow(
                      'Rating',
                      '${srv.rating.toStringAsFixed(1)} ★ (${srv.reviewCount})',
                      highlight: srv.rating == highestRating,
                    ),
                    _CompareRow(
                      'Response SLA',
                      srv.formattedResponseTime,
                      highlight: srv.responseTimeMinutes == fastestMins,
                    ),
                    _CompareRow('Completed Jobs', '${srv.completedJobs}+'),
                    _CompareRow(
                      'Verified Pro',
                      srv.isVerifiedProvider ? 'Yes' : 'Standard',
                    ),
                    _CompareRow('Warranty', srv.warrantyBadge),
                    _CompareRow(
                      'Tiers Available',
                      '${srv.packages.length} options',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onSelectService!(srv);
                        },
                        child: const Text('View & Select'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      ),
    );
  }

  Widget _buildQuotesMatrix(
    BuildContext context,
    CurrencyController currency,
    List<ProviderResponse> list,
  ) {
    final lowestPrice = list.map((q) => q.quotedPrice).reduce(min);
    final highestRating = list.map((q) => q.rating).reduce(max);
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.map((q) {
          final withinBudget =
              clientMaxBudget == null || q.quotedPrice <= clientMaxBudget!;
          return Container(
            width: 245,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        if (q.quotedPrice == lowestPrice)
                          const _BadgePill('Lowest Quote', AppColors.success),
                        if (q.rating == highestRating)
                          const _BadgePill('Top Rated', AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      q.providerRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 20),
                    _CompareRow(
                      'Quoted Price',
                      currency.format(q.quotedPrice),
                      highlight: q.quotedPrice == lowestPrice,
                    ),
                    _CompareRow(
                      'Budget Fit',
                      withinBudget ? 'Within Budget' : 'Above Max',
                      highlight: withinBudget,
                    ),
                    _CompareRow('Rating', '${q.rating.toStringAsFixed(1)} ★'),
                    _CompareRow('Jobs Done', '${q.completedJobs}+'),
                    _CompareRow('Timeline', q.estimatedDuration),
                    _CompareRow(
                      'Deliverables',
                      '${q.deliverables.length} items',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: q.status == QuoteStatus.pending ||
                                q.status == QuoteStatus.negotiating
                            ? () {
                                Navigator.pop(context);
                                onAcceptQuote!(q);
                              }
                            : null,
                        child: Text(
                          q.status == QuoteStatus.accepted
                              ? 'Accepted'
                              : 'Accept Quote',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}
