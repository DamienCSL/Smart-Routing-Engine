import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../ops_map/domain/entities/picked_location.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/address_book_providers.dart';

/// Bottom sheet: pick a saved address for pickup or delivery.
Future<PickedLocation?> showAddressBookPicker({
  required BuildContext context,
  required WidgetRef ref,
  required AddressBookKind kind,
}) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AddressBookSheet(kind: kind),
  );
}

/// Prompt to save a newly picked map location into the address book.
Future<void> promptSaveToAddressBook({
  required BuildContext context,
  required WidgetRef ref,
  required PickedLocation location,
  required AddressBookKind kind,
}) async {
  final labelController = TextEditingController(
    text: kind == AddressBookKind.pickup ? 'My pickup' : 'Delivery address',
  );
  final contactController = TextEditingController(
    text: location.contactName ?? '',
  );
  final phoneController = TextEditingController(text: location.phone ?? '');

  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save to address book?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.shortSummary,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Home, Office',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            if (kind != AddressBookKind.pickup) ...[
              const SizedBox(height: 8),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact name (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (save != true || !context.mounted) {
    labelController.dispose();
    contactController.dispose();
    phoneController.dispose();
    return;
  }

  try {
    final api = ref.read(driverApiClientProvider);
    await api.createCustomerAddress({
      'label': labelController.text.trim().isEmpty
          ? (kind == AddressBookKind.pickup ? 'Pickup' : 'Delivery')
          : labelController.text.trim(),
      'kind': kind.apiValue,
      'address': location.label,
      'city': location.city,
      'state': location.state,
      'zoneCode': location.zoneCode,
      'lat': location.point.latitude,
      'lng': location.point.longitude,
      if (contactController.text.trim().isNotEmpty)
        'contactName': contactController.text.trim(),
      if (phoneController.text.trim().isNotEmpty)
        'phone': phoneController.text.trim(),
    });
    ref.invalidate(customerAddressBookProvider(kind));
    ref.invalidate(customerAddressBookProvider(null));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to address book')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save address: $e')));
    }
  } finally {
    labelController.dispose();
    contactController.dispose();
    phoneController.dispose();
  }
}

class _AddressBookSheet extends ConsumerWidget {
  const _AddressBookSheet({required this.kind});

  final AddressBookKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(customerAddressBookProvider(kind));
    final height = MediaQuery.sizeOf(context).height * 0.65;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kind == AddressBookKind.pickup
                        ? 'Saved pickup addresses'
                        : kind == AddressBookKind.delivery
                        ? 'Saved delivery addresses'
                        : 'Address book',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.customerAddressBook);
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not load address book.\n$e\n\n'
                  'If this is new, run sql/013_mobile_address_book.sql on MySQL.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              data: (addresses) {
                if (addresses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No saved addresses yet.\n'
                        'Tap Manage to add one, or pin a location on the map.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final a = addresses[i];
                    return ListTile(
                      leading: Icon(
                        kind == AddressBookKind.pickup
                            ? Icons.home_outlined
                            : kind == AddressBookKind.delivery
                            ? Icons.location_on_outlined
                            : Icons.menu_book_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        a.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          a.summary,
                          if (a.contactName != null &&
                              a.contactName!.isNotEmpty)
                            a.contactName!,
                          if (a.zoneCode != null && a.zoneCode!.isNotEmpty)
                            DemoZones.labelOf(a.zoneCode!),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete address?'),
                              content: Text(
                                'Remove "${a.label}" from your book?',
                              ),
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
                          if (ok != true) return;
                          try {
                            await ref
                                .read(driverApiClientProvider)
                                .deleteCustomerAddress(a.id);
                            ref.invalidate(customerAddressBookProvider(kind));
                            ref.invalidate(customerAddressBookProvider(null));
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                      ),
                      onTap: () {
                        final picked = a.toPickedLocation();
                        if (picked == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This address has no map pin. Pick on map instead.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, picked);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
