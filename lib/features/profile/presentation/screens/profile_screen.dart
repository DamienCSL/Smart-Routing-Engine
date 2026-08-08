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
import '../../../customer/domain/entities/saved_address.dart';
import '../../../customer/presentation/widgets/address_book_sheet.dart';
import '../../../dispatcher/presentation/providers/dispatcher_providers.dart';
import '../../../hub_worker/presentation/providers/hub_worker_providers.dart';

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
  bool _didRefresh = false;
  List<String> _preferredZones = const [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSession());
  }

  Future<void> _refreshSession() async {
    if (_didRefresh) return;
    if (!(Env.useDriverApi && !Env.isSupabaseConfigured)) return;
    if (ref.read(driverApiSessionProvider) == null) return;
    _didRefresh = true;
    try {
      await ref.read(driverApiSessionProvider.notifier).refreshMe();
      if (mounted) ref.invalidate(currentUserProfileProvider);
    } catch (_) {
      // Older API without /auth/me — keep login payload.
    }
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
    _preferredZones = List<String>.from(
      session?.preferredZones.isNotEmpty == true
          ? session!.preferredZones
          : profile.preferredZones,
    );
  }

  bool get _canEditZones {
    final session = ref.read(driverApiSessionProvider);
    if (session == null) return false;
    return session.role == UserRole.dispatcher ||
        session.role == UserRole.hubWorker ||
        session.role == UserRole.driver;
  }

  bool get _canEditIdentity => true;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      if (_canEditZones && _preferredZones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one preferred zone')),
        );
        return;
      }

      setState(() => _isSaving = true);
      try {
        await ref.read(driverApiSessionProvider.notifier).updateProfile(
              fullName: _nameController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
            );
        if (_canEditZones) {
          await ref
              .read(driverApiSessionProvider.notifier)
              .updatePreferredZones(_preferredZones);
        }
        if (!mounted) return;
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(hubWorkerProfileProvider);
        ref.invalidate(dispatcherProfileProvider);
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
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

  Future<void> _openAddressBook() async {
    await showAddressBookPicker(
      context: context,
      ref: ref,
      kind: AddressBookKind.both,
    );
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
              tooltip: 'Edit profile',
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

          if (!_isEditing &&
              (_nameController.text.isEmpty ||
                  _nameController.text != profile.fullName)) {
            _populateFields(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(profile: profile),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Account',
                    children: [
                      _ProfileField(
                        label: 'Email',
                        value: profile.email,
                        icon: Icons.email_outlined,
                      ),
                      const Divider(height: 24),
                      if (_isEditing && _canEditIdentity) ...[
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
                          value: (profile.phone == null ||
                                  profile.phone!.isEmpty)
                              ? '—'
                              : profile.phone!,
                          icon: Icons.phone_outlined,
                        ),
                      ],
                      const Divider(height: 24),
                      _ProfileField(
                        label: 'Status',
                        value: profile.isActive ? 'Active' : 'Inactive',
                        icon: profile.isActive
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                      ),
                      const Divider(height: 24),
                      _ProfileField(
                        label: 'Member Since',
                        value: DateFormat.yMMMd().format(profile.createdAt),
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _RoleDetailsSection(
                    profile: profile,
                    isEditing: _isEditing,
                    preferredZones: _preferredZones,
                    canEditZones: _canEditZones,
                    onZonesChanged: (zones) =>
                        setState(() => _preferredZones = zones),
                    onManageAddresses: Env.useDriverApi &&
                            !Env.isSupabaseConfigured &&
                            profile.role == UserRole.customer
                        ? _openAddressBook
                        : null,
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

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Chip(
          avatar: const Icon(Icons.badge_outlined, size: 18),
          label: Text(profile.role.label),
        ),
      ],
    );
  }
}

class _RoleDetailsSection extends ConsumerWidget {
  const _RoleDetailsSection({
    required this.profile,
    required this.isEditing,
    required this.preferredZones,
    required this.canEditZones,
    required this.onZonesChanged,
    this.onManageAddresses,
  });

  final UserProfile profile;
  final bool isEditing;
  final List<String> preferredZones;
  final bool canEditZones;
  final ValueChanged<List<String>> onZonesChanged;
  final VoidCallback? onManageAddresses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (profile.role) {
      case UserRole.customer:
        return _SectionCard(
          title: 'Customer details',
          children: [
            _ProfileField(
              label: 'Account No.',
              value: (profile.accountNo == null || profile.accountNo!.isEmpty)
                  ? '—'
                  : profile.accountNo!,
              icon: Icons.badge_outlined,
            ),
            if (onManageAddresses != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onManageAddresses,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Manage address book'),
              ),
            ],
          ],
        );
      case UserRole.hubWorker:
      case UserRole.driver:
      case UserRole.admin:
        return _HubOpsDetails(
          profile: profile,
          isEditing: isEditing,
          preferredZones: preferredZones,
          canEditZones: canEditZones,
          onZonesChanged: onZonesChanged,
        );
      case UserRole.dispatcher:
        return _DispatcherDetails(
          profile: profile,
          isEditing: isEditing,
          preferredZones: preferredZones,
          canEditZones: canEditZones,
          onZonesChanged: onZonesChanged,
        );
      case UserRole.dropPoint:
        return _SectionCard(
          title: 'Drop point details',
          children: [
            _ProfileField(
              label: 'Role',
              value: 'Drop Point operator',
              icon: Icons.storefront_outlined,
            ),
            const Divider(height: 24),
            _ProfileField(
              label: 'User ID',
              value: profile.id,
              icon: Icons.fingerprint,
            ),
          ],
        );
      case UserRole.storekeeper:
        return _SectionCard(
          title: 'Storekeeper details',
          children: [
            _ProfileField(
              label: 'Role',
              value: 'Hub storekeeper',
              icon: Icons.inventory_2_outlined,
            ),
            const Divider(height: 24),
            _ProfileField(
              label: 'User ID',
              value: profile.id,
              icon: Icons.fingerprint,
            ),
          ],
        );
    }
  }
}

