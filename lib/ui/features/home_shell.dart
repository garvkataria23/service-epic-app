import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_request.dart';
import 'account/account_dashboard_screen.dart';
import 'discovery/discovery_screen.dart';
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
                          leading: Icon(
                            _notifIcon(n.type),
                            color: AppColors.primary,
                          ),
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
          AccountDashboardScreen(
            isDarkMode: widget.isDarkMode,
            onToggleDarkMode: widget.onToggleDarkMode,
            onOpenRequestsTab: () => setState(() => _currentIndex = 1),
            onOpenWalletTab: () => setState(() => _currentIndex = 2),
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
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
