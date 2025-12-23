import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'native_service.dart';
import 'background_service.dart';
import '../models/account.dart';

final runtimeManagerProvider =
    StateNotifierProvider<RuntimeManager, Set<String>>(
      (ref) => RuntimeManager(),
    );

class RuntimeManager extends StateNotifier<Set<String>> {
  final MN _mn = MN();
  final Map<String, MMHandle> _handles = {};
  final Map<String, Timer> _logTimers = {};
  final Map<String, StreamController<String>> _logControllers = {};

  RuntimeManager() : super({});

  void ensureHandle(Account account) {
    if (_handles.containsKey(account.id)) return;

    final existingHandle = _mn.findHandle(account.username);
    if (existingHandle != nullptr) {
      _handles[account.id] = existingHandle;

      if (_mn.isRunning(existingHandle) && !state.contains(account.id)) {
        _attachPollingLoop(account.id, existingHandle);

        Future.microtask(() {
          if (!mounted) return;
          state = {...state, account.id};

          if (state.isNotEmpty) {
            AndroidBackgroundService.start();
          }
        });
      }
      return;
    }

    _handles[account.id] = _mn.create();
  }

  Future<void> checkServiceCleanup() async {
    if (!Platform.isAndroid) return;

    await Future.delayed(const Duration(seconds: 2));

    bool anyRunningNatively = false;
    for (final handle in _handles.values) {
      if (_mn.isRunning(handle)) {
        anyRunningNatively = true;
        break;
      }
    }

    if (!anyRunningNatively && state.isEmpty) {
      AndroidBackgroundService.stop();
    }
  }

  void _attachPollingLoop(String accountId, MMHandle handle) {
    _logTimers[accountId]?.cancel();
    final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _broadcastLog(accountId, _mn.getLogs(handle));

      if (!_mn.isRunning(handle)) {
        _internalStop(accountId);
      }
    });
    _logTimers[accountId] = timer;
  }

  void destroyHandle(String accountId) {
    final handle = _handles[accountId];
    if (handle != null) {
      if (state.contains(accountId)) {
        stopAccount(accountId);
      }
      _mn.destroy(handle);
      _handles.remove(accountId);
    }

    _logControllers[accountId]?.close();
    _logControllers.remove(accountId);

    if (_handles.isEmpty) {
      if (Platform.isAndroid) AndroidBackgroundService.stop();
    }
  }

  Stream<String> getLogStream(String accountId) {
    if (!_logControllers.containsKey(accountId)) {
      _logControllers[accountId] = StreamController.broadcast();
    }

    return _logControllers[accountId]!.stream;
  }

  String getLogs(String accountId) {
    final handle = _handles[accountId];
    if (handle != null) {
      return _mn.getLogs(handle);
    }
    return '';
  }

  Future<void> startAccount(Account account) async {
    ensureHandle(account);
    final handle = _handles[account.id]!;

    if (state.contains(account.id)) return;

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        final result =
            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        if (!result) return;
      }

      NotificationPermission notificationPermissionStatus =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermissionStatus != NotificationPermission.granted) {
        final result =
            await FlutterForegroundTask.requestNotificationPermission();
        if (result != NotificationPermission.granted) return;
      }
    }

    if (state.isEmpty) {
      AndroidBackgroundService.start();
    }

    _mn.clearLogs(handle);
    _broadcastLog(account.id, '');

    _mn.start(handle, account.username, account.password);

    final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _broadcastLog(account.id, _mn.getLogs(handle));

      if (!_mn.isRunning(handle)) {
        _internalStop(account.id);
      }
    });

    _logTimers[account.id] = timer;
    state = {...state, account.id};
  }

  void stopAccount(String accountId) {
    final handle = _handles[accountId];
    final timer = _logTimers[accountId];

    if (handle == null) return;

    timer?.cancel();
    _mn.stop(handle);
    _internalStop(accountId);
  }

  void _internalStop(String accountId) {
    _logTimers[accountId]?.cancel();
    _logTimers.remove(accountId);

    state = {...state}..remove(accountId);

    if (state.isEmpty) {
      AndroidBackgroundService.stop();
    }
  }

  void clearLogs(String accountId) {
    final handle = _handles[accountId];
    if (handle != null) {
      _mn.clearLogs(handle);
      _broadcastLog(accountId, '');
    }
  }

  void sendChat(String accountId, String text) {
    final handle = _handles[accountId];
    if (handle != null) {
      _mn.sendChat(handle, text);
    }
  }

  void _broadcastLog(String accountId, String text) {
    final controller = _logControllers[accountId];
    if (controller != null && !controller.isClosed) {
      controller.add(text);
    }
  }
}
