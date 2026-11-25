import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/app_database.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../domain/models/user_profile.dart';
import '../auth/auth_screen.dart';
import '../auth/auth_view_model.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_view_model.dart';
import '../discovery/discovery_view_model.dart';
import '../payment/transactions_screen.dart';
import '../requests/requests_view_model.dart';

class AccountDashboardScreen extends StatefulWidget {
  const AccountDashboardScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.onOpenRequestsTab,
    required this.onOpenWalletTab,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final VoidCallback onOpenRequestsTab;
  final VoidCallback onOpenWalletTab;

  @override
  State<AccountDashboardScreen> createState() => _AccountDashboardScreenState();
}

class _AccountDashboardScreenState extends State<AccountDashboardScreen> {
  Future<void> _editProfileDialog(AuthViewModel authVm) async {
    final user = authVm.currentUser;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final cityCtrl = TextEditingController(text: user.city);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Account Details'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) =>
                      Validators.requiredText(v, fieldName: 'Full name'),
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email ID'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneCtrl,
                  validator: Validators.phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: cityCtrl,
                  validator: Validators.location,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx);
              await authVm.updateProfile(
                user.copyWith(
                  fullName: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().toLowerCase(),
                  phone: phoneCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                ),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account profile updated!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
  }

  Future<void> _addAddressDialog(AuthViewModel authVm) async {
    final user = authVm.currentUser;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final labelCtrl = TextEditingController(text: 'Home');
    final addrCtrl = TextEditingController();
    var makeDefault = user.savedAddresses.isEmpty;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Service Address'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: labelCtrl,
                    validator: (v) =>
                        Validators.requiredText(v, fieldName: 'Label'),
                    decoration: const InputDecoration(
                      labelText: 'Label (Home, Office, Studio)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addrCtrl,
                    validator: Validators.location,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Full Street Address',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as default address'),
                    value: makeDefault,
                    onChanged: (v) =>
                        setDialogState(() => makeDefault = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx);
                final existing = makeDefault
                    ? user.savedAddresses
                        .map(
                          (a) => SavedAddress(
                            id: a.id,
                            label: a.label,
                            fullAddress: a.fullAddress,
                            isDefault: false,
                          ),
                        )
                        .toList()
                    : List<SavedAddress>.from(user.savedAddresses);

                existing.add(
                  SavedAddress(
                    id: 'ADDR-${DateTime.now().millisecondsSinceEpoch}',
                    label: labelCtrl.text.trim(),
                    fullAddress: addrCtrl.text.trim(),
                    isDefault: makeDefault,
                  ),
                );
                await authVm.updateProfile(
                  user.copyWith(savedAddresses: existing),
                );
              },
              child: const Text('Save Address'),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
    addrCtrl.dispose();
  }

  Future<void> _addCardDialog(AuthViewModel authVm) async {
    final user = authVm.currentUser;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController();
    final holderCtrl = TextEditingController(text: user.fullName.toUpperCase());
    final expCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Card'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numCtrl,
                  validator: Validators.cardNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    hintText: '4242 4242 4242 4242',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: holderCtrl,
                  validator: (v) =>
                      Validators.requiredText(v, fieldName: 'Holder name'),
                  decoration: const InputDecoration(labelText: 'Cardholder Name'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: expCtrl,
                        validator: Validators.cardExpiry,
                        decoration: const InputDecoration(
                          labelText: 'MM/YY',
                          hintText: '08/29',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: cvvCtrl,
                        validator: Validators.cardCvv,
                        obscureText: true,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx);
              final digits = numCtrl.text.replaceAll(RegExp(r'\D'), '');
              final card = SavedCard(
                id: 'CARD-${DateTime.now().millisecondsSinceEpoch}',
                brand: Validators.detectCardBrand(digits),
                last4: digits.substring(digits.length - 4),
                expiry: expCtrl.text.trim(),
                holderName: holderCtrl.text.trim().toUpperCase(),
              );
              await authVm.updateProfile(
                user.copyWith(savedCards: [...user.savedCards, card]),
              );
            },
            child: const Text('Save Card'),
          ),
        ],
      ),
    );
    numCtrl.dispose();
    holderCtrl.dispose();
    expCtrl.dispose();
    cvvCtrl.dispose();
  }

  Future<void> _changePasswordDialog(AuthViewModel authVm) async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    validator: Validators.password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    validator: Validators.strongPassword,
                    obscureText: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                  ),
                  if (newCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    PasswordStrengthIndicator(password: newCtrl.text),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    validator: (v) =>
                        Validators.confirmPassword(v, newCtrl.text),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSaving = true);
                      final err = await authVm.changePassword(
                        currentPassword: currentCtrl.text,
                        newPassword: newCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ?? 'Password updated successfully!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final currency = context.watch<CurrencyController>();
    final requestsVm = context.watch<RequestsViewModel>();
    final cartVm = context.watch<CartViewModel>();
    final discoveryVm = context.read<DiscoveryViewModel>();
    final storage = context.read<LocalStorageService>();
    final user = authVm.currentUser;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final simulateError = storage.simulateApiError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Dashboard'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Edit Profile',
              onPressed: () => _editProfileDialog(authVm),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          // 1. Identity Hero Card with Email ID
          if (user != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  authVm.isEmailVerified
                                      ? Icons.verified_rounded
                                      : Icons.info_outline_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user.phone} • ${user.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HeroTag('ID: ${user.id}'),
                      _HeroTag(
                        'Member since ${DateFormat.yMMM().format(user.joinedAt)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 2. 2x2 Responsive Dashboard KPIs (Zero Overflow)
          Row(
            children: [
              Expanded(
                child: _DashboardTile(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  label: 'Wallet Balance',
                  value: currency.format(user?.walletBalance ?? 0),
                  onTap: widget.onOpenWalletTab,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardTile(
                  icon: Icons.assignment_rounded,
                  color: AppColors.accentAmber,
                  label: 'Active Requests',
                  value: '${requestsVm.activeCount}',
                  onTap: widget.onOpenRequestsTab,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DashboardTile(
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.success,
                  label: 'Placed Orders',
                  value: '${cartVm.orders.length}',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CartScreen(initialTab: 1),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardTile(
                  icon: Icons.shopping_cart_rounded,
                  color: AppColors.info,
                  label: 'Cart Items',
                  value: '${cartVm.totalItemCount}',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CartScreen(initialTab: 0),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Saved Addresses Setup
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved Service Addresses',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addAddressDialog(authVm),
                icon: const Icon(Icons.add_location_alt_outlined, size: 17),
                label: const Text('Add'),
              ),
            ],
          ),
          Card(
            child: user == null || user.savedAddresses.isEmpty
                ? ListTile(
                    title: const Text('No saved addresses'),
                    subtitle: const Text('Tap Add to save your service address'),
                    trailing: TextButton(
                      onPressed: () => _addAddressDialog(authVm),
                      child: const Text('Add'),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < user.savedAddresses.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            user.savedAddresses[i].isDefault
                                ? Icons.home_rounded
                                : Icons.location_on_outlined,
                            color: user.savedAddresses[i].isDefault
                                ? colors.primary
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.savedAddresses[i].label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (user.savedAddresses[i].isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(user.savedAddresses[i].fullAddress),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!user.savedAddresses[i].isDefault)
                                TextButton(
                                  onPressed: () async {
                                    final updated = user.savedAddresses
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => SavedAddress(
                                            id: entry.value.id,
                                            label: entry.value.label,
                                            fullAddress:
                                                entry.value.fullAddress,
                                            isDefault: entry.key == i,
                                          ),
                                        )
                                        .toList();
                                    await authVm.updateProfile(
                                      user.copyWith(savedAddresses: updated),
                                    );
                                  },
                                  child: const Text('Set Default'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  final updated = List<SavedAddress>.from(
                                    user.savedAddresses,
                                  )..removeAt(i);
                                  await authVm.updateProfile(
                                    user.copyWith(savedAddresses: updated),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          // 4. Saved Payment Cards Setup
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved Payment Cards',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addCardDialog(authVm),
                icon: const Icon(Icons.add_card_rounded, size: 17),
                label: const Text('Add Card'),
              ),
            ],
          ),
          Card(
            child: user == null || user.savedCards.isEmpty
                ? ListTile(
                    title: const Text('No saved cards'),
                    subtitle: const Text('Add a Visa/Mastercard for 1-tap checkout'),
                    trailing: TextButton(
                      onPressed: () => _addCardDialog(authVm),
                      child: const Text('Add'),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < user.savedCards.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.credit_card_rounded),
                          title: Text(
                            '${user.savedCards[i].brand} •••• ${user.savedCards[i].last4}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Expires ${user.savedCards[i].expiry} • ${user.savedCards[i].holderName}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final updated = List<SavedCard>.from(
                                user.savedCards,
                              )..removeAt(i);
                              await authVm.updateProfile(
                                user.copyWith(savedCards: updated),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 18),
          Text(
            'Security & Preferences',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your password securely'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _changePasswordDialog(authVm),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    authVm.isEmailVerified
                        ? Icons.verified_user_rounded
                        : Icons.mark_email_unread_outlined,
                    color: authVm.isEmailVerified
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  title: Text(
                    authVm.isEmailVerified
                        ? 'Email ID Verified'
                        : 'Verify Your Email ID',
                  ),
                  subtitle: Text(
                    user?.email ?? 'Tap to send verification email',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: authVm.isEmailVerified
                      ? null
                      : () async {
                          final err = await authVm.sendEmailVerification();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                err ?? 'Verification email sent!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Wallet & Escrow Ledger'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TransactionsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.currency_exchange_rounded),
                  title: Text(
                    'Display Currency (${currency.currency.code} ${currency.currency.symbol})',
                  ),
                  subtitle: Text(
                    currency.isInr
                        ? 'Showing Indian Rupees (₹) • Tap to switch to USD (\$)'
                        : 'Showing US Dollars (\$) • Tap to switch to INR (₹)',
                  ),
                  value: currency.isInr,
                  onChanged: (_) => currency.toggle(),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  value: widget.isDarkMode,
                  onChanged: widget.onToggleDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_off_rounded),
                  title: const Text('Simulate API / Network Error'),
                  subtitle: const Text('Test error handling & retry flows'),
                  value: simulateError,
                  onChanged: (val) async {
                    await storage.setSimulateApiError(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Reset Demo Data'),
                  onTap: () async {
                    final db = context.read<AppDatabase>();
                    await storage.clearAllData();
                    await storage.setSimulateApiError(false);
                    await db.resetDatabase();
                    await discoveryVm.loadServices(forceRefresh: true);
                    await requestsVm.loadRequests();
                    await cartVm.loadAll();
                    if (!context.mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demo data & database restored!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: authVm.signOut,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cloud & Database Diagnostics',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Firebase: ${AppEnv.firebaseProjectId} (${AppEnv.firebaseInitialized ? "Initialized" : "Local Fallback"})',
                    style:
                        TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                  FutureBuilder<Map<String, int>>(
                    future: context.read<AppDatabase>().getTableCounts(),
                    builder: (context, snap) {
                      final db = context.read<AppDatabase>();
                      final counts = snap.data;
                      return Text(
                        counts != null
                            ? '${db.engineName} • services: ${counts['services']} • cart: ${counts['cart_items']} • orders: ${counts['orders']}'
                            : db.engineName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
