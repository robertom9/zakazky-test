import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotifikacnaSluzba {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> inicializuj() async {
    if (kIsWeb) return; // Nepodporujeme web

    const nastavenia = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      ),
    );

    await plugin.initialize(nastavenia);
  }

  static Future<void> naplanujUpozornenie(
    int id,
    String nazovZakazky,
    DateTime termin,
  ) async {
    if (kIsWeb) return;

    final casNotifikacie = tz.TZDateTime.from(
      termin.subtract(const Duration(days: 1)),
      tz.local,
    );

    await plugin.zonedSchedule(
      id,
      'Termín sa blíži',
      'Zákazka "$nazovZakazky" má termín zajtra!',
      casNotifikacie,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zakazky_kanal',
          'Zákazky',
          channelDescription: 'Upozornenia na termíny zákaziek',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> zrus(int id) async {
    if (kIsWeb) return;
    await plugin.cancel(id);
  }

  static Future<void> zrusVsetky() async {
    if (kIsWeb) return;
    await plugin.cancelAll();
  }
}
