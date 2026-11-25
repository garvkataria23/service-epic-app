import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/auth_repository.dart';
import 'package:service_epic/data/repositories/cart_order_repository.dart';
import 'package:service_epic/data/repositories/payment_repository.dart';
import 'package:service_epic/data/repositories/request_repository.dart';
import 'package:service_epic/data/repositories/service_repository.dart';
import 'package:service_epic/data/services/app_database.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/service_api_client.dart';
import 'package:service_epic/domain/models/service_category.dart';
import 'package:service_epic/domain/models/service_request.dart';
import 'package:service_epic/ui/features/cart/cart_view_model.dart';
import 'package:service_epic/ui/features/discovery/discovery_view_model.dart';
import 'package:service_epic/ui/features/request_detail/request_detail_view_model.dart';
import 'package:service_epic/ui/features/requests/requests_view_model.dart';
import 'package:service_epic/ui/features/submit_request/submit_request_view_model.dart';

void main() {
  late LocalStorageService storage;
  late AppDatabase db;
  late ServiceApiClient apiClient;
  late ServiceRepository serviceRepo;
  late RequestRepository requestRepo;
  late PaymentRepository paymentRepo;
  late CartOrderRepository cartRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    db = await AppDatabase.open(prefs, useSqlite: false);
    apiClient = ServiceApiClient(storage: storage);
    serviceRepo = ServiceRepository(
      apiClient: apiClient,
      storage: storage,
      database: db,
    );
    requestRepo = RequestRepository(apiClient: apiClient);
    paymentRepo = PaymentRepository(storage: storage);
    cartRepo = CartOrderRepository(
      database: db,
      storage: storage,
      paymentRepository: paymentRepo,
    );
    await AuthRepository(storage: storage).signInDemo();
  });

  test('DiscoveryViewModel handles NL search, favorites, and error recovery',
      () async {
    final vm = DiscoveryViewModel(repository: serviceRepo);
    await vm.loadServices();
    expect(vm.results.length, 12);

    await vm.submitSearch('plumber under \$100');
    expect(vm.parsedQuery.maxPrice, 100);
    expect(vm.results.any((m) => m.item.id == 'srv-01'), isTrue);

    await vm.toggleFavorite('srv-01');
    expect(vm.favoriteIds.contains('srv-01'), isTrue);

    await storage.setSimulateApiError(true);
    await vm.loadServices(forceRefresh: true);
    expect(vm.errorMessage, isNotNull);

    await storage.setSimulateApiError(false);
    await vm.loadServices(forceRefresh: true);
    expect(vm.errorMessage, isNull);
    vm.dispose();
  });

  test('SubmitRequestViewModel + RequestDetailViewModel end-to-end flow',
      () async {
    final submitVm = SubmitRequestViewModel(repository: requestRepo);
    final created = await submitVm.submitNew(
      title: 'Fix bathroom pipe leak urgently',
      category: ServiceCategory.homeRepair,
      description: 'Pipe behind sink is leaking continuously since morning.',
      budgetMin: 80,
      budgetMax: 150,
      urgency: RequestUrgency.urgent,
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      location: 'Sector 14, Apt 4B',
      contactEmail: 'garv@example.com',
      contactPhone: '+1 555-019-2834',
      customAnswers: const {'propertyType': 'Apartment'},
      attachmentLabels: const ['Site Photo'],
    );
    expect(created, isNotNull);
    expect(created!.attachmentLabels, ['Site Photo']);

    final detailVm = RequestDetailViewModel(
      repository: requestRepo,
      initialRequest: created,
    );
    await detailVm.loadResponses();
    expect(detailVm.filteredResponses.length, 2);

    final quote = detailVm.filteredResponses.first;
    final msgCountBefore = quote.messages.length;
    final sent = await detailVm.sendMessage(quote, 'Can you offer a \$10 discount?');
    expect(sent, isTrue);
    // Client message + automatic provider reply
    expect(detailVm.filteredResponses.first.messages.length, msgCountBefore + 2);

    final reqVm = RequestsViewModel(repository: requestRepo);
    await reqVm.loadRequests();
    expect(reqVm.allRequests.any((r) => r.id == created.id), isTrue);
    reqVm.dispose();
  });

  test('CartViewModel adds, updates quantity, and refreshes orders', () async {
    final cartVm = CartViewModel(repository: cartRepo);
    await cartVm.loadAll();
    final services = await db.getAllServices();
    final srv = services.first;

    await cartVm.addToCart(service: srv, package: srv.packages.first, quantity: 2);
    expect(cartVm.totalItemCount, 2);

    await cartVm.updateQuantity(cartVm.items.first.id, 3);
    expect(cartVm.totalItemCount, 3);
  });
}
