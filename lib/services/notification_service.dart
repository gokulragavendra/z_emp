// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // List of topics to subscribe to
  final List<String> _topics = [
    "announcements",
    "attendanceRecords",
    "chats",
    "enquiries",
    "leaveRequests",
    "products",
    "salaryAdvances",
    "tasks",
  ];

  Future<void> initNotifications() async {
    // Request notification permissions (iOS & Android)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // You can add error handling if needed

    // Initialize local notifications (using Android configuration here)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap logic here if needed.
      },
    );

    // Subscribe to each topic
    for (final topic in _topics) {
      try {
        await _messaging.subscribeToTopic(topic);
        // Optionally print a debug message here
      } catch (e) {
        // Handle subscription errors if needed.
      }
    }

    // Listen for foreground messages and display them as local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });

    // Optionally handle onMessageOpenedApp (when user taps the notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle navigation or other processing as needed.
    });
  }

  void _showNotification(RemoteMessage message) {
    // Extract notification details from the message
    RemoteNotification? notification = message.notification;
    if (notification != null) {
      _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // channel ID
            'High Importance Notifications', // channel name
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: 'Default_Sound', // optional payload data
      );
    }
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
