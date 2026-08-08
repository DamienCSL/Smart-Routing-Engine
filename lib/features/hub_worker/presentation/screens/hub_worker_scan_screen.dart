import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../core/utils/shipment_qr_payload.dart';
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
      // This endpoint also verifies that the signed-in staff member is
      // assigned to the shipment before any transition is offered.
      final json = await api.getJson('/driver/jobs/$cn');
      final job = json['job'] as Map<String, dynamic>?;
      loadedNextScans = (job?['nextScans'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (!mounted) return;
      setState(() {
        _nextScans = loadedNextScans;
        _customerLabel = job?['customerLabel']?.toString();
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
      final status = statuses.single;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update shipment status?'),
          content: Text(
            'Move CN $_cnNo to “${IposbStatusMap.labelOf(status)}”?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update status'),
            ),
          ],
        ),
      );
      if (confirmed == true) selected = status;
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
      await api.postJson(
        '/driver/jobs/$cn/scan',
        body: {
          'status': status,
          'note': 'Scanned via app',
          'locId': IposbStatusMap.defaultLocForStatus(status),
        },
      );
      await Future.wait([
        refreshAndWait(ref, hubPickupTasksProvider.future),
        refreshAndWait(ref, hubDeliveryTasksProvider.future),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${IposbStatusMap.labelOf(status)} · CN $cn')),
      );
      await _loadCn(cn);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanner = _scannerController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan CN'),
        actions: [
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
