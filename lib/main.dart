import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_env.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/currency_formatter.dart';
import 'core/utils/location_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cart_order_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/request_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/service_api_client.dart';
import 'firebase_options.dart';
import 'ui/features/auth/auth_screen.dart';
import 'ui/features/auth/auth_view_model.dart';
import 'ui/features/cart/cart_view_model.dart';
import 'ui/features/discovery/discovery_view_model.dart';
import 'ui/features/home_shell.dart';
import 'ui/features/requests/requests_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production error boundary so uncaught errors never crash silently or render raw red screens
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled async error: $error');
    return true;
  };
  ErrorWidget.builder = (details) => Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Something went wrong while rendering this view.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );

  await AppEnv.load();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppEnv.firebaseInitialized = true;
  } catch (_) {
    AppEnv.firebaseInitialized = false;
  }

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final database = await AppDatabase.open(prefs);
  final apiClient = ServiceApiClient(storage: storage);
  final serviceRepo = ServiceRepository(
    apiClient: apiClient,
    storage: storage,
    database: database,
  );
  final requestRepo = RequestRepository(apiClient: apiClient);
  final authRepo = AuthRepository(storage: storage);
  final paymentRepo = PaymentRepository(storage: storage);
  final cartOrderRepo = CartOrderRepository(
    database: database,
    storage: storage,
    paymentRepository: paymentRepo,
  );

  runApp(
    ServiceEpicApp(
      storage: storage,
      database: database,
      serviceRepository: serviceRepo,
      requestRepository: requestRepo,
      authRepository: authRepo,
      paymentRepository: paymentRepo,
      cartOrderRepository: cartOrderRepo,
    ),
  );
}

class ServiceEpicApp extends StatefulWidget {
  const ServiceEpicApp({
    super.key,
    required this.storage,
    required this.database,
    required this.serviceRepository,
    required this.requestRepository,
    required this.authRepository,
    required this.paymentRepository,
    required this.cartOrderRepository,
  });

  final LocalStorageService storage;
  final AppDatabase database;
  final ServiceRepository serviceRepository;
  final RequestRepository requestRepository;
  final AuthRepository authRepository;
  final PaymentRepository paymentRepository;
  final CartOrderRepository cartOrderRepository;

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
        Provider<AppDatabase>.value(value: widget.database),
        Provider<ServiceRepository>.value(value: widget.serviceRepository),
        Provider<RequestRepository>.value(value: widget.requestRepository),
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<PaymentRepository>.value(value: widget.paymentRepository),
        Provider<CartOrderRepository>.value(value: widget.cartOrderRepository),
        ChangeNotifierProvider<CurrencyController>(
          create: (_) => CurrencyController(storage: widget.storage),
        ),
        ChangeNotifierProvider<LocationController>(
          create: (_) => LocationController(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(repository: widget.authRepository),
        ),
        ChangeNotifierProvider<CartViewModel>(
          create: (_) =>
              CartViewModel(repository: widget.cartOrderRepository)..loadAll(),
        ),
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
        title: 'Epic Infocus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 640) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 540),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRect(child: child),
                    ),
                  ),
                );
              }
              return child;
            },
          );
        },
        home: Consumer<AuthViewModel>(
          builder: (context, authVm, _) {
            if (!authVm.isAuthenticated) {
              return const AuthScreen();
            }
            return HomeShell(
              isDarkMode: _isDarkMode,
              onToggleDarkMode: _toggleDarkMode,
            );
          },
        ),
      ),
    );
  }
}
