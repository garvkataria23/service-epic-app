import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/user_profile.dart';
import '../services/local_storage_service.dart';
import '../services/seed_data.dart';

class AuthRepository {
  AuthRepository({required LocalStorageService storage}) : _storage = storage;

  final LocalStorageService _storage;
  final _uuid = const Uuid();

  bool get isLoggedIn =>
      _storage.authToken != null && _storage.loadUserProfile() != null;

  UserProfile? getCurrentUser() => _storage.loadUserProfile();

  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach authentication server.'),
      );
    }

    final existing = _storage.loadUserProfile();
    if (existing != null &&
        existing.email.toLowerCase() == email.trim().toLowerCase()) {
      await _storage.saveAuthToken('tok_${_uuid.v4()}');
      return Success(existing);
    }

    // Create a session profile for any valid email/password login
    final demo = SeedData.demoUser();
    final namePart = email.split('@').first.replaceAll('.', ' ').trim();
    final formattedName = namePart.isEmpty
        ? 'Client User'
        : namePart
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

    final profile = demo.copyWith(
      fullName: email.trim().toLowerCase() == demo.email
          ? demo.fullName
          : formattedName,
      email: email.trim().toLowerCase(),
    );
    await _storage.saveUserProfile(profile);
    await _storage.saveAuthToken('tok_${_uuid.v4()}');
    return Success(profile);
  }

  Future<Result<UserProfile>> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String city,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach registration server.'),
      );
    }

    final profile = UserProfile(
      id: 'USR-${_uuid.v4().substring(0, 6).toUpperCase()}',
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      city: city.trim(),
      walletBalance: 1000.00,
      savedAddresses: [
        SavedAddress(
          id: 'ADDR-1',
          label: 'Primary',
          fullAddress: city.trim(),
          isDefault: true,
        ),
      ],
      savedCards: const [],
      joinedAt: DateTime.now(),
    );
    await _storage.saveUserProfile(profile);
    await _storage.saveAuthToken('tok_${_uuid.v4()}');
    return Success(profile);
  }

  Future<Result<UserProfile>> signInDemo() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final profile = _storage.loadUserProfile() ?? SeedData.demoUser();
    await _storage.saveUserProfile(profile);
    await _storage.saveAuthToken('tok_demo_${_uuid.v4()}');
    return Success(profile);
  }

  Future<void> signOut() async {
    await _storage.saveAuthToken(null);
  }

  Future<Result<UserProfile>> updateProfile(UserProfile updated) async {
    await _storage.saveUserProfile(updated);
    return Success(updated);
  }

  Future<Result<UserProfile>> topUpWallet(double amount) async {
    final current = _storage.loadUserProfile();
    if (current == null) {
      return const Failure(NotFoundException('No active user session.'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final updated = current.copyWith(
      walletBalance: current.walletBalance + amount,
    );
    await _storage.saveUserProfile(updated);
    return Success(updated);
  }
}
