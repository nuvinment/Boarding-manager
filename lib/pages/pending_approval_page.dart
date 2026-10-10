import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

/// Shown to boarders whose account is pending manager approval.
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 56,
                  color: colors.tertiary,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Awaiting Approval',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Your registration has been received.\n\n'
                'The manager will review your details, assign you a room, and activate your account.\n\n'
                'You will be able to log in and access your bills once your account is approved.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              OutlinedButton.icon(
                onPressed: () async {
                  // Try refreshing — maybe manager just approved
                  final ok = await AuthService.instance.restoreSession();
                  if (!ok) return;
                  final user = AuthService.instance.currentUser;
                  if (user != null && user.status.dbValue == 'active') {
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Still awaiting approval. Please check back soon.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Text('Sign Out', style: TextStyle(color: colors.error)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
