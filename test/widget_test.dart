import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/request_repository.dart';
import 'package:service_epic/data/repositories/service_repository.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/service_api_client.dart';
import 'package:service_epic/main.dart';

void main() {
  testWidgets('ServiceEpicApp renders Discovery and navigation tabs',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final apiClient = ServiceApiClient(storage: storage);
    final serviceRepo = ServiceRepository(apiClient: apiClient, storage: storage);
    final requestRepo = RequestRepository(apiClient: apiClient);

    await tester.pumpWidget(
      ServiceEpicApp(
        storage: storage,
        serviceRepository: serviceRepo,
        requestRepository: requestRepo,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Discover Services'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
