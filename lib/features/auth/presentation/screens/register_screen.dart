import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/enums/user_role.dart';
import '../viewmodels/register_viewmodel.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final success =
        await ref.read(registerViewModelProvider.notifier).signUp(
              fullName: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
              phone: _phoneController.text,
            );

    if (!mounted) return;
    final pending =
        ref.read(registerViewModelProvider).pendingMessage;
    if (pending != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pending), duration: const Duration(seconds: 6)),
      );
      context.go(RoutePaths.login);
      return;
    }
    if (success) {
      // GoRouter redirect handles role-based navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      title: 'Create account',
                      subtitle: Env.useDriverApi
                          ? 'Customers can sign in immediately. Drivers and dispatchers wait for admin verification.'
                          : 'Register as any role for demo testing',
                    ),
                    const SizedBox(height: 32),
                    if (state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AuthTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      prefixIcon: Icons.person_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone (optional)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      value: state.selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: (Env.useDriverApi
                              ? const [
                                  UserRole.customer,
                                  UserRole.hubWorker,
                                  UserRole.dispatcher,
                                ]
                              : UserRole.registerChoices)
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(
                                role == UserRole.hubWorker && Env.useDriverApi
                                    ? 'Driver'
                                    : role.label,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: state.isLoading
                          ? null
                          : (role) {
                              if (role != null) {
                                ref
                                    .read(registerViewModelProvider.notifier)
                                    .setRole(role);
                              }
                            },
                    ),
                    if (state.needsZones && Env.useDriverApi) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your ${state.selectedRole == UserRole.dispatcher ? 'dispatcher' : 'driver'} account will stay pending until an IPOSB admin approves it.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (state.needsZones) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Preferred zones',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DemoZones.all.map((zone) {
                          final selected =
                              state.preferredZones.contains(zone);
                          return FilterChip(
                            label: Text(DemoZones.labelOf(zone)),
                            selected: selected,
                            onSelected: state.isLoading
                                ? null
                                : (_) => ref
                                    .read(registerViewModelProvider.notifier)
                                    .toggleZone(zone),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outlined,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSubmit(),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isLoading ? null : _onSubmit,
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go(RoutePaths.login),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
