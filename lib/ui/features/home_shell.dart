import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/services/app_database.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_request.dart';
import 'auth/auth_screen.dart';
import 'auth/auth_view_model.dart';
import 'cart/cart_screen.dart';
import 'cart/cart_view_model.dart';
import 'discovery/discovery_screen.dart';
import 'discovery/discovery_view_model.dart';
import 'payment/transactions_screen.dart';
import 'request_detail/request_detail_screen.dart';
import 'request_detail/request_detail_view_model.dart';
import 'requests/requests_screen.dart';
import 'requests/requests_view_model.dart';
import 'submit_request/submit_request_screen.dart';
import 'submit_request/submit_request_view_model.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  Future<void> _openSubmitFlow({
    ServiceItem? service,
    ServicePackage? package,
  }) async {
    final reqRepo = context.read<RequestRepository>();
    final requestsVm = context.read<RequestsViewModel>();

    final created = await Navigator.of(context).push<ServiceRequest>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => SubmitRequestViewModel(repository: reqRepo),
          child: SubmitRequestScreen(
            linkedService: service,
            selectedPackage: package,
            onSubmitted: (req) => Navigator.of(context).pop(req),
          ),
        ),
      ),
    );

    if (created != null && mounted) {
      await requestsVm.loadRequests();
      setState(() => _currentIndex = 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted ${created.id} & received initial quotes!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openRequestDetail(created);
    }
  }

  Future<void> _openRequestDetail(ServiceRequest request) async {
    final reqRepo = context.read<RequestRepository>();
    final requestsVm = context.read<RequestsViewModel>();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => RequestDetailViewModel(
            repository: reqRepo,
            initialRequest: request,
          )..loadResponses(),
          child: RequestDetailScreen(
            onEditRequest: (req) async {
              return Navigator.of(context).push<ServiceRequest>(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => SubmitRequestViewModel(repository: reqRepo),
                    child: SubmitRequestScreen(
                      editingRequest: req,
                      onSubmitted: (saved) => Navigator.of(context).pop(saved),
                    ),
                  ),
                ),
              );
            },
            onRequestChanged: () {
              requestsVm.loadRequests();
            },
          ),
        ),
      ),
    );
    if (mounted) {
      requestsVm.loadRequests();
    }
  }

  Future<void> _openNotificationsSheet() async {
    final paymentRepo = context.read<PaymentRepository>();
    final requestsVm = context.read<RequestsViewModel>();
    final notifs = paymentRepo.getNotifications();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await paymentRepo.markAllNotificationsRead();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() {});
                    },
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notifs.isEmpty
                  ? const Center(child: Text('No notifications yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, idx) {
                        final n = notifs[idx];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: n.isRead
                              ? null
                              : Theme.of(ctx)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                          leading: Icon(_notifIcon(n.type),
                              color: AppColors.primary),
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.body),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat.MMMd().add_jm().format(n.createdAt),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (n.relatedRequestId != null) {
                              final req = requestsVm.allRequests
                                  .where((r) => r.id == n.relatedRequestId)
                                  .firstOrNull;
                              if (req != null) _openRequestDetail(req);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  IconData _notifIcon(NotificationType type) {
    return switch (type) {
      NotificationType.quote => Icons.local_offer_rounded,
      NotificationType.message => Icons.chat_bubble_outline_rounded,
      NotificationType.payment => Icons.verified_user_rounded,
      NotificationType.status => Icons.notifications_active_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final requestsVm = context.watch<RequestsViewModel>();
    final paymentRepo = context.read<PaymentRepository>();
    final unreadNotifs =
        paymentRepo.getNotifications().where((n) => !n.isRead).length;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DiscoveryScreen(
            onRequestService: (srv, pkg) =>
                _openSubmitFlow(service: srv, package: pkg),
            onPostCustomRequest: () => _openSubmitFlow(),
            unreadNotifications: unreadNotifs,
            onNotificationsTap: _openNotificationsSheet,
          ),
          RequestsScreen(
            onOpenRequestDetail: _openRequestDetail,
            onCreateRequest: () => _openSubmitFlow(),
          ),
          const TransactionsScreen(),
          _ProfileTab(
            isDarkMode: widget.isDarkMode,
            onToggleDarkMode: widget.onToggleDarkMode,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: requestsVm.pendingQuotesCount > 0,
              label: Text('${requestsVm.pendingQuotesCount}'),
              child: const Icon(Icons.assignment_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: requestsVm.pendingQuotesCount > 0,
              label: Text('${requestsVm.pendingQuotesCount}'),
              child: const Icon(Icons.assignment_rounded),
            ),
            label: 'Requests',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<void> _editProfileDialog(AuthViewModel authVm) async {
    final user = authVm.currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone);
    final cityCtrl = TextEditingController(text: user.city);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authVm.updateProfile(
                user.copyWith(
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
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
    final user = authVm.currentUser;
    final storage = context.read<LocalStorageService>();
    final discoveryVm = context.read<DiscoveryViewModel>();
    final requestsVm = context.read<RequestsViewModel>();
    final simulateError = storage.simulateApiError;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Account & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.primaryContainer,
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.onPrimaryContainer,
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
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${user.city} • ${user.savedCards.length} saved card(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit Profile',
                      onPressed: () => _editProfileDialog(authVm),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
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
                        ? 'Email Verified'
                        : 'Verify Your Email',
                  ),
                  subtitle: Text(
                    authVm.isEmailVerified
                        ? 'Your account email is verified'
                        : 'Tap to send a verification email',
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
              ],
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch between light and dark themes'),
                  value: widget.isDarkMode,
                  onChanged: widget.onToggleDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_off_rounded),
                  title: const Text('Simulate API / Network Error'),
                  subtitle: const Text(
                    'Enable to test error handling, payment failure & retry flows',
                  ),
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
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('My Cart & Orders'),
                  subtitle: const Text(
                    'View saved cart items, placed orders & Return / Replace',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CartScreen(initialTab: 1),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Reset Demo Data'),
                  subtitle: const Text(
                    'Restore initial services, requests, quotes & escrow ledger',
                  ),
                  onTap: () async {
                    final db = context.read<AppDatabase>();
                    final cartVm = context.read<CartViewModel>();
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
                        content: Text('Demo data restored!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
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
                    'Cloud & Trial Environment (.env)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firebase Project: ${AppEnv.firebaseProjectId} (${AppEnv.firebaseInitialized ? "Initialized" : "Local Fallback"})',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                  Text(
                    'MongoDB URI: ${AppEnv.mongoDbUri}',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                  Text(
                    'Razorpay Test Key: ${AppEnv.razorpayKeyId}',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                  const Divider(height: 18),
                  FutureBuilder<Map<String, int>>(
                    future: context.read<AppDatabase>().getTableCounts(),
                    builder: (context, snap) {
                      final db = context.read<AppDatabase>();
                      final counts = snap.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Engine: ${db.engineName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (counts != null)
                            Text(
                              'Tables → services: ${counts['services']} • cart_items: ${counts['cart_items']} • orders: ${counts['orders']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
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
