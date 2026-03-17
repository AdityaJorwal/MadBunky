import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mad_bunky/providers/providers.dart';
import 'package:mad_bunky/utils/morph_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      // Successful login will update the authStateProvider,
      // which should trigger navigation in the root widget.
    } catch (e) {
      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Sign in failed: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Configurable App Logo/Title
              const Spacer(),
              _buildLogo(),
              const SizedBox(height: 48),

              // Login Button
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    _buildGoogleSignInButton(),
                    const SizedBox(height: 16),
                    _buildSkipButton(),
                  ],
                ),

              const Spacer(),
              const Text(
                "MadBunky",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Placeholder for an App Icon if one isn't available in assets helper
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.school_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Welcome to MadBunky",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Your ultimate attendance companion",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color
                    ?.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.tonal(
        onPressed: _handleGoogleSignIn,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a generic icon for Google if asset not ready,
            // but ideally you'd use an SVG asset.
            const Icon(Icons.login),
            const SizedBox(width: 12),
            const Text(
              "Sign in with Google",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _handleGuestLogin,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          "Skip for now",
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      // Offline mode: update guest state AND persist session type.
      // This uses the updated AuthService.signInAnonymously which is now offline-safe.
      await ref.read(authServiceProvider).signInAnonymously();
      ref.read(isGuestProvider.notifier).setGuestMode(true);
    } catch (e) {
      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Guest login failed: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
