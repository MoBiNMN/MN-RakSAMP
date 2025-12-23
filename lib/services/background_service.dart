import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class AndroidBackgroundService {
  static Future<void> init() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mn_raksamp_service',
        channelName: 'MN-RakSAMP Foreground Service',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(300000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'MN-RakSAMP is running',
      notificationText: 'Keeping accounts online...',
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(EmptyTaskHandler());
}

class EmptyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("/");
  }
}
