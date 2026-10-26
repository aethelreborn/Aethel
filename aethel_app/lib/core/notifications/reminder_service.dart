import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models.dart';
import '../utils/format.dart';

/// Outcome of asking the user for the right to show reminders.
enum ReminderPermission { granted, denied, notRequired, unsupported }

/// Schedules the two reminders Aethel has: focus windows starting and bills
/// coming due. The whole set is rebuilt from local data on every sync, so
/// what is scheduled always mirrors what is in the vault.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const _channelId = 'aethel_reminders';
  static const _channelName = 'Reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Linux has no scheduled-notification support in the plugin; everything
  /// else Aethel ships to does.
  static bool get _supportsScheduling =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  static bool get _supportsRecurrence =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get _needsPermissionPrompt =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get canScheduleReminders => _supportsScheduling;

  Future<void>? _initialising;

  /// Safe to call from several places; the work happens exactly once.
  Future<void> init() => _initialising ??= _initialise();

  Future<void> _initialise() async {
    if (kIsWeb || !_supportsScheduling) return;
    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(info.identifier);
      tz.setLocalLocation(location);
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      windows: WindowsInitializationSettings(
        appName: 'Aethel',
        appUserModelId: 'com.aethel.aethel',
        guid: 'b6a2f4c8-4f3e-4a51-9f5d-2c8d7e1a9b43',
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
    } catch (_) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Focus windows and bills coming due.',
              importance: Importance.defaultImportance,
            ));
      } catch (_) {
        // A missing channel only affects presentation, not scheduling.
      }
    }
    _ready = true;
  }

  Future<ReminderPermission> permission() async {
    if (kIsWeb || !_supportsScheduling) return ReminderPermission.unsupported;
    await init();
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final enabled = await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled();
          if (enabled == false) return ReminderPermission.denied;
          return enabled == true
              ? ReminderPermission.granted
              : ReminderPermission.notRequired;
        case TargetPlatform.iOS:
          final status = await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
          if (status == null) return ReminderPermission.notRequired;
          return status.isEnabled
              ? ReminderPermission.granted
              : ReminderPermission.denied;
        case TargetPlatform.macOS:
          final status = await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
          if (status == null) return ReminderPermission.notRequired;
          return status.isEnabled
              ? ReminderPermission.granted
              : ReminderPermission.denied;
        default:
          return ReminderPermission.notRequired;
      }
    } catch (_) {
      return ReminderPermission.notRequired;
    }
  }

  /// Shows the platform prompt. Returns the state after the user answered.
  Future<ReminderPermission> request() async {
    if (!_needsPermissionPrompt) return permission();
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        case TargetPlatform.iOS:
          await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.macOS:
          await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        default:
          break;
      }
    } catch (_) {
      // Fall through and read whatever state we ended up in.
    }
    return permission();
  }

  /// Rebuilds every scheduled reminder from the current data.
  Future<void> sync({
    required List<FocusSchedule> schedules,
    required List<BillItem> bills,
  }) async {
    await init();
    if (!_ready || !_supportsScheduling) return;
    try {
      await _plugin.cancelAllPendingNotifications();

      final now = DateTime.now();
      for (final schedule in schedules) {
        if (!schedule.enabled) continue;
        final next = _nextWindowStart(schedule, now);
        if (next == null) continue;
        await _plugin.zonedSchedule(
          id: _stableId(schedule.id, 1),
          scheduledDate: tz.TZDateTime.from(next, tz.local),
          title: 'Focus window · ${schedule.label}',
          body: _windowBody(schedule),
          payload: 'schedule:${schedule.id}',
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              _supportsRecurrence ? DateTimeComponents.dayOfWeekAndTime : null,
        );
      }

      for (final bill in bills) {
        if (!bill.isActive) continue;
        final due = bill.nextDueDate;
        if (due == null) continue;
        final fireAt = DateTime(due.year, due.month, due.day, 9, 0);
        if (!fireAt.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _stableId(bill.id, 2),
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          title: '${bill.title} is due today',
          body: '${formatMoney(bill.amount)} · tap to mark it paid.',
          payload: 'bill:${bill.id}',
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      debugPrint('Reminder sync failed: $error');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Focus windows and bills coming due.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

  String _windowBody(FocusSchedule schedule) {
    final blocked = schedule.blockedApps.length;
    if (blocked == 0) return '${schedule.timeRange} is clear for focused work.';
    return '${schedule.timeRange} · $blocked app${blocked == 1 ? '' : 's'} blocked.';
  }

  /// First start of [schedule] that is still in the future.
  static DateTime? _nextWindowStart(FocusSchedule schedule, DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      // DateTime.weekday: Mon = 1 … Sun = 7, matching FocusSchedule.days.
      if (!schedule.days.contains(day.weekday)) continue;
      final start = day.add(Duration(minutes: schedule.startMinutes));
      if (start.isAfter(now)) return start;
    }
    return null;
  }

  /// Notification ids stay stable per record so a re-sync replaces rather
  /// than duplicates. Each kind gets its own numeric range.
  static int _stableId(String key, int salt) {
    var hash = 7;
    for (final code in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + code);
    }
    return salt * 10000000 + (hash % 1000000);
  }
}
