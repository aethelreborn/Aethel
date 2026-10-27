import 'package:flutter/foundation.dart';

import '../../core/notifications/reminder_service.dart';
import 'device_services.dart';

/// What Aethel still needs from the platform before a feature can work.
enum PermissionStage { granted, prompt, blocked, notNeeded, unavailable }

/// One permission Aethel asks for, written in the words it uses in the UI.
class PermissionEntry {
  const PermissionEntry({
    required this.key,
    required this.title,
    required this.detail,
    required this.stage,
  });

  final String key;
  final String title;
  final String detail;
  final PermissionStage stage;

  bool get needsAction =>
      stage == PermissionStage.prompt || stage == PermissionStage.blocked;

  PermissionEntry copyWith({PermissionStage? stage}) => PermissionEntry(
        key: key,
        title: title,
        detail: detail,
        stage: stage ?? this.stage,
      );
}

/// Reads the current permission state of this device and asks for whatever
/// is still missing. Entries stay empty when the platform has nothing to
/// grant, so nothing is shown just to be shown.
class PermissionCatalog {
  const PermissionCatalog._();

  static Future<List<PermissionEntry>> load() async {
    final entries = <PermissionEntry>[];

    if (ReminderService.instance.canScheduleReminders) {
      final state = await ReminderService.instance.permission();
      if (state != ReminderPermission.unsupported) {
        entries.add(PermissionEntry(
          key: 'reminders',
          title: 'Reminders',
          detail: 'Tell me when a focus window starts and when a bill is due.',
          stage: state == ReminderPermission.granted
              ? PermissionStage.granted
              : state == ReminderPermission.notRequired
                  ? PermissionStage.notNeeded
                  : PermissionStage.prompt,
        ));
      }
    }

    final capabilities = await DeviceServices.instance.capabilities();
    if (capabilities.appBlocking) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final usage = await DeviceServices.instance.hasUsageAccess();
        entries.add(PermissionEntry(
          key: 'blocking',
          title: 'App access',
          detail: 'See which app is open so Focus mode can hold the block.',
          stage: usage ? PermissionStage.granted : PermissionStage.prompt,
        ));
        final overlay = await DeviceServices.instance.hasOverlayPermission();
        entries.add(PermissionEntry(
          key: 'overlay',
          title: 'Display over other apps',
          detail: 'Draw the block wall over a blocked app immediately.',
          stage: overlay ? PermissionStage.granted : PermissionStage.prompt,
        ));
        final a11y = await DeviceServices.instance.hasAccessibilityBlocker();
        entries.add(PermissionEntry(
          key: 'accessibility',
          title: 'Accessibility (fast block)',
          detail: 'Lets the wall rise the instant a blocked app opens.',
          stage: a11y ? PermissionStage.granted : PermissionStage.prompt,
        ));
      } else {
        entries.add(const PermissionEntry(
          key: 'blocking',
          title: 'App blocking',
          detail: 'Force-closes blocked apps while the session runs.',
          stage: PermissionStage.granted,
        ));
      }
    }

    return entries;
  }

  static Future<List<PermissionEntry>> request(PermissionEntry entry) async {
    // The system has already refused this one, so asking again would only
    // re-prompt or be silently dropped. Send the user to the page where they
    // can switch it back on themselves.
    if (entry.stage == PermissionStage.blocked) {
      await openSystemSettings(entry.key);
      return load();
    }
    if (entry.key == 'reminders') {
      final outcome = await ReminderService.instance.request();
      final refreshed = await load();
      if (outcome == ReminderPermission.granted) return refreshed;
      // The system said no. On Android we can still open the switch for it.
      if (defaultTargetPlatform == TargetPlatform.android) {
        return [
          for (final item in refreshed)
            if (item.key == entry.key)
              item.copyWith(stage: PermissionStage.blocked)
            else
              item,
        ];
      }
      return refreshed;
    }
    if (entry.key == 'blocking') {
      await DeviceServices.instance.requestUsageAccess();
    } else if (entry.key == 'overlay') {
      await DeviceServices.instance.requestOverlayPermission();
    } else if (entry.key == 'accessibility') {
      await DeviceServices.instance.requestAccessibilityBlocker();
    }
    return load();
  }

  /// Opens the platform page where a permanently refused permission can be
  /// switched back on. Only Android can jump there directly.
  static Future<void> openSystemSettings(String key) async {
    if (key == 'reminders') {
      await DeviceServices.instance.openNotificationSettings();
    } else if (key == 'blocking') {
      await DeviceServices.instance.requestUsageAccess();
    } else if (key == 'overlay') {
      await DeviceServices.instance.requestOverlayPermission();
    } else if (key == 'accessibility') {
      await DeviceServices.instance.requestAccessibilityBlocker();
    }
  }
}
