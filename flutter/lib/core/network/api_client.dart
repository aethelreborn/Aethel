import 'package:dio/dio.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'AETHEL_API_URL',
  defaultValue: 'http://localhost:3000',
);

class ApiClient {
  static late final Dio _dio;
  static String? _accessToken;
  static String? _refreshToken;
  static bool _isRefreshing = false;

  static Dio get dio => _dio;

  static void init({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException err, handler) async {
        if (err.response?.statusCode == 401 && _refreshToken != null && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final resp = await _dio.post('/auth/refresh', data: {'refresh_token': _refreshToken});
            if (resp.statusCode == 200 && resp.data is Map) {
              _accessToken = resp.data['access_token'] as String;
              _refreshToken = resp.data['refresh_token'] as String? ?? _refreshToken!;
              err.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
              final newResp = await _dio.fetch(err.requestOptions);
              return handler.resolve(newResp);
            }
          } finally {
            _isRefreshing = false;
          }
          await clearTokens();
        }
        return handler.next(err);
      },
    ));
  }

  static Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
  }

  static String? get accessToken => _accessToken;
  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _isRefreshing = false;
  }
}
