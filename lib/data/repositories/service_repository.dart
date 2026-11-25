import '../../core/errors/app_exception.dart';
import '../../domain/models/service_item.dart';
import '../services/app_database.dart';
import '../services/local_storage_service.dart';
import '../services/service_api_client.dart';

class ServiceRepository {
  ServiceRepository({
    required ServiceApiClient apiClient,
    required LocalStorageService storage,
    AppDatabase? database,
  })  : _apiClient = apiClient,
        _storage = storage,
        _database = database;

  final ServiceApiClient _apiClient;
  final LocalStorageService _storage;
  final AppDatabase? _database;

  List<ServiceItem>? _cachedServices;

  Future<Result<List<ServiceItem>>> getServices({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedServices != null) {
      return Success(_cachedServices!);
    }
    try {
      if (!forceRefresh && _database != null && !_storage.simulateApiError) {
        final dbServices = await _database.getAllServices();
        if (dbServices.isNotEmpty) {
          _cachedServices = dbServices;
          return Success(dbServices);
        }
      }
      final services = await _apiClient.fetchServices();
      await _database?.upsertServices(services);
      _cachedServices = services;
      return Success(services);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Unexpected error loading services: $e', e));
    }
  }

  Set<String> getFavoriteIds() => _storage.loadFavoriteIds();

  Future<Set<String>> toggleFavorite(String serviceId) async {
    final ids = _storage.loadFavoriteIds();
    if (ids.contains(serviceId)) {
      ids.remove(serviceId);
    } else {
      ids.add(serviceId);
    }
    await _storage.saveFavoriteIds(ids);
    return ids;
  }

  List<String> getRecentSearches() => _storage.loadRecentSearches();

  Future<List<String>> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return getRecentSearches();
    final current = _storage.loadRecentSearches().toList();
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    if (current.length > 8) {
      current.removeRange(8, current.length);
    }
    await _storage.saveRecentSearches(current);
    return current;
  }

  Future<List<String>> removeRecentSearch(String query) async {
    final current = _storage.loadRecentSearches().toList()
      ..removeWhere((q) => q == query);
    await _storage.saveRecentSearches(current);
    return current;
  }

  Future<void> clearRecentSearches() => _storage.saveRecentSearches(const []);
}
