import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Future<void> init() async {
    if (_initialized) return;
    if (!_isSupportedPlatform) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showNewOrderNotification({
    required String orderNumber,
    required String customerName,
  }) async {
    if (!_isSupportedPlatform) return;

    const androidDetails = AndroidNotificationDetails(
      'new_orders',
      'Nuevos pedidos',
      channelDescription: 'Notificaciones cuando se crea un nuevo pedido',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      orderNumber.hashCode.abs(),
      '📦 Nuevo pedido #$orderNumber',
      customerName.isNotEmpty ? 'Cliente: $customerName' : 'Se registró un nuevo pedido',
      details,
    );
  }
}
