import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static const int _dailyChallengeId = 1;
  static const String _channelId = 'daily_challenge';
  static const String _channelName = 'Daily Challenge';
  static const String _channelDesc =
      'Reminds you to play the daily Mine Master challenge';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Request notification permission (iOS prompts the user; Android 13+ also).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return false;
  }

  /// Schedule (or reschedule) the daily challenge notification for [hour]:[minute]
  /// every day. Call this on every app launch so it stays fresh.
  static Future<void> scheduleDailyChallenge({
    int hour = 9,
    int minute = 0,
  }) async {
    if (kIsWeb) return;

    // Cancel any existing scheduled notification first.
    await _plugin.cancel(_dailyChallengeId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If today's time has already passed, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final messages = [
      ("Your daily mine is ready 💣", "Can you clear it without blowing up? Challenge #${_todayChallengeNumber()} awaits."),
      ("Daily Challenge is live! 🚩", "A new board dropped. Tap to play Mine Master's daily puzzle."),
      ("Think you can survive today? 💥", "Mine Master's daily challenge is ready. Beat the clock!"),
      ("New day, new mines ⚡", "Daily Challenge #${_todayChallengeNumber()} is waiting for you."),
    ];

    final pick = messages[now.day % messages.length];

    await _plugin.zonedSchedule(
      _dailyChallengeId,
      pick.$1,
      pick.$2,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    await _plugin.cancel(_dailyChallengeId);
  }

  static int _todayChallengeNumber() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }
}
