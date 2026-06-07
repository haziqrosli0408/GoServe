import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'onesignal_stub.dart' if (dart.library.js_interop) 'onesignal_web.dart';

/// OneSignal Web Push Notification Service for GoServe.
///
/// This service handles:
/// 1. Logging in users with their Firebase UID as the OneSignal External ID
/// 2. Sending targeted push notifications via the OneSignal REST API
/// 3. Storing the OneSignal subscription ID in Firestore for targeting
class OneSignalService {
  static const String _appId = '84f79509-0ca9-43e1-b5eb-9f363a5c3b85';
  static const String _restApiKey = 'os_v2_app_qt3zkcimvfb6dnplt43duxb3quqamadfaxbebcnbe2ujqvpwplvd3wdnprpaei7gi26guka6wckr6browlqrn4zbj6ugfp35yiq457y';

  // ─── Initialization & Login ───────────────────────────────────────────

  /// Call after Firebase Auth login to link the OneSignal user.
  /// Sets the Firebase UID as the OneSignal External ID so we can target users.
  static Future<void> loginUser(String firebaseUid) async {
    if (!kIsWeb) return;

    try {
      jsOneSignalLogin(firebaseUid);
      promptPermission(); // Trigger native permission prompt
      debugPrint('✅ OneSignal: logged in user $firebaseUid');

      // Wait a moment for OneSignal to register, then save subscription ID
      await Future.delayed(const Duration(seconds: 2));
      await _saveSubscriptionId(firebaseUid);
    } catch (e) {
      debugPrint('❌ OneSignal login error: $e');
    }
  }

  /// Call on logout to disassociate the OneSignal user.
  static void logoutUser() {
    if (!kIsWeb) return;
    try {
      jsOneSignalLogout();
      debugPrint('✅ OneSignal: logged out user');
    } catch (e) {
      debugPrint('❌ OneSignal logout error: $e');
    }
  }

  /// Manually prompt for push notification permissions
  static void promptPermission() {
    if (!kIsWeb) return;
    try {
      jsOneSignalPromptPush();
      debugPrint('✅ OneSignal: Prompted for push permission');
    } catch (e) {
      debugPrint('❌ OneSignal prompt error: $e');
    }
  }

  // ─── Save Subscription ID to Firestore ────────────────────────────────

  /// Fetches the OneSignal Subscription ID (formerly Player ID) and saves it
  /// to the user's Firestore document for targeted notifications.
  static Future<void> _saveSubscriptionId(String uid) async {
    try {
      String? subscriptionId;
      // Retry up to 5 times (10 seconds total) to allow user to accept prompt
      for (int i = 0; i < 5; i++) {
        subscriptionId = jsGetSubscriptionId();
        if (subscriptionId != null && subscriptionId.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
      
      if (subscriptionId == null || subscriptionId.isEmpty) {
        debugPrint('⚠️ OneSignal: No subscription ID yet (user may not have allowed notifications)');
        return;
      }

      debugPrint('🔑 OneSignal Subscription ID: $subscriptionId');

      // Check if user is in 'users' or 'providers' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'oneSignalId': subscriptionId,
        });
      } else {
        final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(uid).get();
        if (providerDoc.exists) {
          await FirebaseFirestore.instance.collection('providers').doc(uid).update({
            'oneSignalId': subscriptionId,
          });
        }
      }
      debugPrint('✅ OneSignal: Saved subscription ID to Firestore');
    } catch (e) {
      debugPrint('❌ OneSignal: Error saving subscription ID: $e');
    }
  }

  // ─── Send Notifications ───────────────────────────────────────────────

  /// Send a push notification to a specific user by their Firebase UID.
  ///
  /// This uses the OneSignal REST API with `include_aliases` to target
  /// the user by their External ID (which we set to their Firebase UID).
  static Future<void> sendNotificationToUser({
    required String recipientUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_restApiKey.isEmpty) {
      debugPrint('⚠️ OneSignal: REST API key not set. Skipping notification.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'target_channel': 'push',
          'include_aliases': {
            'external_id': [recipientUid],
          },
          'headings': {'en': title},
          'contents': {'en': body},
          if (data != null) 'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ OneSignal: Notification sent to $recipientUid');
      } else {
        debugPrint('❌ OneSignal: Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ OneSignal: Error sending notification: $e');
    }
  }

  // ─── Convenience Methods for GoServe Events ───────────────────────────

  /// Notify Provider: New booking request from customer
  static Future<void> notifyNewBooking({
    required String providerId,
    required String customerName,
    required String serviceName,
    required String date,
    required String time,
    String? bookingId,
  }) async {
    await sendNotificationToUser(
      recipientUid: providerId,
      title: '🔔 New Booking!',
      body: '$customerName booked $serviceName for $date at $time',
      data: {'type': 'booking', 'bookingId': bookingId ?? ''},
    );
  }

  /// Notify Customer: Provider accepted/confirmed booking
  static Future<void> notifyBookingConfirmed({
    required String customerId,
    required String providerName,
    required String serviceName,
    String? bookingId,
  }) async {
    await sendNotificationToUser(
      recipientUid: customerId,
      title: '✅ Booking Confirmed',
      body: 'Your booking for $serviceName has been confirmed by $providerName',
      data: {'type': 'booking', 'bookingId': bookingId ?? ''},
    );
  }

  /// Notify Customer: Provider is on the way
  static Future<void> notifyProviderOnTheWay({
    required String customerId,
    required String providerName,
    String? bookingId,
  }) async {
    await sendNotificationToUser(
      recipientUid: customerId,
      title: '🚗 Provider On the Way',
      body: '$providerName is heading to your location now!',
      data: {'type': 'booking', 'bookingId': bookingId ?? ''},
    );
  }

  /// Notify Customer: Service completed
  static Future<void> notifyServiceCompleted({
    required String customerId,
    required String serviceName,
    String? bookingId,
  }) async {
    await sendNotificationToUser(
      recipientUid: customerId,
      title: '⭐ Service Completed',
      body: 'Your $serviceName has been completed. Please rate your experience!',
      data: {'type': 'booking', 'bookingId': bookingId ?? ''},
    );
  }

  /// Notify Provider: Customer cancelled booking
  static Future<void> notifyBookingCancelled({
    required String providerId,
    required String customerName,
    required String serviceName,
    String? bookingId,
  }) async {
    await sendNotificationToUser(
      recipientUid: providerId,
      title: '❌ Booking Cancelled',
      body: '$customerName cancelled the booking for $serviceName',
      data: {'type': 'booking', 'bookingId': bookingId ?? ''},
    );
  }

  /// Notify recipient: New chat message
  static Future<void> notifyNewMessage({
    required String recipientUid,
    required String senderName,
    required String messagePreview,
  }) async {
    await sendNotificationToUser(
      recipientUid: recipientUid,
      title: '💬 New Message',
      body: '$senderName: $messagePreview',
      data: {'type': 'chat'},
    );
  }

  /// Notify Provider: Payment received
  static Future<void> notifyPaymentReceived({
    required String providerId,
    required String serviceName,
    required double amount,
  }) async {
    await sendNotificationToUser(
      recipientUid: providerId,
      title: '💰 Payment Received',
      body: 'You received RM${amount.toStringAsFixed(2)} for $serviceName',
      data: {'type': 'payment'},
    );
  }
}


