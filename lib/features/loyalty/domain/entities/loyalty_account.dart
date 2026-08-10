class LoyaltyTier {
  const LoyaltyTier({
    required this.code,
    required this.name,
    required this.minPoints,
    required this.perks,
  });

  final String code;
  final String name;
  final int minPoints;
  final List<String> perks;
}

class LoyaltyReward {
  const LoyaltyReward({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pointsCost,
  });

  final String id;
  final String title;
  final String subtitle;
  final int pointsCost;
}

class LoyaltyAccount {
  const LoyaltyAccount({
    required this.points,
    required this.memberSince,
    required this.redeemedIds,
  });

  final int points;
  final DateTime memberSince;
  final List<String> redeemedIds;

  LoyaltyAccount copyWith({
    int? points,
    DateTime? memberSince,
    List<String>? redeemedIds,
  }) {
    return LoyaltyAccount(
      points: points ?? this.points,
      memberSince: memberSince ?? this.memberSince,
      redeemedIds: redeemedIds ?? this.redeemedIds,
    );
  }
}

const loyaltyTiers = <LoyaltyTier>[
  LoyaltyTier(
    code: 'bronze',
    name: 'Bronze',
    minPoints: 0,
    perks: ['Earn 1 pt / RM1 spent', 'Birthday greeting'],
  ),
  LoyaltyTier(
    code: 'silver',
    name: 'Silver',
    minPoints: 1000,
    perks: ['1.2× points', 'Priority chat support'],
  ),
  LoyaltyTier(
    code: 'gold',
    name: 'Gold',
    minPoints: 2500,
    perks: ['1.5× points', 'Free reattempt once / month'],
  ),
  LoyaltyTier(
    code: 'platinum',
    name: 'Platinum',
    minPoints: 5000,
    perks: ['2× points', 'Dedicated CS line'],
  ),
];

const loyaltyRewards = <LoyaltyReward>[
  LoyaltyReward(
    id: 'r1',
    title: 'RM5 shipping voucher',
    subtitle: 'Off next prepaid shipment',
    pointsCost: 500,
  ),
  LoyaltyReward(
    id: 'r2',
    title: 'RM15 shipping voucher',
    subtitle: 'West Coast / KK Metro',
    pointsCost: 1200,
  ),
  LoyaltyReward(
    id: 'r3',
    title: 'Free same-zone delivery',
    subtitle: 'One local Sabah parcel',
    pointsCost: 2000,
  ),
  LoyaltyReward(
    id: 'r4',
    title: 'IPOSB tote bag',
    subtitle: 'Collect at KK hub',
    pointsCost: 3000,
  ),
];

LoyaltyTier tierForPoints(int points) {
  LoyaltyTier current = loyaltyTiers.first;
  for (final t in loyaltyTiers) {
    if (points >= t.minPoints) current = t;
  }
  return current;
}

LoyaltyTier? nextTierAfter(LoyaltyTier current) {
  final i = loyaltyTiers.indexWhere((t) => t.code == current.code);
  if (i < 0 || i >= loyaltyTiers.length - 1) return null;
  return loyaltyTiers[i + 1];
}
