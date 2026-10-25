import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isOffline => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._() {
    final options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    );
    _dio = Dio(options);
    _refreshDio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuthCall = request.path.startsWith('/auth/login') ||
              request.path.startsWith('/auth/signup') ||
              request.path.startsWith('/auth/refresh');
          if (error.response?.statusCode != 401 ||
              isAuthCall ||
              request.extra['aethel_retried'] == true) {
            handler.next(error);
            return;
          }

          final refreshToken = _refreshToken;
          if (refreshToken == null || refreshToken.isEmpty) {
            await clearTokens();
            onSessionExpired?.call();
            handler.next(error);
            return;
          }

          try {
            final response = await _refreshDio.post<dynamic>(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );
            final data = response.data as Map<String, dynamic>;
            await setTokens(
              accessToken: data['access_token'] as String,
              refreshToken: data['refresh_token'] as String,
            );
            request.headers['Authorization'] = 'Bearer ${_accessToken!}';
            request.extra['aethel_retried'] = true;
            final retry = await _dio.fetch<dynamic>(request);
            handler.resolve(retry);
          } catch (_) {
            await clearTokens();
            onSessionExpired?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  late final Dio _refreshDio;
  SecureStore? _store;
  String? _accessToken;
  String? _refreshToken;

  /// Called when a refresh token is rejected. The session stays locally
  /// unlocked; this only means remote sync needs a fresh sign-in.
  void Function()? onSessionExpired;

  String? get accessToken => _accessToken;
  bool get hasSession => _accessToken != null || _refreshToken != null;

  Future<void> init(SecureStore store) async {
    _store = store;
    if (_accessToken == null) {
      _accessToken = await store.read(SecureKeys.access);
      _refreshToken = await store.read(SecureKeys.refresh);
    }
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _store?.write(SecureKeys.access, accessToken);
    await _store?.write(SecureKeys.refresh, refreshToken);
  }

  Future<void> setTokensFromResponse(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw const ApiException('The server returned an incomplete session.');
    }
    await setTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _store?.clearTokens();
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<dynamic>(path);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<Map<String, dynamic>> put(String path, {Object? data}) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'data': data};
  }

  static ApiException _translate(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? message;
    if (data is Map) {
      final value = data['error'] ?? data['message'];
      if (value is String && value.trim().isNotEmpty) message = value;
    }
    // A build compiled without a vault server address can only reach
    // localhost, which fails as a connection error or a timeout depending on
    // the platform. Say so instead of blaming the network.
    final unreachable = error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
    if (message == null && unreachable && !AppConfig.hasConfiguredServer) {
      message = 'This copy of Aethel was built without a vault server address, '
          'so it cannot sign in. Install a current build, or rebuild with '
          '--dart-define=AETHEL_API_URL=https://your-server.';
    }
    if (message == null) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'The vault server took too long to answer.';
          break;
        case DioExceptionType.connectionError:
          message = 'The vault server cannot be reached.';
          break;
        case DioExceptionType.badResponse:
          message = status == 401
              ? 'That email or master password does not match.'
              : 'The server could not complete that request.';
          break;
        default:
          message = 'Something interrupted the connection. Try again.';
      }
    }
    return ApiException(message, statusCode: status);
  }
}
