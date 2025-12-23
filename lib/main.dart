import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import '../services/checkupdate_service.dart';
import 'services/background_service.dart';
import 'services/runtime_manager.dart';
import 'providers/accounts_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await localNotifier.setup(appName: 'MN-RakSAMP');
  }

  if (Platform.isAndroid) {
    await AndroidBackgroundService.init();
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(400, 500),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setPreventClose(true);

    final SystemTray systemTray = SystemTray();
    await systemTray.initSystemTray(
      title: "MN-RakSAMP",
      iconPath: 'assets/app_icon.ico',
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show App',
        onClicked: (menuItem) => windowManager.show(),
      ),
      MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
    ]);
    await systemTray.setContextMenu(menu);

    systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        systemTray.popUpContextMenu();
      }
    });
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MNRakSAMP(),
    ),
  );
}

class MNRakSAMP extends ConsumerStatefulWidget {
  const MNRakSAMP({super.key});

  @override
  ConsumerState<MNRakSAMP> createState() => _MNRakSAMPState();
}

class _MNRakSAMPState extends ConsumerState<MNRakSAMP> with WindowListener {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final info = await CheckUpdateService().check();
        if (!info.hasUpdate) return;
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => UpdateDialog(info: info),
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final runningAccounts = ref.read(runtimeManagerProvider);

    if (runningAccounts.isEmpty) {
      exit(0);
    }

    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      LocalNotification notification = LocalNotification(
        title: "Minimized to Tray",
        body: "MN-RakSAMP is still running in the background.",
      );
      notification.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'MN-RakSAMP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}
