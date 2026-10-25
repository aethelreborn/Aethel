import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/secure_store.dart';
import '../../../data/models.dart';
import '../../settings/controllers/settings_controller.dart';

enum SessionStatus { booting, signedOut, locked, unlocked }

class SessionState {
  const SessionState({
    required this.status,
    this.profile,
    this.busy = false,
    this.error,
    this.biometricAvailable = false,
  });

  final SessionStatus status;
  final UserProfile? profile;
  final bool busy;
  final String? error;
  final bool biometricAvailable;

  SessionState copyWith({
    SessionStatus? status,
    Object? profile = _unset,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? biometricAvailable,
  }) {
    return SessionState(
      status: status ?? this.status,
      profile:
          identical(profile, _unset) ? this.profile : profile as UserProfile?,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }
}

const Object _unset = Object();

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required SecureStore secure,
    required SettingsController settings,
  })  : _secure = secure,
        _settings = settings,
        super(const SessionState(status: SessionStatus.booting));

  final SecureStore _secure;
  final SettingsController _settings;
  final ApiClient _api = ApiClient.instance;
  final LocalStore _local = LocalStore.instance;

  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      await _api.init(_secure);
      _api.onSessionExpired = SyncService.instance.onAuthLost;
      final biometricAvailable = await BiometricService.isAvailable();
      final email = await _secure.readEmail();
      final keyCheck = await _secure.readKeyCheck();

      if (email != null && keyCheck != null) {
        final name = await _secure.readName() ?? '';
        state = state.copyWith(
          status: SessionStatus.locked,
          profile: UserProfile(id: '', email: email, name: name),
          biometricAvailable: biometricAvailable,
        );
      } else {
        state = state.copyWith(
          status: SessionStatus.signedOut,
          biometricAvailable: biometricAvailable,
        );
      }
    } catch (_) {
      state = state.copyWith(
        status: SessionStatus.signedOut,
        error: 'Aethel could not open the device key store.',
      );
    }
  }

  Future<bool> signUp({
    required String email,
    required String masterPassword,
    String name = '',
  }) async {
    final normalized = email.trim().toLowerCase();
    state = state.copyWith(busy: true, clearError: true);
    try {
      final keys = await CryptoService.deriveKeys(
        email: normalized,
        masterPassword: masterPassword,
      );
      final data = await _api.post('/auth/signup', data: {
        'email': normalized,
        'password': keys.verifier,
      });
      await _completeAuthentication(
        data: data,
        email: normalized,
        name: name.trim(),
        keys: keys,
        resetLocal: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Aethel could not create the vault. Try again.',
      );
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String masterPassword,
  }) async {
    final normalized = email.trim().toLowerCase();
    state = state.copyWith(busy: true, clearError: true);
    try {
      final keys = await CryptoService.deriveKeys(
        email: normalized,
        masterPassword: masterPassword,
      );
      final data = await _api.post('/auth/login', data: {
        'email': normalized,
        'password': keys.verifier,
      });
      final previousEmail = await _secure.readEmail();
      await _completeAuthentication(
        data: data,
        email: normalized,
        name: await _secure.readName() ?? '',
        keys: keys,
        resetLocal: previousEmail != null && previousEmail != normalized,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Aethel could not open the vault. Try again.',
      );
      return false;
    }
  }

  Future<void> _completeAuthentication({
    required Map<String, dynamic> data,
    required String email,
    required String name,
    required DerivedKeys keys,
    required bool resetLocal,
  }) async {
    if (resetLocal) {
      await _local.wipe();
    }
    await _api.setTokensFromResponse(data);
    await _secure.saveSession(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
      email: email,
      name: name,
    );
    await _secure.saveVaultKey(keys.vaultKey);
    await _secure.saveKeyCheck(
      CryptoService.encryptString(
              CryptoService.keyCheckPlaintext, keys.vaultKey)
          .ciphertext,
    );

    var opened = await _local.open(keys.vaultKey);
    if (!opened) {
      await _local.wipe();
      opened = await _local.open(keys.vaultKey);
    }
    if (!opened) {
      throw const ApiException('The local vault could not be opened.');
    }

    final profile = _profileFrom(data, email: email, name: name);
    state = state.copyWith(
      status: SessionStatus.unlocked,
      profile: profile,
      busy: false,
      clearError: true,
    );
    SyncService.instance.start(data['access_token'] as String);
  }

  Future<bool> unlock(String masterPassword) async {
    final profile = state.profile;
    final email = profile?.email ?? await _secure.readEmail();
    if (email == null) {
      state = state.copyWith(
        status: SessionStatus.signedOut,
        error: 'No account is stored on this device.',
      );
      return false;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final keys = await CryptoService.deriveKeys(
        email: email,
        masterPassword: masterPassword,
      );
      if (!await _verifyKeyCheck(keys.vaultKey)) {
        state = state.copyWith(
          busy: false,
          error: 'That master password does not open this vault.',
        );
        return false;
      }
      if (!await _local.open(keys.vaultKey)) {
        state = state.copyWith(
          busy: false,
          error: 'The local vault could not be opened on this device.',
        );
        return false;
      }
      await _secure.saveVaultKey(keys.vaultKey);
      state = state.copyWith(
        status: SessionStatus.unlocked,
        profile: profile ??
            UserProfile(
              id: '',
              email: email,
              name: await _secure.readName() ?? '',
            ),
        busy: false,
        clearError: true,
      );

      final token = _api.accessToken;
      if (token != null && token.isNotEmpty) {
        SyncService.instance.start(token);
      } else {
        unawaited(_renewSession(email: email, verifier: keys.verifier));
      }
      return true;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Aethel could not unlock the vault. Try again.',
      );
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_settings.state.biometricUnlock || !state.biometricAvailable) {
      return false;
    }
    final profile = state.profile;
    if (profile == null) return false;

    state = state.copyWith(busy: true, clearError: true);
    final approved = await BiometricService.authenticate(
      'Unlock your Aethel vault',
    );
    if (!approved) {
      state = state.copyWith(busy: false, clearError: true);
      return false;
    }

    final key = await _secure.readVaultKey();
    if (key == null || !await _verifyKeyCheck(key) || !await _local.open(key)) {
      state = state.copyWith(
        busy: false,
        error: 'Biometric unlock is not available. Use your master password.',
      );
      return false;
    }

    state = state.copyWith(
      status: SessionStatus.unlocked,
      busy: false,
      clearError: true,
    );
    final token = _api.accessToken;
    if (token != null && token.isNotEmpty) {
      SyncService.instance.start(token);
    }
    return true;
  }

  void lock() {
    if (state.status != SessionStatus.unlocked) return;
    _local.close();
    SyncService.instance.stop();
    state = state.copyWith(
      status: SessionStatus.locked,
      busy: false,
      clearError: true,
    );
  }

  Future<void> logout() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Local sign-out must work even when the server is unreachable.
    }
    SyncService.instance.stop();
    await _local.wipe();
    await _api.clearTokens();
    await _secure.clearSession();
    state = state.copyWith(
      status: SessionStatus.signedOut,
      profile: null,
      busy: false,
      clearError: true,
    );
  }

  Future<bool> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = state.profile?.email;
    final oldKey = _local.exportKeyForSync();
    final oldCheck = await _secure.readKeyCheck();
    if (email == null || oldKey == null || oldCheck == null) {
      state = state.copyWith(error: 'Unlock the vault before changing it.');
      return false;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final currentKeys = await CryptoService.deriveKeys(
        email: email,
        masterPassword: currentPassword,
      );
      if (!await _verifyKeyCheck(currentKeys.vaultKey)) {
        state = state.copyWith(
          busy: false,
          error: 'The current master password is not correct.',
        );
        return false;
      }
      final newKeys = await CryptoService.deriveKeys(
        email: email,
        masterPassword: newPassword,
      );
      final newCheck = CryptoService.encryptString(
              CryptoService.keyCheckPlaintext, newKeys.vaultKey)
          .ciphertext;

      try {
        await _local.rekey(newKeys.vaultKey);
        await _secure.saveKeyCheck(newCheck);
        await _secure.saveVaultKey(newKeys.vaultKey);
        final data = await _api.post('/auth/change-password', data: {
          'password': newKeys.verifier,
        });
        await _api.setTokensFromResponse(data);
        final access = data['access_token'] as String;
        final refresh = data['refresh_token'] as String;
        await _secure.saveSession(
          access: access,
          refresh: refresh,
          email: email,
          name: state.profile?.name ?? '',
        );
        SyncService.instance.start(access);
      } catch (_) {
        await _local.rekey(oldKey);
        await _secure.saveKeyCheck(oldCheck);
        await _secure.saveVaultKey(oldKey);
        rethrow;
      }

      state = state.copyWith(busy: false, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'The master password could not be changed.',
      );
      return false;
    }
  }

  Future<bool> deleteAccount({required String masterPassword}) async {
    final email = state.profile?.email;
    if (email == null) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final keys = await CryptoService.deriveKeys(
        email: email,
        masterPassword: masterPassword,
      );
      if (!await _verifyKeyCheck(keys.vaultKey)) {
        state = state.copyWith(
          busy: false,
          error: 'The master password is not correct.',
        );
        return false;
      }
      await _api.delete('/auth/account');
      SyncService.instance.stop();
      await _local.wipe();
      await _api.clearTokens();
      await _secure.clearSession();
      state = state.copyWith(
        status: SessionStatus.signedOut,
        profile: null,
        busy: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'The account could not be deleted.',
      );
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  Future<void> _renewSession({
    required String email,
    required String verifier,
  }) async {
    try {
      final data = await _api.post('/auth/login', data: {
        'email': email,
        'password': verifier,
      });
      await _api.setTokensFromResponse(data);
      await _secure.saveSession(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
        email: email,
        name: state.profile?.name ?? '',
      );
      SyncService.instance.start(data['access_token'] as String);
    } catch (_) {
      // Offline unlock is intentional. The next online unlock renews tokens.
    }
  }

  Future<bool> _verifyKeyCheck(Uint8List key) async {
    final stored = await _secure.readKeyCheck();
    if (stored == null) return false;
    try {
      final value = CryptoService.decryptString(stored, key);
      return CryptoService.constantTimeEquals(
        value,
        CryptoService.keyCheckPlaintext,
      );
    } catch (_) {
      return false;
    }
  }

  static UserProfile _profileFrom(
    Map<String, dynamic> data, {
    required String email,
    required String name,
  }) {
    final rawUser = data['user'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    return UserProfile(
      id: user?['id']?.toString() ?? '',
      email: user?['email']?.toString() ?? email,
      name: name,
    );
  }
}
