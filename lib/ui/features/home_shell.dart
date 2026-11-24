import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/request_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_request.dart';
import 'discovery/discovery_screen.dart';
import 'discovery/discovery_view_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final requestsVm = context.watch<RequestsViewModel>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DiscoveryScreen(
            onRequestService: (srv, pkg) =>
                _openSubmitFlow(service: srv, package: pkg),
            onPostCustomRequest: () => _openSubmitFlow(),
          ),
          RequestsScreen(
            onOpenRequestDetail: _openRequestDetail,
            onCreateRequest: () => _openSubmitFlow(),
          ),
          _SettingsTab(
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
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final storage = context.read<LocalStorageService>();
    final discoveryVm = context.read<DiscoveryViewModel>();
    final requestsVm = context.read<RequestsViewModel>();
    final simulateError = storage.simulateApiError;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    'Enable to test error handling, validation & retry flows',
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
            child: ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Reset Demo Data'),
              subtitle: const Text(
                'Restore initial sample services, requests, and provider quotes',
              ),
              onTap: () async {
                await storage.clearAllData();
                await storage.setSimulateApiError(false);
                await discoveryVm.loadServices(forceRefresh: true);
                await requestsVm.loadRequests();
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
          ),
          const SizedBox(height: 20),
          Text(
            'Architecture Highlights',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '• Clean MVVM + Repository Pattern with Provider\n'
                '• Typed AppException & Result<T> error handling\n'
                '• Smart Search Engine: Damerau-Levenshtein fuzzy matching, synonym intent expansion, & natural language filter parsing\n'
                '• Local-first persistence with REST API client adapter',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
