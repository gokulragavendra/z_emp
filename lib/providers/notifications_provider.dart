// lib/providers/notifications_provider.dart
import 'package:flutter/material.dart';

class NotificationsProvider extends ChangeNotifier {
  bool _enablePush = true;
  bool _soundAndVibration = true;
  bool _inAppAlerts = true;

  bool get enablePush => _enablePush;
  bool get soundAndVibration => _soundAndVibration;
  bool get inAppAlerts => _inAppAlerts;

  set enablePush(bool value) {
    _enablePush = value;
    notifyListeners();
  }

  set soundAndVibration(bool value) {
    _soundAndVibration = value;
    notifyListeners();
  }

  set inAppAlerts(bool value) {
    _inAppAlerts = value;
    notifyListeners();
  }
}
