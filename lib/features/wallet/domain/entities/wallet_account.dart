enum WalletTxType { topUp, spend, refund, reward }

class WalletTx {
  const WalletTx({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.at,
    this.note,
  });

  final String id;
  final WalletTxType type;
  final String title;
  final double amount;
  final DateTime at;
  final String? note;

  bool get isCredit => amount >= 0;
}

class WalletAccount {
  const WalletAccount({
    required this.balance,
    required this.transactions,
  });

  final double balance;
  final List<WalletTx> transactions;

  WalletAccount copyWith({
    double? balance,
    List<WalletTx>? transactions,
  }) {
    return WalletAccount(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}
