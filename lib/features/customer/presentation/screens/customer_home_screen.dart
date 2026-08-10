import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../loyalty/domain/entities/loyalty_account.dart';
import '../../../loyalty/presentation/providers/loyalty_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/shipment_list_tile.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final shipmentsAsync = ref.watch(customerShipmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPOSB'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await refreshAndWait(ref, customerShipmentsProvider.future);
            },
          ),
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.customerCreateShipment),
        icon: const Icon(Icons.add),
        label: const Text('New Shipment'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              context.push(RoutePaths.trackOrder);
            case 2:
              context.push(RoutePaths.notifications);
            case 3:
              context.push(RoutePaths.profile);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return RefreshIndicator(
            onRefresh: () =>
                refreshAndWait(ref, customerShipmentsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${profile?.fullName ?? 'Customer'}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Send and track parcels across Sabah.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimary.withValues(
                                  alpha: .85,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 44,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _WalletLoyaltyStrip(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_box_outlined,
                        label: 'Send parcel',
                        onTap: () =>
                            context.push(RoutePaths.customerCreateShipment),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.travel_explore,
                        label: 'Track parcel',
                        onTap: () => context.push(RoutePaths.trackOrder),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'E-Wallet',
                        onTap: () => context.push(RoutePaths.customerWallet),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Rewards',
                        onTap: () => context.push(RoutePaths.customerLoyalty),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'My shipments',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Auto-refreshes',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                shipmentsAsync.maybeWhen(
                  data: (shipments) => Row(
                    children: [
                      Expanded(
                        child: _ShipmentStat(
                          label: 'Active',
                          value: shipments
                              .where(
                                (s) =>
                                    s.status != ShipmentStatus.delivered &&
                                    s.status != ShipmentStatus.cancelled &&
                                    s.status != ShipmentStatus.failed,
                              )
                              .length,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ShipmentStat(
                          label: 'Delivered',
                          value: shipments
                              .where(
                                (s) => s.status == ShipmentStatus.delivered,
                              )
                              .length,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                shipmentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: AppLoadingIndicator(message: 'Loading shipments...'),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Could not load shipments.\n$e\n\n'
                      'Please check your connection and pull down to retry.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  data: (shipments) {
                    if (shipments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No shipments yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap New Shipment to create your first parcel.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final shipment in shipments)
                          ShipmentListTile(
                            shipment: shipment,
                            onTap: () => context.push(
                              RoutePaths.customerShipmentDetail(shipment.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalletLoyaltyStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletAccountProvider);
    final loyalty = ref.watch(loyaltyAccountProvider);
    final theme = Theme.of(context);
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final tier = tierForPoints(loyalty.points);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(RoutePaths.customerWallet),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    money.format(wallet.balance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(RoutePaths.customerLoyalty),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tier.name} rewards',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${loyalty.points} pts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShipmentStat extends StatelessWidget {
  const _ShipmentStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
