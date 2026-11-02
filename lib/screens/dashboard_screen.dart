import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';
import 'exchange_screen.dart';
import 'login_screen.dart';
import 'payment_methods_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _mint = Color(0xFF00E676);
  static const _muted = Color(0xFF8994A6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<WalletState>().refreshWalletData());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();
    final theme = Theme.of(context);
    final fullName = wallet.fullName ?? '';
    final phoneNumber = wallet.phoneNumber ?? '';
    final displayName = fullName.isNotEmpty
        ? fullName.split(' ').first
        : phoneNumber.isEmpty
        ? context.tr('dashboard.fallback_name')
        : phoneNumber;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: context.tr('dashboard.logout'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<WalletState>().logout();
              } on WalletApiException catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(error.message)));
              }
              navigator.pushNamedAndRemoveUntil(
                LoginScreen.routeName,
                (_) => false,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: const LanguageToggleButton(),
          ),
        ],
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: _mint,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            GestureDetector(
              onLongPress: () {
                if (context.read<WalletState>().isAdminUser) {
                  Navigator.pushNamed(context, '/admin_rates');
                }
              },
              child: const Text(
                'Cali Black Exchange',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<WalletState>().refreshWalletData(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                wallet.isAdminUser
                    ? context.tr('dashboard.admin_wallet_label')
                    : context.tr('dashboard.wallet_label'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _muted,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                context.tr('dashboard.greeting', {'name': displayName}),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFD2D9E3),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _WalletBalanceCard(
                usdBalance: wallet.usdBalance,
                slshBalance: wallet.slshBalance,
                error: wallet.walletError,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: context.tr('dashboard.deposit'),
                      icon: Icons.add_rounded,
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(PaymentMethodsScreen.depositRouteName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: context.tr('dashboard.withdraw'),
                      icon: Icons.south_west_rounded,
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(PaymentMethodsScreen.withdrawRouteName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: context.tr('dashboard.currency_exchange'),
                      icon: Icons.swap_vert_rounded,
                      secondary: true,
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(ExchangeScreen.routeName);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('dashboard.recent_activity'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Text(
                    context.tr('dashboard.total_transactions', {
                      'count': wallet.transactions.length,
                    }),
                    style: theme.textTheme.bodySmall?.copyWith(color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (wallet.transactionsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    wallet.transactionsError!,
                    style: const TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 12,
                    ),
                  ),
                )
              else if (wallet.transactions.isEmpty)
                const _EmptyTransactions()
              else
                ...wallet.transactions.map(_TransactionTile.new),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.usdBalance,
    required this.slshBalance,
    this.error,
  });

  final double usdBalance;
  final double slshBalance;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2837), Color(0xFF141923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('dashboard.current_balance'),
            style: const TextStyle(
              color: Color(0xFFA7B0C0),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr('dashboard.available_balance'),
            style: const TextStyle(color: Color(0xFF8994A6), fontSize: 11),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _BalanceValue(currency: 'USD', value: usdBalance)),
              const SizedBox(width: 14),
              Expanded(
                child: _BalanceValue(currency: 'SLSH', value: slshBalance),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({required this.currency, required this.value});

  final String currency;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currency,
          style: const TextStyle(
            color: Color(0xFF8994A6),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF4F7FB),
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: secondary
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00F080), Color(0xFF00C967)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: secondary ? const Color(0xFF161B26) : null,
        borderRadius: BorderRadius.circular(18),
        border: secondary
            ? Border.all(color: Colors.white.withValues(alpha: 0.09))
            : null,
        boxShadow: secondary
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: secondary
                      ? const Color(0xFFCCD4E0)
                      : const Color(0xFF062A18),
                  size: 19,
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondary
                        ? const Color(0xFFE1E7EF)
                        : const Color(0xFF062A18),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == TransactionType.deposit;
    final isExchange = transaction.type == TransactionType.exchange;
    final statusColor = switch (transaction.status) {
      TransactionStatus.completed => const Color(0xFF00E676),
      TransactionStatus.pending => const Color(0xFFFFB547),
      TransactionStatus.failed => const Color(0xFFFF6B74),
    };
    final amountColor = isDeposit || isExchange
        ? const Color(0xFF00E676)
        : const Color(0xFFFF7781);
    final statusText = switch (transaction.status) {
      TransactionStatus.completed => context.tr('dashboard.status_completed'),
      TransactionStatus.pending => context.tr('dashboard.status_pending'),
      TransactionStatus.failed => context.tr('dashboard.status_failed'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDeposit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExchange
                      ? context.tr('dashboard.transaction_exchange')
                      : isDeposit
                      ? context.tr('dashboard.deposit')
                      : context.tr('dashboard.withdrawal'),
                  style: const TextStyle(
                    color: Color(0xFFF0F3F8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${transaction.gateway}  ·  ${_formatDate(context, transaction.date)}',
                  style: const TextStyle(
                    color: Color(0xFF8994A6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.45),
                            blurRadius: 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isExchange
                ? '-${transaction.amount.toStringAsFixed(2)} '
                      '${transaction.fromCurrency ?? ''} → +'
                      '${transaction.convertedAmount?.toStringAsFixed(2) ?? '0.00'} '
                      '${transaction.toCurrency ?? ''}'
                : '${isDeposit ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w700,
              fontSize: isExchange ? 11 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    const monthKeys = [
      'dashboard.month_jan',
      'dashboard.month_feb',
      'dashboard.month_mar',
      'dashboard.month_apr',
      'dashboard.month_may',
      'dashboard.month_jun',
      'dashboard.month_jul',
      'dashboard.month_aug',
      'dashboard.month_sep',
      'dashboard.month_oct',
      'dashboard.month_nov',
      'dashboard.month_dec',
    ];
    return context.tr('dashboard.date_format', {
      'month': context.tr(monthKeys[date.month - 1]),
      'day': date.day,
      'year': date.year,
    });
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 30,
            color: Color(0xFF8994A6),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('dashboard.empty_title'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr('dashboard.empty_body'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF8994A6)),
          ),
        ],
      ),
    );
  }
}
