import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../core/utils/shipment_qr_payload.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../dispatcher/presentation/providers/dispatcher_providers.dart';
import '../providers/hub_worker_providers.dart';

/// Scan CN barcode/QR, then post the next allowed SOP scan.
class HubWorkerScanScreen extends ConsumerStatefulWidget {
  const HubWorkerScanScreen({super.key});

  @override
  ConsumerState<HubWorkerScanScreen> createState() =>
      _HubWorkerScanScreenState();
}

class _HubWorkerScanScreenState extends ConsumerState<HubWorkerScanScreen> {
  final _manualController = TextEditingController();
  MobileScannerController? _scannerController;

  String? _cnNo;
  List<String> _nextScans = const [];
  String? _customerLabel;
  String? _originLoc;
  String? _destinationLoc;
  String? _error;
  bool _busy = false;
  bool _handledCode = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadCn(String raw, {bool promptForNextStatus = false}) async {
    final cn = ShipmentQrPayload.decode(raw);
    if (cn.isEmpty) return;
    List<String> loadedNextScans = const [];
    setState(() {
      _busy = true;
      _error = null;
      _cnNo = cn;
    });
    try {
      final api = ref.read(driverApiClientProvider);
      final isDispatcher =
          ref.read(driverApiSessionProvider)?.role == UserRole.dispatcher;
      Map<String, dynamic> data;
      if (isDispatcher) {
        // Dispatchers may process any shipment through the guarded ops route.
        data = await api.getPublicJson('/tracking/$cn');
      } else {
        // This also verifies that the driver is assigned to the shipment.
        final json = await api.getJson('/driver/jobs/$cn');
        data = json['job'] is Map
            ? Map<String, dynamic>.from(json['job'] as Map)
            : <String, dynamic>{};
      }
      loadedNextScans = (data['nextScans'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (!mounted) return;
      setState(() {
        _nextScans = loadedNextScans;
        _customerLabel = data['customerLabel']?.toString();
        _originLoc = (data['originLoc'] ?? data['origin'])?.toString();
        _destinationLoc = (data['destLoc'] ?? data['destination'])?.toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && promptForNextStatus && _error == null) {
      await _promptForNextStatus(loadedNextScans);
    }
  }

  Future<void> _promptForNextStatus(List<String> statuses) async {
    if (statuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This shipment has no further status updates.'),
        ),
      );
      return;
    }

    String? selected;
    if (statuses.length == 1) {
      // The transition is unambiguous, so scanning applies it immediately.
      selected = statuses.single;
    } else {
      selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Choose the next shipment status',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final status in statuses)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(IposbStatusMap.labelOf(status)),
                  onTap: () => Navigator.pop(sheetContext, status),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    if (selected != null && mounted) await _postScan(selected);
  }

  Future<void> _postScan(String status) async {
    final cn = _cnNo;
    if (cn == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(driverApiClientProvider);
      final isDispatcher =
          ref.read(driverApiSessionProvider)?.role == UserRole.dispatcher;
      final locId = IposbStatusMap.defaultLocForStatus(
        status,
        origin: _originLoc,
        dest: _destinationLoc,
      );
      if (isDispatcher) {
        await api.postJson(
          '/ops/scan',
          body: {
            'cnNo': cn,
            'status': status,
            'note': 'Scanned by dispatcher via mobile app',
            'locId': locId,
          },
        );
        ref.invalidate(zoneShipmentsProvider);
        ref.invalidate(zoneDriversProvider);
      } else {
        await api.postJson(
          '/driver/jobs/$cn/scan',
          body: {'status': status, 'note': 'Scanned via app', 'locId': locId},
        );
        await Future.wait([
          refreshAndWait(ref, hubPickupTasksProvider.future),
          refreshAndWait(ref, hubDeliveryTasksProvider.future),
        ]);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${IposbStatusMap.labelOf(status)} · CN $cn')),
      );
      await _loadCn(cn);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanner = _scannerController;
    final isDispatcher =
        ref.watch(driverApiSessionProvider)?.role == UserRole.dispatcher;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDispatcher ? 'Dispatcher Scan' : 'Driver Scan'),
        actions: [
          if (!isDispatcher)
            IconButton(
              tooltip: 'Open job',
              onPressed: _cnNo == null
                  ? null
                  : () => context.push(RoutePaths.hubWorkerTaskDetail(_cnNo!)),
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scanner != null)
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: scanner,
                  onDetect: (capture) {
                    if (_handledCode || _busy) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value == null || value.isEmpty) return;
                    _handledCode = true;
                    _loadCn(value, promptForNextStatus: true).whenComplete(() {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) _handledCode = false;
                      });
                    });
                  },
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Camera scan works on Android/iOS. On web, enter the CN from the QR label.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Scan a shipment QR to apply its next allowed status '
                      'automatically. If the workflow branches, choose the '
                      'correct next status.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Or enter CN manually', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualController,
                  decoration: const InputDecoration(
                    hintText: 'CN / AWB',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _loadCn,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 48),
                ),
                onPressed: _busy ? null : () => _loadCn(_manualController.text),
                child: const Text('Load'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_cnNo != null) ...[
            const SizedBox(height: 20),
            Text('CN $_cnNo', style: theme.textTheme.titleMedium),
            if (_customerLabel != null)
              Text(
                'Customer sees: $_customerLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Text('Next allowed scans', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_nextScans.isEmpty)
              const Text('No further scans (terminal or unknown).')
            else
              ..._nextScans.map(
                (code) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : () => _postScan(code),
                    child: Text(IposbStatusMap.labelOf(code)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
