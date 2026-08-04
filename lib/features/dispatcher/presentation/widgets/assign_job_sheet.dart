import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_zones.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../domain/entities/zone_driver_summary.dart';
import '../providers/dispatcher_providers.dart';

/// Bottom sheet: pick job type + recommended driver → assign.
Future<bool?> showAssignJobSheet(
  BuildContext context, {
  required Shipment shipment,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AssignJobSheet(shipment: shipment),
  );
}

class AssignJobSheet extends ConsumerStatefulWidget {
  const AssignJobSheet({super.key, required this.shipment});

  final Shipment shipment;

  @override
  ConsumerState<AssignJobSheet> createState() => _AssignJobSheetState();
}

class _AssignJobSheetState extends ConsumerState<AssignJobSheet> {
  String _jobType = 'delivery';
  bool _loading = true;
  bool _assigning = false;
  String? _error;
  DispatchSuggestResult? _suggest;
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    final origin = widget.shipment.originZone.toUpperCase();
    final dest = widget.shipment.destinationZone.toUpperCase();
    if (origin.isNotEmpty && dest.isNotEmpty && origin == dest) {
      _jobType = 'pickup';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggest());
  }

  Future<void> _loadSuggest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(dispatcherApiDataSourceProvider)
          .suggestForJob(
            cnNo: widget.shipment.trackingNumber,
            jobType: _jobType,
          );
      if (!mounted) return;
      ZoneDriverSummary? first;
      for (final d in result.drivers) {
        final uid = d.firebaseUid;
        if (uid != null && uid.isNotEmpty) {
          first = d;
          break;
        }
      }
      setState(() {
        _suggest = result;
        _selectedUid = first?.firebaseUid;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _assign() async {
    final uid = _selectedUid;
    if (uid == null || uid.isEmpty) {
      setState(() => _error = 'Select a driver with a mobile login.');
      return;
    }
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      await ref.read(dispatcherApiDataSourceProvider).assignJob(
            cnNo: widget.shipment.trackingNumber,
            firebaseUid: uid,
            jobType: _jobType,
          );
      if (!mounted) return;
      await Future.wait([
        refreshAndWait(ref, zoneShipmentsProvider.future),
        refreshAndWait(ref, zoneDriversProvider.future),
      ]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _assigning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shipment = widget.shipment;
    final route = _suggest?.route;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.38;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Assign ${shipment.trackingNumber}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${DemoZones.labelOf(shipment.originZone)} → '
            '${DemoZones.labelOf(shipment.destinationZone)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if ((shipment.packageDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shipment.packageDescription!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text('Job type', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'pickup',
                label: Text('Pickup'),
                icon: Icon(Icons.upload_outlined),
              ),
              ButtonSegment(
                value: 'delivery',
                label: Text('Delivery'),
                icon: Icon(Icons.download_outlined),
              ),
            ],
            selected: {_jobType},
            onSelectionChanged: _assigning
                ? null
                : (s) {
                    setState(() => _jobType = s.first);
                    _loadSuggest();
                  },
          ),
          const SizedBox(height: 16),
          if (route != null) ...[
            Card(
              margin: EdgeInsets.zero,
              color: route.matched
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      route.matched ? Icons.alt_route : Icons.info_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route suggestion',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(route.summary, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Recommended drivers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _suggest == null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else if ((_suggest?.drivers ?? const []).isEmpty)
            const Text('No drivers found. Check t_driver + preferred zones.')
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggest!.drivers.length,
                itemBuilder: (context, i) {
                  final d = _suggest!.drivers[i];
                  final uid = d.firebaseUid ?? '';
                  final enabled = uid.isNotEmpty;
                  final selected = enabled && uid == _selectedUid;
                  final badges = <String>[];
                  if (d.zoneMatch) badges.add('zone');
                  if (d.routeMatch) badges.add('route');
                  if (d.isAvailable) badges.add('available');
                  if (d.matchScore > 0) badges.add('score ${d.matchScore}');

                  return ListTile(
                    enabled: enabled && !_assigning,
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : d.zoneMatch
                              ? Icons.star_outline
                              : Icons.person_outline,
                    ),
                    title: Text(
                      d.driverName?.isNotEmpty == true
                          ? d.driverName!
                          : 'Driver ${d.id}',
                    ),
                    subtitle: Text(
                      [
                        if (d.vehicleType.isNotEmpty) d.vehicleType,
                        if (d.preferredZones.isNotEmpty)
                          d.preferredZones.join(','),
                        if (badges.isNotEmpty) badges.join(' · '),
                        if (!enabled) 'no mobile login',
                      ].where((e) => e.isNotEmpty).join(' · '),
                    ),
                    onTap: (!enabled || _assigning)
                        ? null
                        : () => setState(() => _selectedUid = uid),
                  );
                },
              ),
            ),
          if (_error != null && _suggest != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _assigning || _loading ? null : _assign,
            icon: _assigning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: Text(_assigning ? 'Assigning…' : 'Confirm assign'),
          ),
        ],
      ),
    );
  }
}
