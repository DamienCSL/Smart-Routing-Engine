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
        await ref
            .read(driverApiSessionProvider.notifier)
            .updateProfile(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    setState(() => _isSaving = true);

    final result = await ref
        .read(authRepositoryProvider)
        .updateProfile(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      },
      failure: (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      await ref.read(driverApiSessionProvider.notifier).signOut();
      if (mounted) context.go(RoutePaths.login);
      return;
    }
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go(RoutePaths.login);
  }

  Future<void> _openAddressBook() async {
    await context.push(RoutePaths.customerAddressBook);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit profile' : 'Profile'),
        actions: [
          if (profileAsync.valueOrNull != null && !_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Loading profile...'),
        error: (error, _) => _ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }

          if (!_isEditing &&
              (_nameController.text.isEmpty ||
                  _nameController.text != profile.fullName)) {
            _populateFields(profile);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHero(profile: profile),
                        const SizedBox(height: 20),
                        if (!_isEditing) ...[
                          _QuickActions(
                            profile: profile,
                            onManageAddresses:
                                Env.useDriverApi &&
                                    !Env.isSupabaseConfigured &&
                                    profile.role == UserRole.customer
                                ? _openAddressBook
                                : null,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _SectionLabel(label: 'Personal information'),
                        _InfoCard(
                          children: [
                            if (_isEditing) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icon(Icons.person_outlined),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Name is required'
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone number',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: profile.email,
                                subtitle: 'Used to sign in — cannot be changed',
                                isLast: true,
                              ),
                            ] else ...[
                              _InfoRow(
                                icon: Icons.person_outlined,
                                label: 'Full name',
                                value: profile.fullName,
                              ),
                              _InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value:
                                    (profile.phone == null ||
                                        profile.phone!.isEmpty)
                                    ? 'Not set'
                                    : profile.phone!,
                                muted:
                                    profile.phone == null ||
                                    profile.phone!.isEmpty,
                              ),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: profile.email,
                              ),
                              _InfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Member since',
                                value: DateFormat.yMMMMd().format(
                                  profile.createdAt,
                                ),
                                isLast: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        _RoleDetailsSection(
                          profile: profile,
                          isEditing: _isEditing,
                          preferredZones: _preferredZones,
                          canEditZones: _canEditZones,
                          onZonesChanged: (zones) =>
                              setState(() => _preferredZones = zones),
                        ),
                        if (!_isEditing) ...[
                          const SizedBox(height: 28),
                          _SectionLabel(label: 'Session'),
                          _InfoCard(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign out'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: scheme.error,
                                    side: BorderSide(
                                      color: scheme.error.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_isEditing) _EditBar(
                isSaving: _isSaving,
                onCancel: () {
                  _populateFields(profile);
                  setState(() => _isEditing = false);
                },
                onSave: _saveProfile,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initial = profile.fullName.trim().isNotEmpty
        ? profile.fullName.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.badge_outlined,
                label: profile.role.label,
              ),
              _HeroChip(
                icon: profile.isActive
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                label: profile.isActive ? 'Active' : 'Inactive',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile, this.onManageAddresses});

  final UserProfile profile;
  final VoidCallback? onManageAddresses;

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionItem>[
      if (onManageAddresses != null)
        _ActionItem(
          icon: Icons.menu_book_outlined,
          label: 'Addresses',
          onTap: onManageAddresses!,
        ),
      if (profile.role == UserRole.customer) ...[
        _ActionItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'E-Wallet',
          onTap: () => context.push(RoutePaths.customerWallet),
        ),
        _ActionItem(
          icon: Icons.card_giftcard_outlined,
          label: 'Loyalty',
          onTap: () => context.push(RoutePaths.customerLoyalty),
        ),
      ],
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Shortcuts'),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _ActionTile(item: actions[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            children: [
              Icon(item.icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
  });

  final UserProfile profile;
  final bool isEditing;
  final List<String> preferredZones;
  final bool canEditZones;
  final ValueChanged<List<String>> onZonesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (profile.role) {
      case UserRole.customer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'Customer account'),
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.pin_outlined,
                  label: 'Account number',
                  value: (profile.accountNo == null || profile.accountNo!.isEmpty)
                      ? 'Not assigned'
                      : profile.accountNo!,
                  muted:
                      profile.accountNo == null || profile.accountNo!.isEmpty,
                  isLast: true,
                ),
              ],
            ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'Drop point'),
            _InfoCard(
              children: [
                const _InfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Assignment',
                  value: 'Drop point operator',
                ),
                _InfoRow(
                  icon: Icons.fingerprint,
                  label: 'User ID',
                  value: profile.id,
                  isLast: true,
                ),
              ],
            ),
          ],
        );
      case UserRole.storekeeper:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'Storekeeper'),
            _InfoCard(
              children: [
                const _InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Assignment',
                  value: 'Hub storekeeper',
                ),
                _InfoRow(
                  icon: Icons.fingerprint,
                  label: 'User ID',
                  value: profile.id,
                  isLast: true,
                ),
              ],
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
    final title = profile.role == UserRole.driver
        ? 'Driver details'
        : 'Hub worker details';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: title),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.local_shipping_outlined,
              label: 'Driver ID',
              value:
                  hub?.id ??
                  (profile.driverId != null ? '${profile.driverId}' : '—'),
            ),
            _InfoRow(
              icon: Icons.warehouse_outlined,
              label: 'Branch / hub',
              value: (hub?.hubId == null || hub!.hubId.isEmpty)
                  ? '—'
                  : hub.hubId,
            ),
            _InfoRow(
              icon: Icons.alt_route,
              label: 'Route code',
              value: (hub?.routeCd == null || hub!.routeCd!.isEmpty)
                  ? '—'
                  : hub.routeCd!,
            ),
            _InfoRow(
              icon: Icons.toggle_on_outlined,
              label: 'Availability',
              value: hub == null
                  ? '—'
                  : (hub.isAvailable ? 'Available' : 'Unavailable'),
              isLast: !(Env.useDriverApi && canEditZones),
            ),
            if (Env.useDriverApi && canEditZones)
              _ZonesEditor(
                isEditing: isEditing,
                preferredZones: preferredZones.isNotEmpty
                    ? preferredZones
                    : (hub?.preferredZones ?? profile.preferredZones),
                onZonesChanged: onZonesChanged,
              ),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Dispatcher details'),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.support_agent_outlined,
              label: 'Dispatcher ID',
              value:
                  disp?.id ??
                  (profile.dispatcherId != null
                      ? '${profile.dispatcherId}'
                      : '—'),
            ),
            _InfoRow(
              icon: Icons.qr_code_2_outlined,
              label: 'Code',
              value: (disp?.code == null || disp!.code!.isEmpty)
                  ? '—'
                  : disp.code!,
            ),
            _InfoRow(
              icon: Icons.warehouse_outlined,
              label: 'Branch',
              value: (disp?.hubId == null || disp!.hubId!.isEmpty)
                  ? '—'
                  : disp.hubId!,
            ),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Primary zone',
              value: disp == null ? '—' : DemoZones.labelOf(disp.zone),
              isLast: !(Env.useDriverApi && canEditZones),
            ),
            if (Env.useDriverApi && canEditZones)
              _ZonesEditor(
                isEditing: isEditing,
                preferredZones: preferredZones.isNotEmpty
                    ? preferredZones
                    : (disp?.preferredZones ?? profile.preferredZones),
                onZonesChanged: onZonesChanged,
              ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred zones',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
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
          else if (preferredZones.isEmpty)
            Text(
              'None selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preferredZones
                  .map(
                    (zone) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(DemoZones.labelOf(zone)),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.muted = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool muted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 64,
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
      ],
    );
  }
}

class _EditBar extends StatelessWidget {
  const _EditBar({
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Could not load profile', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
