import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    try {
      // 1. Request permissions (especially for iOS, though we focus on Android now)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permissions');
        
        // 2. Get FCM token and save to Firestore
        // Note: On iOS simulators without APNs, getToken() might timeout. We wrap it in a timeout.
        String? token = await _fcm.getToken().timeout(
          const Duration(seconds: 3), 
          onTimeout: () {
            debugPrint("FCM getToken() timed out (expected on iOS simulator without APNs)");
            return null;
          }
        );
        
        if (token != null) {
          await saveTokenToDatabase(token);
        }

        // Listen to token refreshes
        _fcm.onTokenRefresh.listen(saveTokenToDatabase);

        // 3. Initialize local notifications for foreground messages
        const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        );

        // 4. Listen to foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 5. Handle background/terminated message taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
        
        // Handle app opened from terminated state via notification
        RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleBackgroundMessageTap(initialMessage);
        }
      }
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  Future<void> saveTokenToDatabase(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Save token to both users and providers collection just in case,
    // or we can check which collection the user belongs to.
    // We'll update the user document if it exists, else provider document.
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
      } else {
        final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
        if (providerDoc.exists) {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).update({
            'fcmToken': token,
          });
        }
      }
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint("Received foreground message: ${message.notification?.title}");
    
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      _navigateBasedOnData(data);
    }
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    _navigateBasedOnData(message.data);
  }

  void _navigateBasedOnData(Map<String, dynamic> data) {
    if (navigatorKey == null || navigatorKey!.currentState == null) return;
    
    final type = data['type'];
    
    if (type == 'chat') {
      // Could navigate directly to the chat if we have chatId
      // navigatorKey!.currentState!.pushNamed('/chat');
    } else if (type == 'booking') {
      // Navigate to bookings page
      // navigatorKey!.currentState!.pushNamed('/bookings');
    }
  }
}
