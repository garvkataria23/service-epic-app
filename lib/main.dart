import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/request_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/service_api_client.dart';
import 'ui/features/discovery/discovery_view_model.dart';
import 'ui/features/home_shell.dart';
import 'ui/features/requests/requests_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final apiClient = ServiceApiClient(storage: storage);
  final serviceRepo = ServiceRepository(apiClient: apiClient, storage: storage);
  final requestRepo = RequestRepository(apiClient: apiClient);

  runApp(
    ServiceEpicApp(
      storage: storage,
      serviceRepository: serviceRepo,
      requestRepository: requestRepo,
    ),
  );
}

class ServiceEpicApp extends StatefulWidget {
  const ServiceEpicApp({
    super.key,
    required this.storage,
    required this.serviceRepository,
    required this.requestRepository,
  });

  final LocalStorageService storage;
  final ServiceRepository serviceRepository;
  final RequestRepository requestRepository;

  @override
  State<ServiceEpicApp> createState() => _ServiceEpicAppState();
}

class _ServiceEpicAppState extends State<ServiceEpicApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.storage.isDarkMode;
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await widget.storage.setDarkMode(value);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: widget.storage),
        Provider<ServiceRepository>.value(value: widget.serviceRepository),
        Provider<RequestRepository>.value(value: widget.requestRepository),
        ChangeNotifierProvider<DiscoveryViewModel>(
          create: (_) =>
              DiscoveryViewModel(repository: widget.serviceRepository)
                ..loadServices(),
        ),
        ChangeNotifierProvider<RequestsViewModel>(
          create: (_) =>
              RequestsViewModel(repository: widget.requestRepository)
                ..loadRequests(),
        ),
      ],
      child: MaterialApp(
        title: 'ServiceEpic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: HomeShell(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: _toggleDarkMode,
        ),
      ),
    );
  }
}
