import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_client.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../providers/hub_worker_providers.dart';

/// Full E2E demo: create CN → assign driver → scan hops → customer track.
class DemoOpsDeskScreen extends ConsumerStatefulWidget {
  const DemoOpsDeskScreen({super.key});

  @override
  ConsumerState<DemoOpsDeskScreen> createState() => _DemoOpsDeskScreenState();
}

class _DemoOpsDeskScreenState extends ConsumerState<DemoOpsDeskScreen> {
  final _recipient = TextEditingController(text: 'Demo Buyer');
  final _address = TextEditingController(text: 'Likas, Kota Kinabalu');
  final _origin = TextEditingController(text: 'BKI');
  final _dest = TextEditingController(text: 'BKI');

  String? _cnNo;
  String? _customerLabel;
  List<String> _nextScans = const [];
  String? _assignedDriverName;
  String _jobType = 'delivery';
  String? _error;
  String? _message;
  bool _busy = false;
  bool _assigned = false;

  static const _pipelineHints = [
    IposbStatusMap.pickedUp,
    IposbStatusMap.arrivedHub,
    IposbStatusMap.sorted,
    IposbStatusMap.storekeeper,
    IposbStatusMap.outForDelivery,
    IposbStatusMap.delivered,
  ];

  @override
  void dispose() {
    _recipient.dispose();
    _address.dispose();
    _origin.dispose();
    _dest.dispose();
    super.dispose();
  }

  DriverApiClient get _api => ref.read(driverApiClientProvider);

