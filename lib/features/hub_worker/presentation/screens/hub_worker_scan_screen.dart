import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
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

  Future<void> _loadCn(String raw) async {
    final cn = raw.trim();
    if (cn.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _cnNo = cn;
    });
    try {
      final api = ref.read(driverApiClientProvider);
      try {
        final json = await api.getJson('/driver/jobs/$cn');
        final job = json['job'] as Map<String, dynamic>?;
        setState(() {
          _nextScans = (job?['nextScans'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
          _customerLabel = job?['customerLabel']?.toString();
        });
      } catch (_) {
        // Public tracking fallback when job is not assigned to this driver yet.
        final track = await api.getPublicJson('/tracking/$cn');
        setState(() {
          _nextScans = (track['nextScans'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
          _customerLabel = track['customerLabel']?.toString();
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      ref.invalidate(hubPickupTasksProvider);
      ref.invalidate(hubDeliveryTasksProvider);
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
                    _loadCn(value).whenComplete(() {
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
                onPressed:
                    _busy ? null : () => _loadCn(_manualController.text),
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
