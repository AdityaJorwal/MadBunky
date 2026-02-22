import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/login_screen.dart';
import '../screens/main_scaffold.dart';
import '../utils/sync_manager.dart';
import '../services/notification_image_generator.dart';
import 'global_gesture_handler.dart';
import '../providers/providers.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restoration = ref.watch(authRestorationProvider);

    return restoration.when(
      data: (_) {
        final authState = ref.watch(authStateProvider);
        return authState.when(
          data: (user) {
            if (user != null) {
              // User is authenticated
              return GlobalGestureHandler(
                child: SyncManager(
                  child: NotificationImageGenerator.wrapper(
                    child: const MainScaffold(),
                  ),
                ),
              );
            } else {
              // User is not authenticated
              return const LoginScreen();
            }
          },
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Scaffold(
            body: Center(
              child: Text("Authentication Error: $error"),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.white, // Or theme background
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        // Fallback toAuthState logic even if restoration fails?
        // Or show error? Better to just show LoginScreen if restoration fails.
        return const LoginScreen();
      },
    );
  }
}
