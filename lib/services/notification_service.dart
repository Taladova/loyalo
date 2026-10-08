import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> loyaloFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint('Notification reçue en arrière-plan: ${message.messageId}');
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messagingInstance = messaging,
       _db = firestore ?? FirebaseFirestore.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _deviceIdKey = 'loyalo_device_id';
  static const _androidChannel = AndroidNotificationChannel(
    'loyalo',
    'Loyalo',
    description: 'Notifications utiles de Loyalo',
    importance: Importance.high,
  );

  final FirebaseMessaging? _messagingInstance;
  final FirebaseFirestore _db;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> initializeAppHandlers() async {
    FirebaseMessaging.onBackgroundMessage(
      loyaloFirebaseMessagingBackgroundHandler,
    );
    await _initLocalNotifications();
  }

  Future<void> startForUser({
    required String userId,
    required void Function(RemoteMessage message) onMessageOpened,
    void Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    await requestPermission();
    final messaging = _messaging;
    final token = await messaging.getToken();
    if (token != null) {
      await _saveDeviceToken(userId: userId, token: token);
    }
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
      _saveDeviceToken(userId: userId, token: token);
    });

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
      _showForegroundNotification(message);
    });

    await _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      onMessageOpened,
    );

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        () => onMessageOpened(initialMessage),
      );
    }
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
  }

  FirebaseMessaging get _messaging =>
      _messagingInstance ?? FirebaseMessaging.instance;

  Future<void> detachCurrentDevice(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final deviceId = await _deviceId();
    await _db
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .set({
          'active': false,
          'signedOutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await stop();
  }

  Future<void> saveDeviceToken({
    required String userId,
    required String token,
    String? deviceId,
  }) async {
    await _saveDeviceToken(userId: userId, token: token, deviceId: deviceId);
  }

  Future<void> stop() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
  }

  Future<void> _saveDeviceToken({
    required String userId,
    required String token,
    String? deviceId,
  }) async {
    final resolvedDeviceId = deviceId ?? await _deviceId();
    await _db
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(resolvedDeviceId)
        .set({
          'token': token,
          'platform': _platform,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotifications.initialize(settings);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if (title == null && body == null) return;
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}
