import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/location_service.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/models/service_item.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_view_model.dart';
import '../payment/checkout_screen.dart';
import '../provider_profile/provider_profile_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({
    super.key,
    required this.service,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onRequestService,
  });

  final ServiceItem service;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(ServiceItem service, ServicePackage? selectedPackage)
      onRequestService;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _selectedPackageIndex = 0;
  int _quantity = 1;

  ServicePackage get _effectivePackage {
    if (widget.service.packages.isNotEmpty) {
      return widget.service.packages[_selectedPackageIndex];
    }
    return ServicePackage(
      id: '${widget.service.id}-std',
      name: 'Standard Service',
      sizeOrScope: widget.service.priceUnit,
      price: widget.service.basePrice,
      deliveryLabel: widget.service.formattedResponseTime,
      features: widget.service.highlights,
    );
  }

  Future<void> _handleAddToCart() async {
    final cartVm = context.read<CartViewModel>();
    final pkg = _effectivePackage;
    await cartVm.addToCart(
      service: widget.service,
      package: pkg,
      quantity: _quantity,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${_quantity}x ${widget.service.title} (${pkg.name}) to Cart',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleBuyNow() async {
    final pkg = _effectivePackage;
    final directItem = CartItem(
      id: 'DIRECT-${DateTime.now().millisecondsSinceEpoch}',
      serviceId: widget.service.id,
      serviceTitle: widget.service.title,
      category: widget.service.category,
      providerName: widget.service.providerName,
      variantName: pkg.name,
      sizeOrScope:
          pkg.sizeOrScope.isNotEmpty ? pkg.sizeOrScope : pkg.deliveryLabel,
      unitPrice: pkg.price,
      quantity: _quantity,
      deliveryLabel: pkg.deliveryLabel,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: [directItem],
          clearCartAfter: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cartVm = context.watch<CartViewModel>();
    final currency = context.watch<CurrencyController>();
    final selectedPkg = _effectivePackage;
    final totalPreview = selectedPkg.price * _quantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(service.category.label),
        actions: [
          Badge(
            isLabelVisible: cartVm.totalItemCount > 0,
            label: Text('${cartVm.totalItemCount}'),
            child: IconButton(
              tooltip: 'Open Cart',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                );
              },
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            tooltip: widget.isFavorite ? 'Remove from saved' : 'Save service',
            onPressed: widget.onToggleFavorite,
            icon: Icon(
              widget.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.isFavorite ? AppColors.error : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProviderProfileScreen(
                            providerName: service.providerName,
                            providerTitle: service.providerTitle,
                            isVerified: service.isVerifiedProvider,
                            rating: service.rating,
                            completedJobs: service.completedJobs,
                            onSelectService: (srv) {
                              Navigator.of(context).pop();
                              if (srv.id != service.id) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ServiceDetailScreen(
                                      service: srv,
                                      isFavorite: widget.isFavorite,
                                      onToggleFavorite: widget.onToggleFavorite,
                                      onRequestService: widget.onRequestService,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: service.category.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            service.category.icon,
                            color: service.category.color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      service.providerName,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                  if (service.isVerifiedProvider) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: AppColors.info,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${service.providerTitle} • SKU: ${service.skuCode}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    service.title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _MetricPill(
                        icon: Icons.star_rounded,
                        iconColor: AppColors.accentAmber,
                        label:
                            '${service.rating.toStringAsFixed(1)} (${service.reviewCount})',
                      ),
                      _MetricPill(
                        icon: Icons.bolt_rounded,
                        iconColor: AppColors.success,
                        label: 'Replies ${service.formattedResponseTime}',
                      ),
                      _MetricPill(
                        icon: Icons.verified_user_rounded,
                        iconColor: colors.primary,
                        label: service.warrantyBadge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    service.description,
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${service.location} • ${context.watch<LocationController>().formatDistanceFor(service)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Size / Scope / Tier Selection + Quantity
          if (service.packages.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Size / Scope Tier',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_rounded, size: 18),
                      ),
                      Text(
                        'Qty: $_quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _quantity < 10
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(service.packages.length, (idx) {
              final pkg = service.packages[idx];
              final isSelected = idx == _selectedPackageIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedPackageIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryContainer.withValues(alpha: 0.3)
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : AppColors.lightBorder.withValues(alpha: 0.6),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pkg.name,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (pkg.sizeOrScope.isNotEmpty)
                                    Text(
                                      pkg.sizeOrScope,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pkg.originalPrice != null) ...[
                                      Text(
                                        currency.format(pkg.originalPrice!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      currency.format(pkg.price),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (pkg.discountPercent > 0)
                                  Text(
                                    '${pkg.discountPercent}% OFF',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            'Turnaround: ${pkg.deliveryLabel}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...pkg.features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(left: 28, top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(f, style: textTheme.bodySmall),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Custom Quote CTA
          OutlinedButton.icon(
            onPressed: () => widget.onRequestService(service, selectedPkg),
            icon: const Icon(Icons.assignment_add),
            label: const Text('Need Custom Scope? Submit Requirement for Quotes'),
          ),

          const SizedBox(height: 20),

          // Return, Replacement & Warranty Policies
          Text(
            'Return, Replacement & Protection Policies',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _PolicyRow(
                    icon: Icons.assignment_return_outlined,
                    color: AppColors.info,
                    title: 'Return & Refund Policy',
                    body: service.returnPolicy,
                  ),
                  const Divider(height: 18),
                  _PolicyRow(
                    icon: Icons.autorenew_rounded,
                    color: AppColors.success,
                    title: 'Replacement / Re-Service Policy',
                    body: service.replacementPolicy,
                  ),
                  const Divider(height: 18),
                  _PolicyRow(
                    icon: Icons.event_busy_outlined,
                    color: AppColors.warning,
                    title: 'Cancellation Policy',
                    body: service.cancellationPolicy,
                  ),
                  const Divider(height: 18),
                  _PolicyRow(
                    icon: Icons.verified_user_outlined,
                    color: colors.primary,
                    title: 'SLA Guarantee',
                    body: service.slaGuarantee,
                  ),
                ],
              ),
            ),
          ),

          if (service.customerReviews.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Verified Client Reviews (${service.customerReviews.length})',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...service.customerReviews.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.reviewerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (r.verifiedPurchase) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                            ],
                            const Spacer(),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.accentAmber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              r.rating.toStringAsFixed(1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (r.variantPurchased.isNotEmpty)
                          Text(
                            'Purchased: ${r.variantPurchased} • ${r.dateLabel}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(r.comment, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "What's Included & Escrow Guarantee",
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...[
                    'Background-verified specialist with 4-digit Job-Start PIN',
                    '100% Escrow protection — release funds only after completion',
                    'Free rescheduling & instant wallet refund before work begins',
                    '7-day complimentary rework / replacement guarantee',
                  ].map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: textTheme.bodySmall?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (service.faqs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Frequently Asked Questions',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: service.faqs
                    .map(
                      (faq) => ExpansionTile(
                        title: Text(
                          faq.question,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Text(
                              faq.answer,
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ($_quantity×)',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(totalPreview),
                        maxLines: 1,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _handleAddToCart,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Add to Cart'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _handleBuyNow,
                  icon: const Icon(Icons.flash_on_rounded, size: 17),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Buy Now'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
