import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/wallet_account.dart';

const demoTopUpPresets = [10.0, 20.0, 50.0, 100.0];

class WalletNotifier extends StateNotifier<WalletAccount> {
  WalletNotifier() : super(_seed());

  static WalletAccount _seed() {
    final now = DateTime.now();
    return WalletAccount(
      balance: 128.50,
      transactions: [
        WalletTx(
          id: 'w1',
          type: WalletTxType.topUp,
          title: 'Top up (FPX demo)',
          amount: 100,
          at: now.subtract(const Duration(days: 6)),
        ),
        WalletTx(
          id: 'w2',
          type: WalletTxType.spend,
          title: 'Shipment 26791963',
          amount: -18.50,
          at: now.subtract(const Duration(days: 4)),
          note: 'Prepaid delivery fee (demo)',
        ),
        WalletTx(
          id: 'w3',
          type: WalletTxType.reward,
          title: 'Welcome bonus',
          amount: 10,
          at: now.subtract(const Duration(days: 12)),
        ),
        WalletTx(
          id: 'w4',
          type: WalletTxType.refund,
          title: 'Cancelled CN refund',
          amount: 12,
          at: now.subtract(const Duration(days: 20)),
        ),
        WalletTx(
          id: 'w5',
          type: WalletTxType.spend,
          title: 'Shipment 26110088',
          amount: -25,
          at: now.subtract(const Duration(days: 28)),
        ),
      ],
    );
  }

  void topUp(double amount, {String method = 'Demo FPX'}) {
    if (amount <= 0) return;
    final tx = WalletTx(
      id: 'w${DateTime.now().millisecondsSinceEpoch}',
      type: WalletTxType.topUp,
      title: 'Top up ($method)',
      amount: amount,
      at: DateTime.now(),
      note: 'UI demo — not charged',
    );
    state = state.copyWith(
      balance: state.balance + amount,
      transactions: [tx, ...state.transactions],
    );
  }
}

final walletAccountProvider =
    StateNotifierProvider<WalletNotifier, WalletAccount>(
  (ref) => WalletNotifier(),
);
