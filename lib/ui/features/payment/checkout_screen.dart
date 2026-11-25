import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/app_env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/cart_order_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_request.dart';
import '../../../domain/models/user_profile.dart';
import '../../core/widgets/confirmation_banner.dart';
import '../auth/auth_view_model.dart';
import '../cart/cart_view_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.request,
    this.quote,
    this.cartItems,
    this.clearCartAfter = false,
  });

  final ServiceRequest? request;
  final ProviderResponse? quote;
  final List<CartItem>? cartItems;
  final bool clearCartAfter;

  bool get isDirectOrder => cartItems != null && cartItems!.isNotEmpty;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cardFormKey = GlobalKey<FormState>();
  final _upiFormKey = GlobalKey<FormState>();

  final _promoController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _upiController = TextEditingController();

  PaymentMethodType _method = PaymentMethodType.card;
  SavedCard? _selectedSavedCard;
  bool _useNewCard = false;
  bool _saveNewCard = true;
  String? _appliedPromo;
  double _discountRate = 0.0;
  String? _promoFeedback;
  bool _isProcessing = false;
  String? _errorBanner;
  Razorpay? _razorpay;

  static const List<String> _timeSlots = [
    '9:00 AM – 11:00 AM',
    '10:00 AM – 12:00 PM',
    '2:00 PM – 4:00 PM',
    '5:00 PM – 7:00 PM',
  ];
  String _selectedSlot = '10:00 AM – 12:00 PM';
  String _selectedAddress = 'Home • Default Location';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null && user.savedCards.isNotEmpty) {
      _selectedSavedCard = user.savedCards.first;
      _useNewCard = false;
    } else {
      _useNewCard = true;
    }
    if (user != null && user.savedAddresses.isNotEmpty) {
      final def = user.savedAddresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => user.savedAddresses.first,
      );
      _selectedAddress = '${def.label} • ${def.fullAddress}';
    } else if (user != null && user.city.isNotEmpty) {
      _selectedAddress = 'Primary • ${user.city}';
    }
    _cardHolderController.text = user?.fullName.toUpperCase() ?? '';
    if (!kIsWeb) {
      try {
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
      } catch (_) {
        _razorpay = null;
      }
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _promoController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.isDirectOrder
      ? widget.cartItems!.fold<double>(0, (sum, i) => sum + i.lineTotal)
      : (widget.quote?.quotedPrice ?? 0);
  double get _platformFee =>
      double.parse((_subtotal * 0.03).toStringAsFixed(2));
  double get _discount =>
      double.parse((_subtotal * _discountRate).toStringAsFixed(2));
  double get _total =>
      double.parse((_subtotal + _platformFee - _discount).toStringAsFixed(2));

  Future<void> _onRazorpaySuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    await _completePaymentRecord(
      method: PaymentMethodType.card,
      methodDetail: 'Razorpay (${response.paymentId ?? 'Test'})',
    );
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorBanner =
          response.message ?? 'Razorpay checkout was cancelled or failed.';
    });
  }

  void _launchRazorpayCheckout() {
    final user = context.read<AuthViewModel>().currentUser;
    if (_razorpay == null || user == null) {
      setState(() {
        _errorBanner =
            'Razorpay native SDK is available on Android devices. Use Card/UPI/Wallet below.';
      });
      return;
    }
    final options = {
      'key': AppEnv.razorpayKeyId,
      'amount': (_total * 100).round(),
      'name': 'Epic Infocus',
      'description': widget.isDirectOrder
          ? 'Service Order Checkout'
          : (widget.request?.title ?? 'Escrow Booking'),
      'prefill': {
        'contact': user.phone,
        'email': user.email,
      },
    };
    try {
      _razorpay!.open(options);
    } catch (e) {
      setState(() {
        _errorBanner = 'Unable to open Razorpay SDK: $e';
      });
    }
  }

  Future<void> _completePaymentRecord({
    required PaymentMethodType method,
    required String methodDetail,
    SavedCard? cardToSave,
  }) async {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    if (widget.isDirectOrder) {
      final orderRepo = context.read<CartOrderRepository>();
      final cartVm = context.read<CartViewModel>();
      final res = await orderRepo.placeDirectOrder(
        user: user,
        items: widget.cartItems!,
        method: method,
        methodDetail: methodDetail,
        promoCode: _appliedPromo,
        newCardToSave: cardToSave,
        clearCartAfter: widget.clearCartAfter,
        preferredSlot: _selectedSlot,
        serviceAddress: _selectedAddress,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      res.when(
        success: (order) async {
          authVm.refreshUserFromStorage();
          await cartVm.refreshOrders();
          if (!mounted) return;
          final txn = PaymentTransaction(
            id: order.transactionId,
            requestId: order.id,
            quoteId: 'DIRECT',
            providerName: order.items.first.providerName,
            serviceTitle: order.items.first.serviceTitle,
            subtotal: order.subtotal,
            platformFee: order.platformFee,
            discount: order.discount,
            totalAmount: order.totalAmount,
            method: order.paymentMethod,
            methodDetail: order.paymentDetail,
            status: EscrowStatus.heldInEscrow,
            promoCode: order.promoCode,
            createdAt: order.createdAt,
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<PaymentTransaction>(
              builder: (_) => _PaymentReceiptScreen(
                transaction: txn,
                isOrder: true,
                preferredSlot: order.preferredSlot,
                jobStartPin: order.jobStartPin,
                serviceAddress: order.serviceAddress,
              ),
            ),
          );
        },
        failure: (err) => setState(() => _errorBanner = err.message),
      );
      return;
    }

    final paymentRepo = context.read<PaymentRepository>();
    final res = await paymentRepo.processEscrowPayment(
      user: user,
      request: widget.request!,
      quote: widget.quote!,
      method: method,
      methodDetail: methodDetail,
      promoCode: _appliedPromo,
      newCardToSave: cardToSave,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    res.when(
      success: (txn) {
        authVm.refreshUserFromStorage();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<PaymentTransaction>(
            builder: (_) => _PaymentReceiptScreen(transaction: txn),
          ),
        );
      },
      failure: (err) => setState(() => _errorBanner = err.message),
    );
  }

  void _applyPromo() {
    final repo = context.read<PaymentRepository>();
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final rate = repo.validatePromoCode(code);
    setState(() {
      if (rate != null) {
        _appliedPromo = code;
        _discountRate = rate;
        _promoFeedback =
            'Promo $code applied (${(rate * 100).toStringAsFixed(0)}% off)!';
      } else {
        _appliedPromo = null;
        _discountRate = 0.0;
        _promoFeedback = 'Invalid promo code. Try EPIC10 or WELCOME15.';
      }
    });
  }

  Future<bool> _showOtpVerificationDialog(String methodLabel) async {
    final otpController = TextEditingController(text: '1234');
    final currency = context.read<CurrencyController>();
    String? otpError;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('3D-Secure Verification')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm payment of ${currency.formatExact(_total)} via $methodLabel.',
              ),
              const SizedBox(height: 8),
              Text(
                'Demo OTP: 1234',
                style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Enter 4-digit OTP',
                  errorText: otpError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (otpController.text.trim() == '1234') {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() {
                    otpError = 'Incorrect OTP. Use 1234 for demo.';
                  });
                }
              },
              child: const Text('Verify & Pay'),
            ),
          ],
        ),
      ),
    );
    otpController.dispose();
    return verified ?? false;
  }

  Future<void> _payNow() async {
    setState(() => _errorBanner = null);

    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    String methodDetail;
    SavedCard? cardToSave;

    if (_method == PaymentMethodType.card) {
      if (!_useNewCard && _selectedSavedCard != null) {
        methodDetail =
            '${_selectedSavedCard!.brand} •••• ${_selectedSavedCard!.last4}';
      } else {
        if (!(_cardFormKey.currentState?.validate() ?? false)) return;
        final digits =
            _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
        final brand = Validators.detectCardBrand(digits);
        final last4 = digits.substring(digits.length - 4);
        methodDetail = '$brand •••• $last4';
        if (_saveNewCard) {
          cardToSave = SavedCard(
            id: 'CARD-${DateTime.now().millisecondsSinceEpoch}',
            brand: brand,
            last4: last4,
            expiry: _expiryController.text.trim(),
            holderName: _cardHolderController.text.trim().toUpperCase(),
          );
        }
      }
    } else if (_method == PaymentMethodType.upi) {
      if (!(_upiFormKey.currentState?.validate() ?? false)) return;
      methodDetail = 'UPI (${_upiController.text.trim()})';
    } else {
      if (user.walletBalance < _total) {
        setState(() {
          _errorBanner =
              'Insufficient wallet balance (\$${user.walletBalance.toStringAsFixed(2)}). Top up or choose Card/UPI.';
        });
        return;
      }
      methodDetail = 'ServiceEpic Wallet';
    }

    final otpOk = await _showOtpVerificationDialog(methodDetail);
    if (!otpOk || !mounted) return;

    await _completePaymentRecord(
      method: _method,
      methodDetail: methodDetail,
      cardToSave: cardToSave,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final currency = context.watch<CurrencyController>();
    final user = authVm.currentUser;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Escrow Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Escrow Protection Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Escrow Protection: Funds are held securely and only released to the provider after you mark the job completed.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          if (_errorBanner != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Text(
                _errorBanner!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Order Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Summary',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.isDirectOrder) ...[
                    ...widget.cartItems!.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.serviceTitle} (${item.variantName})',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              currency.formatExact(item.lineTotal),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      widget.request?.title ?? '',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Provider: ${widget.quote?.providerName ?? ''} • ${widget.request?.id ?? ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Divider(height: 22),
                  _PriceRow('Quoted Amount', currency.formatExact(_subtotal)),
                  _PriceRow(
                    'Escrow Protection Fee (3%)',
                    currency.formatExact(_platformFee),
                  ),
                  if (_discount > 0)
                    _PriceRow(
                      'Promo ($_appliedPromo)',
                      '-${currency.formatExact(_discount)}',
                      valueColor: AppColors.success,
                    ),
                  const Divider(height: 18),
                  _PriceRow(
                    'Total Payable',
                    currency.formatExact(_total),
                    isBold: true,
                    valueColor: colors.primary,
                  ),
                ],
              ),
            ),
          ),

          if (widget.isDirectOrder) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Preferred Arrival / Kickoff Slot',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _timeSlots.map((slot) {
                        final selected = _selectedSlot == slot;
                        return ChoiceChip(
                          label: Text(slot),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedSlot = slot),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Service Visit Address',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final ctrl = TextEditingController();
                            final custom = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Add Visit Address'),
                                content: TextField(
                                  controller: ctrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Flat / Street / Landmark',
                                    hintText: 'e.g., Office • Sector 18, Noida',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, ctrl.text.trim()),
                                    child: const Text('Use Address'),
                                  ),
                                ],
                              ),
                            );
                            ctrl.dispose();
                            if (custom != null && custom.isNotEmpty && mounted) {
                              setState(() => _selectedAddress = custom);
                            }
                          },
                          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...(user?.savedAddresses ?? const []).map((addr) {
                          final formatted = '${addr.label} • ${addr.fullAddress}';
                          return ChoiceChip(
                            label: Text(
                              addr.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: _selectedAddress == formatted,
                            onSelected: (_) =>
                                setState(() => _selectedAddress = formatted),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedAddress,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Promo Code
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Promo Code (Try EPIC10 or WELCOME15)',
                    prefixIcon: Icon(Icons.local_offer_outlined),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _applyPromo,
                child: const Text('Apply'),
              ),
            ],
          ),
          if (_promoFeedback != null) ...[
            const SizedBox(height: 6),
            Text(
              _promoFeedback!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _discountRate > 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Payment Method',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (!kIsWeb && _razorpay != null)
                TextButton.icon(
                  onPressed: _isProcessing ? null : _launchRazorpayCheckout,
                  icon: const Icon(Icons.bolt_rounded, size: 17),
                  label: const Text('Razorpay SDK'),
                ),
            ],
          ),
          const SizedBox(height: 10),

          SegmentedButton<PaymentMethodType>(
            segments: const [
              ButtonSegment(
                value: PaymentMethodType.card,
                icon: Icon(Icons.credit_card_rounded, size: 18),
                label: Text('Card'),
              ),
              ButtonSegment(
                value: PaymentMethodType.upi,
                icon: Icon(Icons.account_balance_rounded, size: 18),
                label: Text('UPI'),
              ),
              ButtonSegment(
                value: PaymentMethodType.wallet,
                icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                label: Text('Wallet'),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),

          const SizedBox(height: 14),

          if (_method == PaymentMethodType.card) ...[
            if (user != null && user.savedCards.isNotEmpty) ...[
              ...user.savedCards.map(
                (card) {
                  final isSelected =
                      !_useNewCard && _selectedSavedCard?.id == card.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => setState(() {
                        _selectedSavedCard = card;
                        _useNewCard = false;
                      }),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text('${card.brand} •••• ${card.last4}'),
                      subtitle:
                          Text('Expires ${card.expiry} • ${card.holderName}'),
                    ),
                  );
                },
              ),
              TextButton.icon(
                onPressed: () => setState(() => _useNewCard = !_useNewCard),
                icon: Icon(_useNewCard ? Icons.close : Icons.add_card_rounded),
                label: Text(
                  _useNewCard ? 'Use Saved Card' : 'Pay with New Card',
                ),
              ),
            ],
            if (_useNewCard)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: _cardFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _cardNumberController,
                          validator: Validators.cardNumber,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Card Number',
                            hintText: '4242 4242 4242 4242',
                            prefixIcon: Icon(Icons.credit_card_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cardHolderController,
                          validator: (v) => Validators.requiredText(
                            v,
                            fieldName: 'Cardholder name',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Cardholder Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expiryController,
                                validator: Validators.cardExpiry,
                                keyboardType: TextInputType.datetime,
                                decoration: const InputDecoration(
                                  labelText: 'Expiry (MM/YY)',
                                  hintText: '08/29',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _cvvController,
                                validator: Validators.cardCvv,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'CVV',
                                  hintText: '123',
                                ),
                              ),
                            ),
                          ],
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Save card securely for future bookings'),
                          value: _saveNewCard,
                          onChanged: (v) =>
                              setState(() => _saveNewCard = v ?? true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ] else if (_method == PaymentMethodType.upi) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: _upiFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _upiController,
                        validator: Validators.upiId,
                        decoration: const InputDecoration(
                          labelText: 'Enter UPI ID',
                          hintText: 'garv@okaxis',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: ['garv@okaxis', 'garv@ybl', 'garv@paytm']
                            .map(
                              (handle) => ActionChip(
                                label: Text(handle),
                                onPressed: () =>
                                    setState(() => _upiController.text = handle),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Wallet Balance',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            currency.formatExact(user?.walletBalance ?? 0),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await authVm.topUpWallet(500);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${currency.formatExact(500)} to Wallet!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text('+ ${currency.format(500)}'),
                    ),
                  ],
                ),
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
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _payNow,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_rounded),
            label: Text(
              _isProcessing
                  ? 'Processing Secure Payment...'
                  : 'Pay ${currency.formatExact(_total)} in Escrow',
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                fontSize: isBold ? 15 : 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                fontSize: isBold ? 17 : 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentReceiptScreen extends StatelessWidget {
  const _PaymentReceiptScreen({
    required this.transaction,
    this.isOrder = false,
    this.preferredSlot,
    this.jobStartPin,
    this.serviceAddress,
  });

  final PaymentTransaction transaction;
  final bool isOrder;
  final String? preferredSlot;
  final String? jobStartPin;
  final String? serviceAddress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = context.watch<CurrencyController>();
    final formattedTotal = currency.formatExact(transaction.totalAmount);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Receipt')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConfirmationBanner(
                      data: ConfirmationBannerData(
                        title: isOrder
                            ? 'Order Confirmed & Protected'
                            : 'Quote Accepted & Escrow Locked',
                        badgeText: isOrder ? 'PIN: ${jobStartPin ?? '----'}' : 'ESCROW ACTIVE',
                        subtitle: isOrder
                            ? 'Booked for ${preferredSlot ?? '10:00 AM – 12:00 PM'}. You can reschedule or cancel for an instant wallet refund before work starts.'
                            : 'Funds are safely held in Escrow and released only after you mark the job completed.',
                        tone: ConfirmationTone.success,
                      ),
                      onDismiss: () {},
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Escrow Payment Successful',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedTotal,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _PriceRow('Transaction ID', transaction.id),
                    _PriceRow(
                      isOrder ? 'Order ID' : 'Request ID',
                      transaction.requestId,
                    ),
                    _PriceRow('Provider', transaction.providerName),
                    _PriceRow('Payment Method', transaction.methodDetail),
                    if (preferredSlot != null)
                      _PriceRow('Arrival Slot', preferredSlot!),
                    if (serviceAddress != null)
                      _PriceRow('Visit Address', serviceAddress!),
                    if (jobStartPin != null)
                      _PriceRow(
                        'Job-Start PIN',
                        jobStartPin!,
                        isBold: true,
                        valueColor: AppColors.primary,
                      ),
                    _PriceRow(
                      'Status',
                      transaction.status.label,
                      valueColor: AppColors.success,
                    ),
                    _PriceRow(
                      'Date',
                      DateFormat.yMMMd().add_jm().format(transaction.createdAt),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final summary = [
                            'EPIC INFOCUS — ESCROW INVOICE',
                            'Txn ID: ${transaction.id}',
                            '${isOrder ? 'Order' : 'Request'}: ${transaction.requestId}',
                            'Service: ${transaction.serviceTitle}',
                            'Provider: ${transaction.providerName}',
                            'Amount: $formattedTotal (${currency.currency.code})',
                            'Method: ${transaction.methodDetail}',
                            if (preferredSlot != null) 'Slot: $preferredSlot',
                            if (serviceAddress != null)
                              'Address: $serviceAddress',
                            if (jobStartPin != null)
                              'Job-Start PIN: $jobStartPin',
                            'Status: ${transaction.status.label}',
                            'Date: ${DateFormat.yMMMd().add_jm().format(transaction.createdAt)}',
                          ].join('\n');
                          await Clipboard.setData(ClipboardData(text: summary));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invoice copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Invoice'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(transaction),
                        child: Text(isOrder ? 'Done' : 'Back to Request'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
