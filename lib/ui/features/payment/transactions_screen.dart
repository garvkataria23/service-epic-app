import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../auth/auth_view_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final paymentRepo = context.read<PaymentRepository>();
    final transactions = paymentRepo.getTransactions();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & Escrow Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet Balance Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ServiceEpic Wallet',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${(authVm.currentUser?.walletBalance ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await authVm.topUpWallet(500);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added \$500.00 to your wallet!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Top Up \$500'),
                ),
              ],
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
                              '\$${txn.totalAmount.toStringAsFixed(2)}',
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
                        Row(
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
                            if (txn.promoCode != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Promo: ${txn.promoCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              DateFormat.MMMd().add_jm().format(txn.createdAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
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
