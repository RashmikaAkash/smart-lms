import 'package:flutter/services.dart';

class NotificationService {
  const NotificationService._();

  static const MethodChannel _channel =
      MethodChannel('smart_lms/notifications');

  static Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> show({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      final shown = await _channel.invokeMethod<bool>('show', {
        'id': id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'title': title,
        'body': body,
      });
      return shown ?? false;
    } on PlatformException {
      return false;
    }
  }
}
