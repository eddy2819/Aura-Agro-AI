import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._init();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init() {
    _initNotifications();
  }

  bool get isInitialized => _isInitialized;

  Future<void> _initNotifications() async {
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      _isInitialized =
          await _notificationsPlugin.initialize(
            settings: initializationSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {
              debugPrint("Notification clicked: ${response.payload}");
            },
          ) ??
          false;
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      debugPrint("Notifications initialized successfully: $_isInitialized");
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await _initNotifications();
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'aura_alerts_channel',
          'Alertas de AURA Agro',
          channelDescription:
              'Canal para alertas críticas e inventario de AURA Agro',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) await _initNotifications();

    // Garantizar que la fecha esté en el futuro
    DateTime targetDate = scheduledDate;
    if (targetDate.isBefore(DateTime.now())) {
      targetDate = DateTime.now().add(const Duration(minutes: 1));
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'aura_schedule_channel',
          'Recordatorios Programados',
          channelDescription: 'Canal para vacunas y tratamientos programados',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(targetDate, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    debugPrint("Scheduled notification id=$id on $targetDate");
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
    debugPrint("Cancelled notification id=$id");
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("Cancelled all scheduled notifications");
  }
}
