import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../domain/entities/loyalty_account.dart';
import '../providers/loyalty_providers.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(loyaltyAccountProvider);
    final theme = Theme.of(context);
    final tier = tierForPoints(account.points);
    final next = nextTierAfter(tier);
    final progress = next == null
        ? 1.0
        : ((account.points - tier.minPoints) /
                (next.minPoints - tier.minPoints))
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Rewards'),
        actions: [
          TextButton(
            onPressed: () => context.push(RoutePaths.customerWallet),
            child: const Text('Wallet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${account.points}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'points',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(tier.name),
                        avatar: const Icon(Icons.workspace_premium, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    next == null
                        ? 'Highest tier unlocked'
                        : '${next.minPoints - account.points} pts to ${next.name}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    'Member since ${DateFormat('MMM yyyy').format(account.memberSince)} · demo program',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tiers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final t in loyaltyTiers)
            Card(
              color: t.code == tier.code
                  ? theme.colorScheme.primaryContainer.withValues(alpha: .45)
                  : null,
              child: ListTile(
                leading: Icon(
                  t.code == tier.code
                      ? Icons.verified
                      : Icons.workspace_premium_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text('${t.name} · ${t.minPoints}+ pts'),
                subtitle: Text(t.perks.join(' · ')),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Redeem',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final reward in loyaltyRewards)
            _RewardTile(
              reward: reward,
              points: account.points,
              redeemed: account.redeemedIds.contains(reward.id),
              onRedeem: () {
                final err =
                    ref.read(loyaltyAccountProvider.notifier).redeem(reward);
                final messenger = ScaffoldMessenger.of(context);
                if (err != null) {
                  messenger.showSnackBar(SnackBar(content: Text(err)));
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Redeemed ${reward.title} (demo voucher)'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.points,
    required this.redeemed,
    required this.onRedeem,
  });

  final LoyaltyReward reward;
  final int points;
  final bool redeemed;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final can = !redeemed && points >= reward.pointsCost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(reward.subtitle),
                  const SizedBox(height: 6),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${reward.pointsCost} pts'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: can ? onRedeem : null,
              child: Text(redeemed ? 'Done' : 'Redeem'),
            ),
          ],
        ),
      ),
    );
  }
}
