import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/loyalty_account.dart';

class LoyaltyNotifier extends StateNotifier<LoyaltyAccount> {
  LoyaltyNotifier()
      : super(
          LoyaltyAccount(
            points: 2460,
            memberSince: DateTime(2026, 3, 12),
            redeemedIds: const [],
          ),
        );

  String? redeem(LoyaltyReward reward) {
    if (state.redeemedIds.contains(reward.id)) {
      return 'Already redeemed';
    }
    if (state.points < reward.pointsCost) {
      return 'Not enough points';
    }
    state = state.copyWith(
      points: state.points - reward.pointsCost,
      redeemedIds: [...state.redeemedIds, reward.id],
    );
    return null;
  }
}

final loyaltyAccountProvider =
    StateNotifierProvider<LoyaltyNotifier, LoyaltyAccount>(
  (ref) => LoyaltyNotifier(),
);
