import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aethel/core/network/api_client.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _cachedToken;

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Request notification permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      // Permission denied - handle gracefully
      return;
    }

    // Get initial FCM token
    await _registerToken();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _cachedToken = token;
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      // Token registration failed - will retry on refresh
    }
  }

  static Future<void> _onTokenRefresh(String newToken) async {
    _cachedToken = newToken;
    await _sendTokenToBackend(newToken);
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.dio.post('/devices/register', data: {
        'pushToken': token,
        'platform': 'android',
      });
    } catch (e) {
      // Backend registration failed - token is cached and will be retried on refresh
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    // Foreground message received - handle notification display if needed
    // The message data is available in message.data
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    try {
      final token = await _messaging.getToken();
      _cachedToken = token;
      return token;
    } catch (e) {
      return null;
    }
  }
}
