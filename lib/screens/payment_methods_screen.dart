import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/language_toggle.dart';
import 'deposit_screen.dart';
import 'onexbet_withdrawal_screen.dart';
import 'withdrawal_screen.dart';

enum WalletFlow { deposit, withdraw }

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, required this.flow});

  static const depositRouteName = '/deposit-methods';
  static const withdrawRouteName = '/withdraw-methods';

  final WalletFlow flow;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String? _selectedId;

  bool get _isDeposit => widget.flow == WalletFlow.deposit;

  Future<void> _open(_Method method) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final comingSoon = context.trRead('methods.coming_soon');
    setState(() => _selectedId = method.id);

    if (_isDeposit) {
      // Let the selection animation play before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      await navigator.pushNamed(
        DepositScreen.routeName,
        arguments: method.gateway,
      );
      if (mounted) setState(() => _selectedId = null);
      return;
    }

    switch (method.id) {
      case 'onexbet':
        await navigator.pushNamed(OneXBetWithdrawalScreen.routeName);
      case 'crypto':
        await navigator.pushNamed(WithdrawalScreen.routeName);
      default:
        messenger.showSnackBar(SnackBar(content: Text(comingSoon)));
    }
    if (mounted) setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final methods = <_Method>[
      _Method(
        id: 'onexbet',
        title: '1xBet',
        hint: context.tr('methods.onexbet_hint'),
        color: const Color(0xFF2F7BFF),
        gateway: '1xBet',
        logo: const _TextLogo(
          text: '1x',
          background: Color(0xFF1B5FD9),
          foreground: Colors.white,
        ),
      ),
      _Method(
        id: 'zaad',
        title: 'Zaad',
        hint: context.tr('methods.zaad_hint'),
        color: const Color(0xFF1FD66B),
        gateway: 'Zaad Mobile Money',
        logo: const _TextLogo(
          text: 'Z',
          background: Color(0xFF0E9F4A),
          foreground: Colors.white,
        ),
      ),
      _Method(
        id: 'edahab',
        title: 'Edahab',
        hint: context.tr('methods.edahab_hint'),
        color: const Color(0xFFF5C518),
        gateway: 'eDahab Mobile Money',
        logo: const _CheckLogo(),
      ),
      _Method(
        id: 'crypto',
        title: context.tr('methods.crypto'),
        hint: context.tr('methods.crypto_hint'),
        color: const Color(0xFF26C6A0),
        gateway: 'Crypto',
        logo: const _TextLogo(
          text: '₮',
          background: Color(0xFF26A17B),
          foreground: Colors.white,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          context.tr(
            _isDeposit ? 'methods.deposit_title' : 'methods.withdraw_title',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  context.tr(
                    _isDeposit
                        ? 'methods.deposit_subtitle'
                        : 'methods.withdraw_subtitle',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFA7B0C0),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                for (final method in methods) ...[
                  _MethodCard(
                    method: method,
                    selected: _selectedId == method.id,
                    onTap: () => _open(method),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Method {
  const _Method({
    required this.id,
    required this.title,
    required this.hint,
    required this.color,
    required this.gateway,
    required this.logo,
  });

  final String id;
  final String title;
  final String hint;
  final Color color;
  final String gateway;
  final Widget logo;
}

class _MethodCard extends StatefulWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final _Method method;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final method = widget.method;
    final glowing = widget.selected || _hovered || _pressed;
    final color = method.color;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: method.title,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  color.withValues(alpha: glowing ? 0.14 : 0.04),
                  const Color(0xFF161B26),
                ),
                const Color(0xFF121722),
              ],
            ),
            border: Border.all(
              color: glowing
                  ? color.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.08),
              width: glowing ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: glowing
                    ? color.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: glowing ? 22 : 12,
                offset: glowing ? Offset.zero : const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('method-${method.id}'),
              borderRadius: BorderRadius.circular(22),
              splashColor: color.withValues(alpha: 0.18),
              highlightColor: Colors.transparent,
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hovered = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 56, height: 56, child: method.logo),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            method.hint,
                            style: const TextStyle(
                              color: Color(0xFFA7B0C0),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SelectionIndicator(selected: widget.selected, color: color),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.black),
      ),
    );
  }
}

class _TextLogo extends StatelessWidget {
  const _TextLogo({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background,
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _CheckLogo extends StatelessWidget {
  const _CheckLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E9F4A), Color(0xFF7BD63A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7BD63A).withValues(alpha: 0.4),
            blurRadius: 12,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFFFFD43B),
        size: 34,
      ),
    );
  }
}
