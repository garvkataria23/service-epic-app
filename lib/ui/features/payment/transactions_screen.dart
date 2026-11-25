import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../../domain/models/user_profile.dart';
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'ServiceEpic Wallet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () async {
                        final result = await showModalBottomSheet<_TopUpResult>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          showDragHandle: true,
                          builder: (_) => const _WalletTopUpSheet(),
                        );
                        if (result == null || !context.mounted) return;
                        await authVm.topUpWallet(result.usdAmount);
                        if (!context.mounted) return;
                        setState(() {
                          _banner = ConfirmationBannerData(
                            title: 'Wallet Topped Up',
                            badgeText: '+${currency.formatExact(result.usdAmount)}',
                            subtitle:
                                'Verified via ${result.methodLabel}. Added ${currency.formatExact(result.usdAmount)} to your Epic Wallet. Available balance: ${currency.formatExact(authVm.currentUser?.walletBalance ?? 0)}.',
                            tone: ConfirmationTone.success,
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'Top Up',
                        style: TextStyle(fontSize: 12),
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
                          'Spend & Escrow',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currency.formatExact(totalSpend),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
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

class _TopUpResult {
  const _TopUpResult({
    required this.usdAmount,
    required this.methodLabel,
  });

  final double usdAmount;
  final String methodLabel;
}

class _WalletTopUpSheet extends StatefulWidget {
  const _WalletTopUpSheet();

  @override
  State<_WalletTopUpSheet> createState() => _WalletTopUpSheetState();
}

class _WalletTopUpSheetState extends State<_WalletTopUpSheet> {
  static const List<double> _presetUsdAmounts = [100, 250, 500, 1000];

  final _amountFormKey = GlobalKey<FormState>();
  final _cardFormKey = GlobalKey<FormState>();
  final _upiFormKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _upiController = TextEditingController(text: 'garv@okaxis');
  final _otpController = TextEditingController(text: '1234');

  double _selectedUsd = 500;
  PaymentMethodType _method = PaymentMethodType.upi;
  SavedCard? _selectedSavedCard;
  bool _useNewCard = false;
  bool _awaitingOtp = false;
  bool _verifying = false;
  String? _otpError;
  String _pendingMethodLabel = '';
  double _pendingUsdAmount = 500;

  @override
  void initState() {
    super.initState();
    final currency = context.read<CurrencyController>();
    final user = context.read<AuthViewModel>().currentUser;
    _amountController = TextEditingController(
      text: currency.convert(_selectedUsd).round().toString(),
    );
    if (user != null && user.savedCards.isNotEmpty) {
      _selectedSavedCard = user.savedCards.first;
      _useNewCard = false;
    } else {
      _useNewCard = true;
    }
    _cardHolderController.text = (user?.fullName ?? '').toUpperCase();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _upiController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _selectPreset(double usdAmount, CurrencyController currency) {
    setState(() {
      _selectedUsd = usdAmount;
      _amountController.text = currency.convert(usdAmount).round().toString();
    });
  }

  void _proceedToVerification(CurrencyController currency) {
    if (!(_amountFormKey.currentState?.validate() ?? false)) return;

    final enteredDisplay = double.tryParse(
          _amountController.text.replaceAll(',', '').trim(),
        ) ??
        0;
    final usdAmount = enteredDisplay / currency.currency.rateFromUsd;

    String methodLabel;
    if (_method == PaymentMethodType.card) {
      if (!_useNewCard && _selectedSavedCard != null) {
        methodLabel =
            '${_selectedSavedCard!.brand} •••• ${_selectedSavedCard!.last4}';
      } else {
        if (!(_cardFormKey.currentState?.validate() ?? false)) return;
        final digits =
            _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
        final brand = Validators.detectCardBrand(digits);
        methodLabel =
            '$brand •••• ${digits.substring(digits.length - 4)}';
      }
    } else {
      if (!(_upiFormKey.currentState?.validate() ?? false)) return;
      methodLabel = 'UPI (${_upiController.text.trim()})';
    }

    setState(() {
      _pendingUsdAmount = usdAmount;
      _pendingMethodLabel = methodLabel;
      _otpError = null;
      _otpController.text = '1234';
      _awaitingOtp = true;
    });
  }

  Future<void> _confirmOtp() async {
    if (_otpController.text.trim() != '1234') {
      setState(() => _otpError = 'Invalid code. Use 1234 for demo verification.');
      return;
    }
    setState(() {
      _otpError = null;
      _verifying = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pop(
      _TopUpResult(
        usdAmount: _pendingUsdAmount,
        methodLabel: _pendingMethodLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyController>();
    final user = context.watch<AuthViewModel>().currentUser;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _awaitingOtp ? 'Verify Top-Up Payment' : 'Top Up Epic Wallet',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _awaitingOtp
                  ? 'Confirm payment verification to credit your wallet'
                  : 'Add funds securely via UPI or Debit/Credit Card',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_awaitingOtp) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top-Up Amount',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currency.formatExact(_pendingUsdAmount),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Method: $_pendingMethodLabel',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Demo OTP / UPI PIN: 1234',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Enter 4-digit OTP / UPI PIN',
                  errorText: _otpError,
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _verifying
                        ? null
                        : () => setState(() => _awaitingOtp = false),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _verifying ? null : _confirmOtp,
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _verifying ? 'Verifying...' : 'Verify & Top Up',
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Form(
                key: _amountFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Select Amount (${currency.currency.code})',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetUsdAmounts.map((usd) {
                        final selected = (_selectedUsd - usd).abs() < 0.01;
                        return ChoiceChip(
                          label: Text(currency.format(usd)),
                          selected: selected,
                          onSelected: (_) => _selectPreset(usd, currency),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Amount (${currency.currency.symbol})',
                        prefixText: '${currency.currency.symbol} ',
                      ),
                      validator: (val) {
                        final num? parsed =
                            double.tryParse((val ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid top-up amount';
                        }
                        final usd = parsed / currency.currency.rateFromUsd;
                        if (usd > 10000) {
                          return 'Max ${currency.format(10000)} per top-up';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '2. Payment Method',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PaymentMethodType>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethodType.upi,
                    icon: Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text('UPI'),
                  ),
                  ButtonSegment(
                    value: PaymentMethodType.card,
                    icon: Icon(Icons.credit_card_rounded, size: 18),
                    label: Text('Card'),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (next) {
                  setState(() => _method = next.first);
                },
              ),
              const SizedBox(height: 12),
              if (_method == PaymentMethodType.upi) ...[
                Form(
                  key: _upiFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _upiController,
                        validator: Validators.upiId,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          hintText: 'name@okaxis',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ['garv@okaxis', 'garv@ybl', 'garv@okicici']
                            .map(
                              (handle) => ActionChip(
                                label: Text(
                                  handle,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    setState(() => _upiController.text = handle),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (user != null && user.savedCards.isNotEmpty) ...[
                  ...user.savedCards.map(
                    (card) {
                      final isSelected =
                          !_useNewCard && _selectedSavedCard?.id == card.id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          title: Text(
                            '${card.brand} •••• ${card.last4}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Exp ${card.expiry}'),
                          onTap: () => setState(() {
                            _selectedSavedCard = card;
                            _useNewCard = false;
                          }),
                        ),
                      );
                    },
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _useNewCard = !_useNewCard),
                    icon: Icon(
                      _useNewCard ? Icons.close : Icons.add_card_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _useNewCard ? 'Use Saved Card' : 'Pay with New Card',
                    ),
                  ),
                ],
                if (_useNewCard)
                  Form(
                    key: _cardFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _cardNumberController,
                          validator: Validators.cardNumber,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Card Number',
                            hintText: '4532 8821 0043 4242',
                            prefixIcon: Icon(Icons.credit_card_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _cardHolderController,
                          validator: (v) => Validators.requiredText(
                            v,
                            fieldName: 'Cardholder name',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cardholder Name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expiryController,
                                validator: Validators.cardExpiry,
                                decoration: const InputDecoration(
                                  labelText: 'MM/YY',
                                  hintText: '12/28',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _cvvController,
                                validator: Validators.cardCvv,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'CVV',
                                  hintText: '123',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _proceedToVerification(currency),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Proceed to Verify & Pay'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
