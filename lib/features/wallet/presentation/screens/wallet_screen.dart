import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/wallet_account.dart';
import '../providers/wallet_providers.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  WalletTxType? _filter;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletAccountProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final theme = Theme.of(context);
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final txs = wallet.transactions
        .where((t) => _filter == null || t.type == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Wallet'),
        actions: [
          TextButton(
            onPressed: () => context.push(RoutePaths.customerLoyalty),
            child: const Text('Rewards'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: .85),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money.format(wallet.balance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Account ${profile?.accountNo?.isNotEmpty == true ? profile!.accountNo : 'demo'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: .8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Demo wallet — not linked to IPOSB finance yet',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showTopUp(context, money),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Top up'),
          ),
          const SizedBox(height: 20),
          Text(
            'History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              FilterChip(
                label: const Text('Top-up'),
                selected: _filter == WalletTxType.topUp,
                onSelected: (_) => setState(() => _filter = WalletTxType.topUp),
              ),
              FilterChip(
                label: const Text('Spend'),
                selected: _filter == WalletTxType.spend,
                onSelected: (_) => setState(() => _filter = WalletTxType.spend),
              ),
              FilterChip(
                label: const Text('Refund'),
                selected: _filter == WalletTxType.refund,
                onSelected: (_) =>
                    setState(() => _filter = WalletTxType.refund),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'No transactions in this filter.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...txs.map((tx) => _TxTile(tx: tx, money: money)),
        ],
      ),
    );
  }

  Future<void> _showTopUp(BuildContext context, NumberFormat money) async {
    var selected = demoTopUpPresets[2];
    final custom = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Top up wallet',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Demo only — no real payment is taken.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amt in demoTopUpPresets)
                        ChoiceChip(
                          label: Text(money.format(amt)),
                          selected: selected == amt && custom.text.isEmpty,
                          onSelected: (_) {
                            custom.clear();
                            setModal(() => selected = amt);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: custom,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Other amount (RM)',
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirm top up'),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
    final typed = double.tryParse(custom.text.trim());
    custom.dispose();
    if (ok != true || !mounted) return;
    final amount = typed != null && typed > 0 ? typed : selected;
    ref.read(walletAccountProvider.notifier).topUp(amount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${money.format(amount)} (demo)')),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, required this.money});

  final WalletTx tx;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = tx.isCredit;
    final color = credit ? theme.colorScheme.tertiary : theme.colorScheme.error;
    final icon = switch (tx.type) {
      WalletTxType.topUp => Icons.add_card_outlined,
      WalletTxType.spend => Icons.local_shipping_outlined,
      WalletTxType.refund => Icons.replay_outlined,
      WalletTxType.reward => Icons.card_giftcard_outlined,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        title: Text(tx.title),
        subtitle: Text(
          [
            DateFormat('d MMM yyyy, HH:mm').format(tx.at),
            if (tx.note != null) tx.note!,
          ].join(' · '),
        ),
        trailing: Text(
          '${credit ? '+' : ''}${money.format(tx.amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
