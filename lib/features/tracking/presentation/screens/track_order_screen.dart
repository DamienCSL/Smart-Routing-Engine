import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/driver_api_client.dart';
import '../../../../core/network/driver_api_providers.dart';

/// Customer-facing order tracking inside the mobile app (no PHP needed).
class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key, this.initialCn});

  final String? initialCn;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  late final TextEditingController _cnController;
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cnController = TextEditingController(text: widget.initialCn ?? '');
    if ((widget.initialCn ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _track());
    }
  }

  @override
  void dispose() {
    _cnController.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    final cn = _cnController.text.trim();
    if (cn.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final DriverApiClient api = ref.read(driverApiClientProvider);
      final json = await api.getPublicJson('/tracking/$cn');
      if (!mounted) return;
      setState(() => _data = json);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeline = (_data?['timeline'] as List<dynamic>?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Track order')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Enter your consignment / AWB number',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _cnController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 20091031',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _track(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _track,
                child: const Text('Track'),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_data != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STATUS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _data!['customerLabel']?.toString() ?? '',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CN ${_data!['cnNo']}'
                      '${_data!['destination'] != null && _data!['destination'].toString().isNotEmpty ? ' · To ${_data!['destination']}' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Timeline', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (timeline.isEmpty)
              const Text('No scan events yet.')
            else
              ...timeline.map((raw) {
                final row = raw as Map<String, dynamic>;
                final label = row['customerLabel']?.toString() ??
                    row['statusCode']?.toString() ??
                    '';
                final at = row['at']?.toString() ?? '';
                final loc = row['location']?.toString() ?? '';
                final note = row['note']?.toString() ?? '';
                // Location is already in the detailed title; only show time (+ note if unique).
                final subtitleParts = <String>[
                  if (at.isNotEmpty) at,
                  if (note.isNotEmpty &&
                      !label.toLowerCase().contains(note.toLowerCase()) &&
                      note.toUpperCase() != loc.toUpperCase())
                    note,
                ];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: subtitleParts.isEmpty
                      ? null
                      : Text(subtitleParts.join(' · ')),
                );
              }),
          ],
        ],
      ),
    );
  }
}
