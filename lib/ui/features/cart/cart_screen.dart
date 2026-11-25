import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/service_order.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../payment/checkout_screen.dart';
import 'cart_view_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openReturnReplaceDialog(
    CartViewModel vm,
    ServiceOrder order, {
    required bool isReplacement,
  }) async {
    final reasons = isReplacement
        ? [
            'Specialist did not arrive on time',
            'Quality issue — need free re-service',
            'Need different specialist / technician',
          ]
        : [
            'Deliverable did not match agreed scope',
            'Service no longer required',
            'Quality issue — requesting full refund',
          ];
    var selectedReason = reasons.first;
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isReplacement
                ? 'Request Free Replacement'
                : 'Request Return & Refund',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${order.id} • Protected by 7-Day Return & Replace Guarantee',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (r) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selectedReason == r
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    onTap: () => setDialogState(() => selectedReason = r),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                isReplacement ? 'Schedule Replacement' : 'Submit Return',
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final fullReason = notesCtrl.text.trim().isEmpty
          ? selectedReason
          : '$selectedReason — ${notesCtrl.text.trim()}';
      await vm.requestReturnOrReplace(
        order: order,
        isReplacement: isReplacement,
        reason: fullReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isReplacement
                  ? 'Free replacement scheduled for ${order.id}!'
                  : 'Return & refund request submitted for ${order.id}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CartViewModel>();
    final currency = context.watch<CurrencyController>();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart & Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Cart (${vm.totalItemCount})'),
            Tab(text: 'Orders (${vm.orders.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: CART
          Column(
            children: [
              Expanded(
                child: vm.items.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Your cart is empty',
                        subtitle:
                            'Explore services, pick a size/scope tier, and tap Add to Cart or Buy Now.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: vm.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final item = vm.items[idx];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: item.category.color
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          item.category.icon,
                                          color: item.category.color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.serviceTitle,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${item.variantName} • ${item.sizeOrScope}',
                                              style:
                                                  textTheme.bodySmall?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: () =>
                                            vm.updateQuantity(item.id, 0),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        item.providerName,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: colors.outlineVariant,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  vm.updateQuantity(
                                                item.id,
                                                item.quantity - 1,
                                              ),
                                              icon: const Icon(
                                                Icons.remove_rounded,
                                                size: 18,
                                              ),
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  vm.updateQuantity(
                                                item.id,
                                                item.quantity + 1,
                                              ),
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        currency.format(item.lineTotal),
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (vm.items.isNotEmpty)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cart Subtotal',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              currency.formatExact(vm.subtotal),
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => CheckoutScreen(
                                    cartItems: List.of(vm.items),
                                    clearCartAfter: true,
                                  ),
                                ),
                              );
                              await vm.refreshOrders();
                              if (mounted && vm.items.isEmpty) {
                                _tabController.animateTo(1);
                              }
                            },
                            icon: const Icon(Icons.flash_on_rounded),
                            label: const Text('Proceed to Buy Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // TAB 2: ORDERS & RETURN/REPLACE
          vm.orders.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No orders placed yet',
                  subtitle:
                      'Orders purchased via Buy Now or Cart will appear here with Return & Replacement options.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final order = vm.orders[idx];
                    final canReturnOrReplace =
                        order.status == OrderStatus.confirmed ||
                            order.status == OrderStatus.scheduled ||
                            order.status == OrderStatus.completed;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  order.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _orderColor(order.status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    order.status.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _orderColor(order.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map(
                              (i) => Text(
                                '${i.quantity}x ${i.serviceTitle} (${i.variantName})',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paid ${currency.formatExact(order.totalAmount)} via ${order.paymentDetail} • ${DateFormat.MMMd().format(order.createdAt)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.preferredSlot,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: colors.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.pin_outlined,
                                        size: 13,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Start PIN: ${order.jobStartPin}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _OrderProgressStepper(
                              currentStep: order.progressStep,
                            ),
                            if (order.progressStep <
                                    ServiceOrder.progressStages.length - 1 &&
                                canReturnOrReplace) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      vm.advanceOrderProgress(order),
                                  icon: const Icon(
                                    Icons.fast_forward_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Advance Stage (${ServiceOrder.progressStages[order.progressStep + 1]})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                            if (order.returnOrReplaceReason != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Note: ${order.returnOrReplaceReason}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            if (canReturnOrReplace) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openReturnReplaceDialog(
                                        vm,
                                        order,
                                        isReplacement: false,
                                      ),
                                      icon: const Icon(
                                        Icons.assignment_return_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Return / Refund'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _openReturnReplaceDialog(
                                        vm,
                                        order,
                                        isReplacement: true,
                                      ),
                                      icon: const Icon(
                                        Icons.autorenew_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Replace'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Color _orderColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.confirmed => AppColors.primary,
      OrderStatus.scheduled => AppColors.info,
      OrderStatus.completed => AppColors.success,
      OrderStatus.returnRequested => AppColors.warning,
      OrderStatus.replacementScheduled => AppColors.accentAmber,
      OrderStatus.refunded => AppColors.error,
    };
  }
}

class _OrderProgressStepper extends StatelessWidget {
  const _OrderProgressStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stages = ServiceOrder.progressStages;
    final clamped = currentStep.clamp(0, stages.length - 1);
    final progress = (clamped + 1) / stages.length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Stage ${clamped + 1}/${stages.length}: ${stages[clamped]}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: clamped == stages.length - 1
                      ? AppColors.success
                      : colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: clamped == stages.length - 1
                  ? AppColors.success
                  : colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(stages.length, (i) {
              final done = i <= clamped;
              return Text(
                '${done ? '✓' : '○'} ${stages[i]}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  color: done ? AppColors.success : colors.onSurfaceVariant,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