class _HubOpsDetails extends ConsumerWidget {
  const _HubOpsDetails({
    required this.profile,
    required this.isEditing,
    required this.preferredZones,
    required this.canEditZones,
    required this.onZonesChanged,
  });

  final UserProfile profile;
  final bool isEditing;
  final List<String> preferredZones;
  final bool canEditZones;
  final ValueChanged<List<String>> onZonesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(hubWorkerProfileProvider);
    final hub = hubAsync.valueOrNull;

    return _SectionCard(
      title: profile.role == UserRole.driver
          ? 'Driver details'
          : 'Hub worker details',
      children: [
        _ProfileField(
          label: 'Driver ID',
          value: hub?.id ??
              (profile.driverId != null ? '${profile.driverId}' : '—'),
          icon: Icons.local_shipping_outlined,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Branch / hub',
          value: (hub?.hubId == null || hub!.hubId.isEmpty) ? '—' : hub.hubId,
          icon: Icons.warehouse_outlined,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Route code',
          value: (hub?.routeCd == null || hub!.routeCd!.isEmpty)
              ? '—'
              : hub.routeCd!,
          icon: Icons.alt_route,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Availability',
          value: hub == null
              ? '—'
              : (hub.isAvailable ? 'Available' : 'Unavailable'),
          icon: Icons.toggle_on_outlined,
        ),
        if (Env.useDriverApi && canEditZones) ...[
          const Divider(height: 24),
          _ZonesEditor(
            isEditing: isEditing,
            preferredZones: preferredZones.isNotEmpty
                ? preferredZones
                : (hub?.preferredZones ?? profile.preferredZones),
            onZonesChanged: onZonesChanged,
          ),
        ],
      ],
    );
  }
}

class _DispatcherDetails extends ConsumerWidget {
  const _DispatcherDetails({
    required this.profile,
    required this.isEditing,
    required this.preferredZones,
    required this.canEditZones,
    required this.onZonesChanged,
  });

  final UserProfile profile;
  final bool isEditing;
  final List<String> preferredZones;
  final bool canEditZones;
  final ValueChanged<List<String>> onZonesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispAsync = ref.watch(dispatcherProfileProvider);
    final disp = dispAsync.valueOrNull;

    return _SectionCard(
      title: 'Dispatcher details',
      children: [
        _ProfileField(
          label: 'Dispatcher ID',
          value: disp?.id ??
              (profile.dispatcherId != null
                  ? '${profile.dispatcherId}'
                  : '—'),
          icon: Icons.support_agent_outlined,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Code',
          value: (disp?.code == null || disp!.code!.isEmpty) ? '—' : disp.code!,
          icon: Icons.qr_code_2_outlined,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Branch',
          value: (disp?.hubId == null || disp!.hubId!.isEmpty)
              ? '—'
              : disp.hubId!,
          icon: Icons.warehouse_outlined,
        ),
        const Divider(height: 24),
        _ProfileField(
          label: 'Primary zone',
          value: disp == null ? '—' : DemoZones.labelOf(disp.zone),
          icon: Icons.map_outlined,
        ),
        if (Env.useDriverApi && canEditZones) ...[
          const Divider(height: 24),
          _ZonesEditor(
            isEditing: isEditing,
            preferredZones: preferredZones.isNotEmpty
                ? preferredZones
                : (disp?.preferredZones ?? profile.preferredZones),
            onZonesChanged: onZonesChanged,
          ),
        ],
      ],
    );
  }
}

class _ZonesEditor extends StatelessWidget {
  const _ZonesEditor({
    required this.isEditing,
    required this.preferredZones,
    required this.onZonesChanged,
  });

  final bool isEditing;
  final List<String> preferredZones;
  final ValueChanged<List<String>> onZonesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferred zones', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (isEditing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DemoZones.all.map((zone) {
              final selected = preferredZones.contains(zone);
              return FilterChip(
                label: Text(DemoZones.labelOf(zone)),
                selected: selected,
                onSelected: (_) {
                  final next = [...preferredZones];
                  if (selected) {
                    next.remove(zone);
                  } else {
                    next.add(zone);
                  }
                  onZonesChanged(next);
                },
              );
            }).toList(),
          )
        else
          Text(
            preferredZones.isEmpty
                ? '—'
                : preferredZones.map(DemoZones.labelOf).join(', '),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
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
