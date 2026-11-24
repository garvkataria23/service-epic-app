import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/payment_transaction.dart';
import '../../domain/models/provider_response.dart';
import '../../domain/models/service_request.dart';
import '../../domain/models/user_profile.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _requestsKey = 'service_epic_requests_v1';
  static const _responsesKey = 'service_epic_responses_v1';
  static const _favoritesKey = 'service_epic_favorites_v1';
  static const _recentSearchesKey = 'service_epic_recent_searches_v1';
  static const _seededKey = 'service_epic_seeded_v1';
  static const _simulateErrorKey = 'service_epic_simulate_error_v1';
  static const _darkModeKey = 'service_epic_dark_mode_v1';
  static const _userProfileKey = 'service_epic_user_profile_v1';
  static const _authTokenKey = 'service_epic_auth_token_v1';
  static const _transactionsKey = 'service_epic_transactions_v1';
  static const _notificationsKey = 'service_epic_notifications_v1';

  bool get isSeeded => _prefs.getBool(_seededKey) ?? false;
  Future<void> markSeeded() => _prefs.setBool(_seededKey, true);

  bool get simulateApiError => _prefs.getBool(_simulateErrorKey) ?? false;
  Future<void> setSimulateApiError(bool value) =>
      _prefs.setBool(_simulateErrorKey, value);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? false;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  String? get authToken => _prefs.getString(_authTokenKey);
  Future<void> saveAuthToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_authTokenKey);
    } else {
      await _prefs.setString(_authTokenKey, token);
    }
  }

  UserProfile? loadUserProfile() {
    final raw = _prefs.getString(_userProfileKey);
    if (raw == null || raw.isEmpty) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveUserProfile(UserProfile? profile) async {
    if (profile == null) {
      await _prefs.remove(_userProfileKey);
    } else {
      await _prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
    }
  }

  List<ServiceRequest> loadRequests() {
    final raw = _prefs.getString(_requestsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRequests(List<ServiceRequest> requests) async {
    final encoded = jsonEncode(requests.map((r) => r.toJson()).toList());
    await _prefs.setString(_requestsKey, encoded);
  }

  List<ProviderResponse> loadResponses() {
    final raw = _prefs.getString(_responsesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ProviderResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveResponses(List<ProviderResponse> responses) async {
    final encoded = jsonEncode(responses.map((r) => r.toJson()).toList());
    await _prefs.setString(_responsesKey, encoded);
  }

  List<PaymentTransaction> loadTransactions() {
    final raw = _prefs.getString(_transactionsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTransactions(List<PaymentTransaction> txns) async {
    final encoded = jsonEncode(txns.map((t) => t.toJson()).toList());
    await _prefs.setString(_transactionsKey, encoded);
  }

  List<AppNotification> loadNotifications() {
    final raw = _prefs.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNotifications(List<AppNotification> items) async {
    final encoded = jsonEncode(items.map((n) => n.toJson()).toList());
    await _prefs.setString(_notificationsKey, encoded);
  }

  Set<String> loadFavoriteIds() {
    return (_prefs.getStringList(_favoritesKey) ?? const []).toSet();
  }

  Future<void> saveFavoriteIds(Set<String> ids) async {
    await _prefs.setStringList(_favoritesKey, ids.toList());
  }

  List<String> loadRecentSearches() {
    return _prefs.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    await _prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<void> clearAllData() async {
    await _prefs.remove(_requestsKey);
    await _prefs.remove(_responsesKey);
    await _prefs.remove(_favoritesKey);
    await _prefs.remove(_recentSearchesKey);
    await _prefs.remove(_transactionsKey);
    await _prefs.remove(_notificationsKey);
    await _prefs.remove(_seededKey);
  }
}
