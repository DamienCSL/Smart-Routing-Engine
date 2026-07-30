import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../ops_map/domain/entities/picked_location.dart';
import '../../../ops_map/presentation/screens/role_ops_map_screens.dart';
import '../../../shipment/domain/entities/create_shipment_request.dart';
import '../../../shipment/presentation/viewmodels/create_shipment_viewmodel.dart';

class CreateShipmentScreen extends ConsumerStatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  ConsumerState<CreateShipmentScreen> createState() =>
      _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends ConsumerState<CreateShipmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _description = TextEditingController();
  final _weight = TextEditingController(text: '1.0');
  final _count = TextEditingController(text: '1');

  PickedLocation? _origin;
  PickedLocation? _destination;
  String? _locationError;

  @override
  void dispose() {
    _description.dispose();
    _weight.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _pickLocation({required bool isOrigin}) async {
    final current = isOrigin ? _origin : _destination;
    final result = await context.push<PickedLocation>(
      RoutePaths.customerPickLocation,
      extra: AddressPickArgs(
        title: isOrigin ? 'Pickup location' : 'Delivery location',
        initialZone: isOrigin
            ? (current?.zoneCode ?? DemoZones.demoOrigin)
            : (current?.zoneCode ?? DemoZones.demoDestination),
        initialQuery: current?.label,
        initialLat: current?.point.latitude,
        initialLng: current?.point.longitude,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _locationError = null;
      if (isOrigin) {
        _origin = result;
      } else {
        _destination = result;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _locationError = null);

    if (_origin == null || _destination == null) {
      setState(() {
        _locationError =
            'Pin both pickup and delivery on the map before creating.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final origin = _origin!;
    final destination = _destination!;

    final request = CreateShipmentRequest(
      originAddress: origin.label,
      originCity: origin.city?.trim().isNotEmpty == true
          ? origin.city!.trim()
          : DemoZones.labelOf(origin.zoneCode),
      originProvince: origin.state,
      originZone: origin.zoneCode,
      originLat: origin.point.latitude,
      originLng: origin.point.longitude,
      destinationAddress: destination.label,
      destinationCity: destination.city?.trim().isNotEmpty == true
          ? destination.city!.trim()
          : DemoZones.labelOf(destination.zoneCode),
      destinationProvince: destination.state,
      destinationZone: destination.zoneCode,
      destinationLat: destination.point.latitude,
      destinationLng: destination.point.longitude,
      packageDescription: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      weightKg: double.parse(_weight.text.trim()),
      packageCount: int.parse(_count.text.trim()),
    );

    final shipment =
        await ref.read(createShipmentViewModelProvider.notifier).submit(request);

    if (!mounted) return;

    if (shipment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shipment.isAssigned
                ? 'Assigned ${shipment.trackingNumber} · ETA ready'
                : 'Created ${shipment.trackingNumber}',
          ),
        ),
      );
      context.go(RoutePaths.customerShipmentDetail(shipment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createShipmentViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Shipment')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_locationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _locationError!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Pickup (Origin)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search a place, then move the pin for accuracy. Zone is set from the pin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _LocationPickCard(
                title: 'Pickup on map',
                emptyHint: 'Tap to search & pin pickup in Sabah',
                location: _origin,
                enabled: !state.isLoading,
                onPick: () => _pickLocation(isOrigin: true),
              ),
              const SizedBox(height: 24),
              Text(
                'Delivery (Destination)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Same flow for the delivery stop — search first, refine with the pin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _LocationPickCard(
                title: 'Delivery on map',
                emptyHint: 'Tap to search & pin delivery in Sabah',
                location: _destination,
                enabled: !state.isLoading,
                onPick: () => _pickLocation(isOrigin: false),
              ),
              const SizedBox(height: 24),
              Text(
                'Package',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid weight';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _count,
                      decoration: const InputDecoration(
                        labelText: 'Packages',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid count';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                Env.useDriverApi
                    ? 'Creates an IPOSB consignment (Pending Pickup). '
                        'A dispatcher assigns a driver next.'
                    : 'Tip: pin Kota Kinabalu Metro → Sandakan so the Assignment '
                        'Engine can match the Sabah demo routing rule and staff seed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Shipment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPickCard extends StatelessWidget {
  const _LocationPickCard({
    required this.title,
    required this.emptyHint,
    required this.location,
    required this.enabled,
    required this.onPick,
  });

  final String title;
  final String emptyHint;
  final PickedLocation? location;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = location != null;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPick : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                picked ? Icons.place : Icons.add_location_alt_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: picked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location!.shortSummary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  DemoZones.labelOf(location!.zoneCode),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '${location!.point.latitude.toStringAsFixed(4)}, '
                                  '${location!.point.longitude.toStringAsFixed(4)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to adjust on map',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emptyHint,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
