import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'email_auth_screen.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.local_florist, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              const Text(
                'Save your plant history\nacross devices',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
              _AuthButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: () => _signIn(context, ref, 'google'),
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: 12),
                _AuthButton(
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  onPressed: () => _signIn(context, ref, 'apple'),
                ),
              ],
              const SizedBox(height: 12),
              _AuthButton(
                label: 'Continue with Email',
                icon: Icons.email_outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Continue as Guest',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(
      BuildContext context, WidgetRef ref, String provider) async {
    final auth = ref.read(authServiceProvider);
    try {
      if (provider == 'google') await auth.linkOrSignInWithGoogle();
      if (provider == 'apple') await auth.linkOrSignInWithApple();
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _AuthButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }
}
