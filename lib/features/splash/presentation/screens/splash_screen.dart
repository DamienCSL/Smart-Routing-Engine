import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/router/role_redirect.dart';
import '../../../../core/utils/logger.dart';

/// Splash screen — branding, then navigates to login or role home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
  }

  Future<void> _navigateNext() async {
    // Brief branding delay.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (!Env.isConfigured) {
      AppLogger.info('Splash: env not configured — staying on setup view');
      return;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        AppLogger.info('Splash: navigating to login');
        context.go(RoutePaths.login);
        return;
      }

      final role = roleFromMetadata(session.user.userMetadata);
      final home = homePathForRole(role);
      AppLogger.info('Splash: navigating to $home');
      context.go(home);
    } catch (e, st) {
      AppLogger.error('Splash navigation failed — falling back to login', e, st);
      if (mounted) context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showSetup = !Env.isConfigured;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: showSetup ? _SetupView(theme: theme) : _LoadingView(theme: theme),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: 80,
          color: theme.colorScheme.onPrimary,
        ),
        const SizedBox(height: 24),
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppConstants.appTagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Icon(
            Icons.settings_suggest_outlined,
            size: 64,
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(height: 24),
          Text(
            'Setup Required',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Configure Supabase and run migrations before signing in.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 32),
          _SetupStep(
            number: '1',
            text: 'Create a Supabase project at supabase.com',
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(height: 12),
          _SetupStep(
            number: '2',
            text: 'Run 001_initial_schema.sql and 002_auth_rls.sql',
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(height: 12),
          _SetupStep(
            number: '3',
            text: 'Update .env with SUPABASE_URL and SUPABASE_ANON_KEY',
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(height: 12),
          _SetupStep(
            number: '4',
            text: 'Disable email confirmation in Supabase Auth settings (demo)',
            color: theme.colorScheme.onPrimary,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.text,
    required this.color,
  });

  final String number;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            number,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color.withValues(alpha: 0.9)),
          ),
        ),
      ],
    );
  }
}
