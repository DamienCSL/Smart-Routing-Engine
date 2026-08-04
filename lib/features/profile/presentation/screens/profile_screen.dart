import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isSaving = false;
  List<String> _preferredZones = const [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateFields(UserProfile profile) {
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';
    final session = ref.read(driverApiSessionProvider);
    _preferredZones = List<String>.from(session?.preferredZones ?? const []);
  }

  bool get _canEditZones {
    final session = ref.read(driverApiSessionProvider);
    if (session == null) return false;
    return session.role == UserRole.dispatcher ||
        session.role == UserRole.hubWorker ||
        session.role == UserRole.driver;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      if (_canEditZones) {
        if (_preferredZones.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one preferred zone')),
          );
          return;
        }
        setState(() => _isSaving = true);
        try {
          await ref
              .read(driverApiSessionProvider.notifier)
              .updatePreferredZones(_preferredZones);
          if (!mounted) return;
          ref.invalidate(currentUserProfileProvider);
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferred zones updated')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is managed in IPOSB ops (t_driver).')),
      );
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    final result = await ref.read(authRepositoryProvider).updateProfile(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );

    if (!mounted) return;

    setState(() => _isSaving = false);

    result.when(
      success: (_) {
        ref.invalidate(currentUserProfileProvider);
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Future<void> _signOut() async {
    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      await ref.read(driverApiSessionProvider.notifier).signOut();
      if (mounted) context.go(RoutePaths.login);
      return;
    }
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (profileAsync.valueOrNull != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Loading profile...'),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }

          if (!_isEditing && _nameController.text.isEmpty) {
            _populateFields(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Chip(
                    avatar: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(profile.role.label),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _ProfileField(
                            label: 'Email',
                            value: profile.email,
                            icon: Icons.email_outlined,
                          ),
                          const Divider(height: 24),
                          if (_isEditing) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outlined),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ] else ...[
                            _ProfileField(
                              label: 'Full Name',
                              value: profile.fullName,
                              icon: Icons.person_outlined,
                            ),
                            const Divider(height: 24),
                            _ProfileField(
                              label: 'Phone',
                              value: profile.phone ?? '—',
                              icon: Icons.phone_outlined,
                            ),
                          ],
                          if (Env.useDriverApi && _canEditZones) ...[
                            const Divider(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Preferred zones',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: DemoZones.all.map((zone) {
                                  final selected =
                                      _preferredZones.contains(zone);
                                  return FilterChip(
                                    label: Text(DemoZones.labelOf(zone)),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        final next = [..._preferredZones];
                                        if (selected) {
                                          next.remove(zone);
                                        } else {
                                          next.add(zone);
                                        }
                                        _preferredZones = next;
                                      });
                                    },
                                  );
                                }).toList(),
                              )
                            else
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _preferredZones.isEmpty
                                      ? '—'
                                      : _preferredZones
                                          .map(DemoZones.labelOf)
                                          .join(', '),
                                ),
                              ),
                          ],
                          const Divider(height: 24),
                          _ProfileField(
                            label: 'Member Since',
                            value: DateFormat.yMMMd().format(profile.createdAt),
                            icon: Icons.calendar_today_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    _populateFields(profile);
                                    setState(() => _isEditing = false);
                                  },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
