import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/user_profile.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository repository})
      : _repository = repository {
    _currentUser = _repository.getCurrentUser();
    _isAuthenticated = _repository.isLoggedIn;
  }

  final AuthRepository _repository;

  UserProfile? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void refreshUserFromStorage() {
    _currentUser = _repository.getCurrentUser();
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.signIn(email: email, password: password);
    _isLoading = false;

    final ok = res.when(
      success: (user) {
        _currentUser = user;
        _isAuthenticated = true;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String city,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.signUp(
      fullName: fullName,
      email: email,
      phone: phone,
      city: city,
      password: password,
    );
    _isLoading = false;

    final ok = res.when(
      success: (user) {
        _currentUser = user;
        _isAuthenticated = true;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> signInDemo() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.signInDemo();
    _isLoading = false;

    final ok = res.when(
      success: (user) {
        _currentUser = user;
        _isAuthenticated = true;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<void> topUpWallet(double amount) async {
    final res = await _repository.topUpWallet(amount);
    res.when(
      success: (user) => _currentUser = user,
      failure: (err) => _errorMessage = err.message,
    );
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile updated) async {
    final res = await _repository.updateProfile(updated);
    res.when(
      success: (user) => _currentUser = user,
      failure: (err) => _errorMessage = err.message,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _isAuthenticated = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
