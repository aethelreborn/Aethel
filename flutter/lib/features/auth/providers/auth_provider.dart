import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/domain/models/models.dart';

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({this.user, this.isLoading = false, this.error, this.isAuthenticated = false});

  AuthState copyWith({User? user, bool? isLoading, String? error, bool? isAuthenticated}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = resp.data as Map<String, dynamic>;
      await ApiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      state = state.copyWith(
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signup(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.dio.post(
        '/auth/signup',
        data: {'email': email, 'password': password},
      );
      final data = resp.data as Map<String, dynamic>;
      await ApiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      state = state.copyWith(
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> logout() async {
    await ApiClient.clearTokens();
    state = const AuthState();
  }
}