  Future<void> _createOrder() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _assigned = false;
      _assignedDriverName = null;
    });
    try {
      final json = await _api.postDispatchJson(
        '/demo/orders',
        body: {
          'recipientName': _recipient.text.trim(),
          'address': _address.text.trim(),
          'origin': _origin.text.trim(),
          'dest': _dest.text.trim(),
        },
      );
      final cn = json['cnNo']?.toString();
      if (cn == null || cn.isEmpty) {
        throw Exception('No CN returned');
      }
      setState(() {
        _cnNo = cn;
        _customerLabel = json['customerLabel']?.toString();
        _message = 'Created CN $cn — next: assign to driver';
      });
      await _refreshNext(cn);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignToMe() async {
    final cn = _cnNo;
    if (cn == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final json = await _api.postDispatchJson(
        '/dispatch/assign',
        body: {
          'cnNo': cn,
          'firebaseUid': Env.demoDriverUid,
          'jobType': _jobType,
        },
      );
      ref.invalidate(hubPickupTasksProvider);
      ref.invalidate(hubDeliveryTasksProvider);
      setState(() {
        _assigned = true;
        _assignedDriverName = 'You (${Env.demoDriverUid})';
        _message =
            'Assigned to driver · jobType=${json['jobType'] ?? _jobType}';
        _customerLabel = json['customerLabel']?.toString() ?? _customerLabel;
      });
      await _refreshNext(cn);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshNext(String cn) async {
    try {
      final track = await _api.getPublicJson('/tracking/$cn');
      setState(() {
        _customerLabel = track['customerLabel']?.toString();
        _nextScans = (track['nextScans'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
      });
    } catch (_) {
      // keep previous nextScans
    }
  }

  /// Driver-owned scan (requires assignment). Preferred for real flow.
  Future<void> _driverScan(String status) async {
    final cn = _cnNo;
    if (cn == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (!_assigned) {
        throw Exception('Assign the CN to a driver first');
      }
      final json = await _api.postJson(
        '/driver/jobs/$cn/scan',
        body: {
          'status': status,
          'note': 'Driver scan via demo desk',
          'locId': IposbStatusMap.defaultLocForStatus(status),
        },
      );
      ref.invalidate(hubPickupTasksProvider);
      ref.invalidate(hubDeliveryTasksProvider);
      setState(() {
        _message =
            'Driver: ${IposbStatusMap.labelOf(status)} → ${json['customerLabel'] ?? ''}';
        _customerLabel = json['customerLabel']?.toString();
        _nextScans = (json['nextScans'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
      });
      await _refreshNext(cn);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ops/hub scan without driver ownership (warehouse hops).
  Future<void> _opsScan(String status) async {
    final cn = _cnNo;
    if (cn == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final json = await _api.postDispatchJson(
        '/ops/scan',
        body: {
          'cnNo': cn,
          'status': status,
          'note': 'Ops desk hop',
          'actorName': 'flutter ops',
          'locId': IposbStatusMap.defaultLocForStatus(status),
        },
      );
      ref.invalidate(hubPickupTasksProvider);
      ref.invalidate(hubDeliveryTasksProvider);
      setState(() {
        _message =
            'Ops: ${IposbStatusMap.labelOf(status)} → ${json['customerLabel'] ?? ''}';
        _customerLabel = json['customerLabel']?.toString();
        _nextScans = (json['nextScans'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
      });
      await _refreshNext(cn);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cn = _cnNo;
    final scanCodes =
        _nextScans.isNotEmpty ? _nextScans : (_assigned ? _pipelineHints : const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo desk'),
        actions: [
          if (cn != null)
            IconButton(
              tooltip: 'Track as customer',
              icon: const Icon(Icons.travel_explore),
              onPressed: () => context.push('${RoutePaths.trackOrder}?cn=$cn'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Complete flow against PHP API (${Env.driverApiUrl}):\n'
            '1) Create order  2) Assign driver  3) Scan hops  4) Track as customer',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text('1. Customer creates order', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _recipient,
            decoration: const InputDecoration(
              labelText: 'Recipient',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _origin,
                  decoration: const InputDecoration(
                    labelText: 'Origin',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dest,
                  decoration: const InputDecoration(
                    labelText: 'Dest',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _createOrder,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Create demo CN'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: theme.colorScheme.primary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (cn != null) ...[
            const SizedBox(height: 24),
            Text('2. Label / CN', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: QrImageView(
                data: cn,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CN $cn', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: 'Copy CN',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cn));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CN copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
            if (_customerLabel != null)
              Center(
                child: Text(
                  'Customer sees: $_customerLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('3. Dispatch — assign driver', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _jobType,
              decoration: const InputDecoration(
                labelText: 'Job type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                DropdownMenuItem(value: 'pipeline', child: Text('Pipeline')),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => _jobType = v);
                    },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _assignToMe,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(
                _assigned
                    ? 'Re-assign to me (${Env.demoDriverUid})'
                    : 'Assign to me (${Env.demoDriverUid})',
              ),
            ),
            if (_assignedDriverName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Assigned: $_assignedDriverName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(hubPickupTasksProvider);
                ref.invalidate(hubDeliveryTasksProvider);
                context.go(RoutePaths.hubWorkerHome);
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Open my Hub Tasks'),
            ),
            const SizedBox(height: 20),
            Text('4. Scan hops', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _assigned
                  ? (_nextScans.isEmpty
                      ? 'Use driver scans in order: PKU → ARR → SRT → SHB → OFD → POD'
                      : 'Allowed next (driver): ${_nextScans.join(', ')}')
                  : 'Assign a driver first for the real flow, or use Ops hops below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_assigned)
              ...scanCodes.map(
                (code) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : () => _driverScan(code),
                    child: Text('Driver: ${IposbStatusMap.labelOf(code)}'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Ops / hub hops (no driver ownership)'),
              children: [
                ...(_nextScans.isNotEmpty ? _nextScans : _pipelineHints).map(
                  (code) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _opsScan(code),
                      child: Text('Ops: ${IposbStatusMap.labelOf(code)}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('${RoutePaths.trackOrder}?cn=$cn'),
              icon: const Icon(Icons.travel_explore),
              label: const Text('5. Open customer Track view'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.hubWorkerScan),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Open camera Scan CN'),
            ),
          ],
        ],
      ),
    );
  }
}
