import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../core/widgets/confirmation_banner.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../auth/auth_view_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  ConfirmationBannerData? _banner;

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final currency = context.watch<CurrencyController>();
    final paymentRepo = context.read<PaymentRepository>();
    final transactions = paymentRepo.getTransactions();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final heldTotal = transactions
        .where((t) => t.status == EscrowStatus.heldInEscrow)
        .fold<double>(0, (s, t) => s + t.totalAmount);
    final releasedTotal = transactions
        .where((t) => t.status == EscrowStatus.released)
        .fold<double>(0, (s, t) => s + t.totalAmount);
    final promoSavings =
        transactions.fold<double>(0, (s, t) => s + t.discount);
    final totalSpend = heldTotal + releasedTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & Escrow Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_banner != null)
            ConfirmationBanner(
              data: _banner!,
              onDismiss: () => setState(() => _banner = null),
            ),
          // Wallet Balance Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ServiceEpic Wallet',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () async {
                        await authVm.topUpWallet(500);
                        if (!context.mounted) return;
                        setState(() {
                          _banner = ConfirmationBannerData(
                            title: 'Wallet Topped Up',
                            badgeText: '+${currency.formatExact(500)}',
                            subtitle:
                                'Added ${currency.formatExact(500)} to your Epic Wallet. Available balance: ${currency.formatExact(authVm.currentUser?.walletBalance ?? 0)}.',
                            tone: ConfirmationTone.success,
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(
                        'Top Up ${currency.format(500)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currency.formatExact(authVm.currentUser?.walletBalance ?? 0),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Spend & Savings Analytics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Spend & Escrow Analytics',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currency.formatExact(totalSpend),
                            maxLines: 1,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AnalyticsBar(
                    label: 'Held in Escrow',
                    amount: currency.formatExact(heldTotal),
                    ratio: totalSpend > 0 ? heldTotal / totalSpend : 0,
                    color: AppColors.accentAmber,
                  ),
                  const SizedBox(height: 8),
                  _AnalyticsBar(
                    label: 'Released to Providers',
                    amount: currency.formatExact(releasedTotal),
                    ratio: totalSpend > 0 ? releasedTotal / totalSpend : 0,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _AnalyticsBar(
                    label: 'Promo Savings',
                    amount: currency.formatExact(promoSavings),
                    ratio: totalSpend > 0
                        ? (promoSavings / totalSpend).clamp(0.0, 1.0)
                        : 0,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Payment History (${transactions.length})',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          if (transactions.isEmpty)
            const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle:
                  'Payments made when accepting provider quotes will appear here.',
            )
          else
            ...transactions.map(
              (txn) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                txn.serviceTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currency.formatExact(txn.totalAmount),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txn.providerName} • ${txn.requestId} • ${txn.methodDetail}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(txn.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                txn.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(txn.status),
                                ),
                              ),
                            ),
                            if (txn.promoCode != null)
                              Text(
                                'Promo: ${txn.promoCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              DateFormat.MMMd().add_jm().format(txn.createdAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final invoice = [
                                'EPIC INFOCUS — INVOICE',
                                'Txn ID: ${txn.id}',
                                'Ref: ${txn.requestId}',
                                'Service: ${txn.serviceTitle}',
                                'Provider: ${txn.providerName}',
                                'Total: ${currency.formatExact(txn.totalAmount)} (${currency.currency.code})',
                                'Method: ${txn.methodDetail}',
                                'Status: ${txn.status.label}',
                                'Date: ${DateFormat.yMMMd().add_jm().format(txn.createdAt)}',
                              ].join('\n');
                              await Clipboard.setData(
                                ClipboardData(text: invoice),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invoice copied to clipboard!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text(
                              'Copy Invoice',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(EscrowStatus status) {
    return switch (status) {
      EscrowStatus.heldInEscrow => AppColors.accentAmber,
      EscrowStatus.released => AppColors.success,
      EscrowStatus.refunded => AppColors.info,
      EscrowStatus.topUp => AppColors.primary,
    };
  }
}

class _AnalyticsBar extends StatelessWidget {
  const _AnalyticsBar({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String amount;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
          ),
        ),
      ],
    );
  }
}
