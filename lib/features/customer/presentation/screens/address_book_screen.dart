import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../ops_map/domain/entities/picked_location.dart';
import '../../../ops_map/presentation/screens/role_ops_map_screens.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/address_book_providers.dart';

/// Full CRUD screen for the customer's saved addresses.
class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  AddressBookKind? _filter;

  Future<void> _refresh() async {
    ref.invalidate(customerAddressBookProvider(_filter));
    ref.invalidate(customerAddressBookProvider(null));
    ref.invalidate(customerAddressBookProvider(AddressBookKind.pickup));
    ref.invalidate(customerAddressBookProvider(AddressBookKind.delivery));
    ref.invalidate(customerAddressBookProvider(AddressBookKind.both));
  }

  Future<void> _openEditor({SavedAddress? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddressEditorSheet(existing: existing),
    );
    if (saved == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Address saved' : 'Address updated'),
        ),
      );
    }
  }

  Future<void> _delete(SavedAddress address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${address.label}" from your address book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(driverApiClientProvider).deleteCustomerAddress(address.id);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Address deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Future<void> _setDefault(SavedAddress address) async {
    try {
      await ref
          .read(driverApiClientProvider)
          .updateCustomerAddress(address.id, {
            'label': address.label,
            'kind': address.kind.apiValue,
            'address': address.address,
            'contactName': address.contactName,
            'phone': address.phone,
            'city': address.city,
            'state': address.state,
            'zoneCode': address.zoneCode,
            'lat': address.lat,
            'lng': address.lng,
            'isDefault': true,
          });
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${address.label} set as default')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update default: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(customerAddressBookProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Address book'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Pickup'),
                    selected: _filter == AddressBookKind.pickup,
                    onSelected: (_) =>
                        setState(() => _filter = AddressBookKind.pickup),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Delivery'),
                    selected: _filter == AddressBookKind.delivery,
                    onSelected: (_) =>
                        setState(() => _filter = AddressBookKind.delivery),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: async.when(
                loading: () =>
                    const AppLoadingIndicator(message: 'Loading addresses...'),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      '$e\n\nIf this is new, run sql/013_mobile_address_book.sql.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No saved addresses yet',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add pickup and delivery addresses so you can reuse '
                          'them when creating shipments.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address.label,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (address.isDefault)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: const Text('Default'),
                                      avatar: Icon(
                                        Icons.star,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _openEditor(existing: address);
                                        case 'default':
                                          _setDefault(address);
                                        case 'delete':
                                          _delete(address);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      if (!address.isDefault)
                                        const PopupMenuItem(
                                          value: 'default',
                                          child: Text('Set as default'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(address.summary),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(address.kind.label),
                                  ),
                                  if (address.zoneCode != null &&
                                      address.zoneCode!.isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        DemoZones.labelOf(address.zoneCode!),
                                      ),
                                    ),
                                  if (address.contactName != null &&
                                      address.contactName!.isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(address.contactName!),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openEditor(existing: address),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _delete(address),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressEditorSheet extends ConsumerStatefulWidget {
  const _AddressEditorSheet({this.existing});

  final SavedAddress? existing;

  @override
  ConsumerState<_AddressEditorSheet> createState() =>
      _AddressEditorSheetState();
}

class _AddressEditorSheetState extends ConsumerState<_AddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late AddressBookKind _kind;
  late bool _isDefault;
  PickedLocation? _location;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? '');
    _contact = TextEditingController(text: existing?.contactName ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _kind = existing?.kind ?? AddressBookKind.both;
    _isDefault = existing?.isDefault ?? false;
    if (existing?.hasCoordinates == true) {
      _location = existing!.toPickedLocation();
    } else if (existing != null) {
      _location = PickedLocation(
        point: const LatLng(5.9804, 116.0735),
        label: existing.address,
        zoneCode: existing.zoneCode ?? DemoZones.demoOrigin,
        city: existing.city,
        state: existing.state,
        contactName: existing.contactName,
        phone: existing.phone,
      );
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _contact.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final current = _location;
    final result = await context.push<PickedLocation>(
      RoutePaths.customerPickLocation,
      extra: AddressPickArgs(
        title: _isEdit ? 'Update location' : 'Choose location',
        initialZone: current?.zoneCode,
        initialQuery: current?.label,
        initialLat: current?.point.latitude,
        initialLng: current?.point.longitude,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _location = result;
      _error = null;
      if (_label.text.trim().isEmpty) {
        _label.text = _kind == AddressBookKind.pickup
            ? 'My pickup'
            : (_kind == AddressBookKind.delivery
                  ? 'Delivery address'
                  : 'Saved address');
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final location = _location;
    if (location == null) {
      setState(() => _error = 'Choose a location on the map first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final body = {
      'label': _label.text.trim(),
      'kind': _kind.apiValue,
      'address': location.label,
      'city': location.city,
      'state': location.state,
      'zoneCode': location.zoneCode,
      'lat': location.point.latitude,
      'lng': location.point.longitude,
      'contactName': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'isDefault': _isDefault,
    };

    try {
      final api = ref.read(driverApiClientProvider);
      if (_isEdit) {
        await api.updateCustomerAddress(widget.existing!.id, body);
      } else {
        await api.createCustomerAddress(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Edit address' : 'Add address',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Home, Office, Warehouse',
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Label is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AddressBookKind>(
                value: _kind,
                decoration: const InputDecoration(
                  labelText: 'Use for',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AddressBookKind.values
                    .map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _kind = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Contact name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickOnMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _location == null
                      ? 'Choose on map'
                      : 'Change location on map',
                ),
              ),
              if (_location != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _location!.shortSummary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DemoZones.labelOf(_location!.zoneCode),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${_location!.point.latitude.toStringAsFixed(5)}, '
                        '${_location!.point.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Create address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
