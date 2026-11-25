import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_env.dart';
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

  bool get isEmailVerified {
    if (!AppEnv.firebaseInitialized) return true;
    try {
      return FirebaseAuth.instance.currentUser?.emailVerified ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<Result<UserProfile>> signInWithGoogle() async {
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach Google Sign-In service.'),
      );
    }

    try {
      await GoogleSignIn.instance.initialize();
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final idToken = googleAccount.authentication.idToken;

      String uid = googleAccount.id;
      String? token = idToken;

      if (AppEnv.firebaseInitialized && idToken != null) {
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        uid = userCred.user?.uid ?? uid;
        token = await userCred.user?.getIdToken() ?? token;
      }

      final demo = SeedData.demoUser();
      final profile = UserProfile(
        id: uid,
        fullName: googleAccount.displayName?.trim().isNotEmpty == true
            ? googleAccount.displayName!.trim()
            : googleAccount.email.split('@').first,
        email: googleAccount.email.toLowerCase(),
        phone: demo.phone,
        city: demo.city,
        walletBalance: demo.walletBalance,
        savedAddresses: demo.savedAddresses,
        savedCards: demo.savedCards,
        joinedAt: DateTime.now(),
      );
      await _storage.saveUserProfile(profile);
      await _storage.saveAuthToken(token ?? 'tok_google_${_uuid.v4()}');
      return Success(profile);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Failure(
          ValidationException('Google Sign-In was cancelled.'),
        );
      }
      return Failure(
        NetworkException(
          'Google Sign-In unavailable (${e.code.name}). Ensure SHA-1 & Google Sign-In are enabled in Firebase Console, or use Email / Demo Login.',
          e,
        ),
      );
    } on FirebaseAuthException catch (e) {
      return Failure(
        ValidationException(e.message ?? 'Google authentication failed.'),
      );
    } catch (e) {
      return Failure(
        NetworkException('Google Sign-In failed: $e', e),
      );
    }
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach security server.'),
      );
    }

    if (AppEnv.firebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          final cred = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPassword,
          );
          await user.reauthenticateWithCredential(cred);
          await user.updatePassword(newPassword);
          return const Success(null);
        }
      } on FirebaseAuthException catch (e) {
        return Failure(
          ValidationException(e.message ?? 'Could not update password.'),
        );
      } catch (_) {}
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const Success(null);
  }

  Future<Result<void>> sendEmailVerification() async {
    if (AppEnv.firebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
        }
      } on FirebaseAuthException catch (e) {
        return Failure(
          ValidationException(e.message ?? 'Could not send verification email.'),
        );
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach authentication server.'),
      );
    }

    String? firebaseUid;
    String? firebaseToken;
    String? firebaseDisplayName;

    if (AppEnv.firebaseInitialized) {
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        firebaseUid = cred.user?.uid;
        firebaseDisplayName = cred.user?.displayName;
        firebaseToken = await cred.user?.getIdToken();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          return const Failure(
            NetworkException('Network error connecting to Firebase Auth.'),
          );
        }
        return Failure(
          ValidationException(e.message ?? 'Authentication failed.'),
        );
      } catch (_) {
        // Fallback to local session if Firebase plugin isn't bound (e.g., tests)
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    final existing = _storage.loadUserProfile();
    if (existing != null &&
        existing.email.toLowerCase() == email.trim().toLowerCase()) {
      await _storage.saveAuthToken(firebaseToken ?? 'tok_${_uuid.v4()}');
      return Success(existing);
    }

    final demo = SeedData.demoUser();
    final namePart = email.split('@').first.replaceAll('.', ' ').trim();
    final formattedName = firebaseDisplayName?.isNotEmpty == true
        ? firebaseDisplayName!
        : (namePart.isEmpty
            ? 'Client User'
            : namePart
                .split(' ')
                .where((w) => w.isNotEmpty)
                .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
                .join(' '));

    final profile = UserProfile(
      id: firebaseUid ?? 'USR-${_uuid.v4().substring(0, 6).toUpperCase()}',
      fullName: email.trim().toLowerCase() == demo.email
          ? demo.fullName
          : formattedName,
      email: email.trim().toLowerCase(),
      phone: demo.phone,
      city: demo.city,
      walletBalance: demo.walletBalance,
      savedAddresses: demo.savedAddresses,
      savedCards: demo.savedCards,
      joinedAt: DateTime.now(),
    );
    await _storage.saveUserProfile(profile);
    await _storage.saveAuthToken(firebaseToken ?? 'tok_${_uuid.v4()}');
    return Success(profile);
  }

  Future<Result<UserProfile>> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String city,
    required String password,
  }) async {
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Unable to reach registration server.'),
      );
    }

    String? firebaseUid;
    String? firebaseToken;

    if (AppEnv.firebaseInitialized) {
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.updateDisplayName(fullName.trim());
        firebaseUid = cred.user?.uid;
        firebaseToken = await cred.user?.getIdToken();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          return const Failure(
            NetworkException('Network error connecting to Firebase Auth.'),
          );
        }
        return Failure(
          ValidationException(e.message ?? 'Registration failed.'),
        );
      } catch (_) {}
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final profile = UserProfile(
      id: firebaseUid ?? 'USR-${_uuid.v4().substring(0, 6).toUpperCase()}',
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
    await _storage.saveAuthToken(firebaseToken ?? 'tok_${_uuid.v4()}');
    return Success(profile);
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    if (AppEnv.firebaseInitialized) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      } on FirebaseAuthException catch (e) {
        return Failure(
          ValidationException(e.message ?? 'Could not send reset email.'),
        );
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<UserProfile>> signInDemo() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final profile = _storage.loadUserProfile() ?? SeedData.demoUser();
    await _storage.saveUserProfile(profile);
    await _storage.saveAuthToken('tok_demo_${_uuid.v4()}');
    return Success(profile);
  }

  Future<void> signOut() async {
    if (AppEnv.firebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
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
