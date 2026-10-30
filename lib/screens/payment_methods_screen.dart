import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/language_toggle.dart';
import 'deposit_screen.dart';
import 'onexbet_withdrawal_screen.dart';
import 'withdrawal_screen.dart';

enum WalletFlow { deposit, withdraw }

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key, required this.flow});

  static const depositRouteName = '/deposit-methods';
  static const withdrawRouteName = '/withdraw-methods';

  final WalletFlow flow;

  bool get _isDeposit => flow == WalletFlow.deposit;

  void _open(BuildContext context, _Method method) {
    final navigator = Navigator.of(context);
    if (_isDeposit) {
      navigator.pushNamed(DepositScreen.routeName, arguments: method.gateway);
      return;
    }
    switch (method.id) {
      case 'onexbet':
        navigator.pushNamed(OneXBetWithdrawalScreen.routeName);
      case 'crypto':
        navigator.pushNamed(WithdrawalScreen.routeName);
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trRead('methods.coming_soon'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = <_Method>[
      const _Method(
        id: 'edahab',
        title: 'Edahab',
        icon: Icons.account_balance_wallet_rounded,
        color: Color(0xFFF5B301),
        gateway: 'eDahab Mobile Money',
      ),
      const _Method(
        id: 'zaad',
        title: 'Zaad',
        icon: Icons.phone_android_rounded,
        color: Color(0xFF2E9BFF),
        gateway: 'Zaad Mobile Money',
      ),
      const _Method(
        id: 'onexbet',
        title: '1xBet',
        icon: Icons.sports_esports_rounded,
        color: Color(0xFF3D7BFF),
        gateway: '1xBet',
      ),
      _Method(
        id: 'crypto',
        title: context.tr('methods.crypto'),
        icon: Icons.currency_bitcoin_rounded,
        color: const Color(0xFFFF9F43),
        gateway: 'Crypto',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            _isDeposit ? 'methods.deposit_title' : 'methods.withdraw_title',
          ),
        ),
        actions: const [LanguageToggle(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              context.tr(
                _isDeposit
                    ? 'methods.deposit_subtitle'
                    : 'methods.withdraw_subtitle',
              ),
              style: const TextStyle(color: Color(0xFFA7B0C0), height: 1.45),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 14) / 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final method in methods)
                      SizedBox(
                        width: width,
                        child: _MethodCard(
                          method: method,
                          onTap: () => _open(context, method),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Method {
  const _Method({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.gateway,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String gateway;
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method, required this.onTap});

  final _Method method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: method.title,
      child: Material(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('method-${method.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: method.color.withValues(alpha: 0.16),
                    border: Border.all(color: method.color, width: 1.5),
                  ),
                  child: Icon(method.icon, color: method.color, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  method.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
