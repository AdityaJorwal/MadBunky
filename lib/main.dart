import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/foundation.dart'; // Added for defaultTargetPlatform
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/models.dart';
import 'providers/providers.dart';

import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'services/live_activity_service.dart'; // Added
import 'services/quick_settings_service.dart'; // Added

import 'theme.dart';
import 'utils/globals.dart'; // Added for navigatorKey

import 'services/log_service.dart'; // Added for Logging

import 'widgets/auth_wrapper.dart'; // Added for AuthWrapper

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize LogService first
    await LogService().init();
    await LogService().log("App Starting...");

    try {
      await LogService().log("Initializing Firebase...");
      await Firebase.initializeApp();
      await LogService().log("Firebase Initialized.");
    } catch (e, stack) {
      await LogService().error("Firebase Init Error", stack);
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await LogService().log("Initializing LiveActivityService (iOS)...");
        await LiveActivityService().init();
        await LogService().log("LiveActivityService Initialized.");
      }
    } catch (e, stack) {
      await LogService().error("LiveActivity Init Error", stack);
    }

    try {
      await LogService().log("Initializing QuickSettingsService...");
      await QuickSettingsService().init();
      await LogService().log("QuickSettingsService Initialized.");
    } catch (e, stack) {
      await LogService().error("QuickSettings Init Error", stack);
    }

    try {
      LogService().log("Initializing NotificationService...");
      await NotificationService().init();
      LogService().log("NotificationService Initialized.");
    } catch (e, stack) {
      LogService().error("NotificationService Init Error", stack);
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('SharedPreferences initialization timed out');
        },
      );
    } catch (e, stack) {
      LogService().error('SharedPreferences initialization failed', stack);
    }

    if (prefs != null) {
      final p = prefs;
      // Seed initial data for widgets (critical for "Me Section" config list)
      // We do this in a microtask or background to not block startup
      Future.delayed(Duration.zero, () async {
        try {
          // Retrieve initial state from prefs
          final sessionsJson = p.getString('sessions');
          final scheduleJson = p.getString('schedule');

          List<ClassSession> sessions = [];
          if (sessionsJson != null) {
            try {
              final List<dynamic> cList = jsonDecode(sessionsJson);
              sessions = cList.map((e) => ClassSession.fromJson(e)).toList();
            } catch (e) {
              LogService().error("Seeding Error: Invalid Sessions JSON", null);
            }
          }

          if (sessions.isNotEmpty && scheduleJson != null) {
            try {
              final List<ScheduleTemplate> schedule =
                  (jsonDecode(scheduleJson) as List)
                      .map((e) => ScheduleTemplate.fromJson(e))
                      .toList();

              // Safe update
              await WidgetService.updateMyDayWidget(sessions, schedule);
            } catch (e) {
              LogService().error(
                  "Seeding Error: Invalid Schedule JSON or Update Failed",
                  null);
            }
          }
        } catch (e, stack) {
          LogService()
              .error("Failed to seed widget data (Global Catch)", stack);
        }
      });

      FlutterError.onError = (FlutterErrorDetails details) {
        LogService()
            .error("Flutter Error: ${details.exception}", details.stack);
        FlutterError.presentError(details);
      };

      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MadBunkyApp(),
        ),
      );
    } else {
      runApp(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Failed to initialize app settings.\nPlease restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    // Register Port for Background Communication
    final ReceivePort port = ReceivePort();
    IsolateNameServer.removePortNameMapping('notification_port');
    IsolateNameServer.registerPortWithName(port.sendPort, 'notification_port');

    // Listen for background actions and forward to Service stream
    port.listen((message) {
      if (message is NotificationResponse) {
        debugPrint("Main Isolate received action: ${message.actionId}");
        // Use processAction to Avoid Loop (broadcastAction sends back to port -> loop)
        NotificationService.processAction(message);
      } else if (message == "reload_data") {
        debugPrint("Main Isolate received RELOAD request from Background");
        NotificationService.processAction(const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'reload_data'));
      }
    });
  }, (error, stack) {
    LogService().error('Uncaught error in runZonedGuarded', stack);
  });
}

class MadBunkyApp extends ConsumerWidget {
  const MadBunkyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // If Material You is disabled, pass null to force fallback (Pastel Red)
        final lightScheme = settings.useMaterialYou ? lightDynamic : null;
        final darkScheme = settings.useMaterialYou ? darkDynamic : null;

        return MaterialApp(
          title: 'MasterBunker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(
            lightScheme,
            preset: settings.themePreset,
            customThemeColor: settings.customThemeColor != null
                ? Color(settings.customThemeColor!)
                : null,
            isNeon: settings.isNeon, // Added
          ),
          darkTheme: AppTheme.darkTheme(
            darkScheme,
            preset: settings.themePreset,
            customThemeColor: settings.customThemeColor != null
                ? Color(settings.customThemeColor!)
                : null,
            isNeon: settings.isNeon, // Added
          ),
          themeMode: settings.themeMode == ThemeType.system
              ? ThemeMode.system
              : (settings.themeMode == ThemeType.light
                  ? ThemeMode.light
                  : ThemeMode.dark),
          navigatorKey: navigatorKey,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}
