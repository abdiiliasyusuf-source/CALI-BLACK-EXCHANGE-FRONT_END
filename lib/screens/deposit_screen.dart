import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';
import '../services/ussd_dialer.dart';
import '../widgets/ussd_instruction_sheet.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  static const routeName = '/deposit';

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _txHashController = TextEditingController();
  final _playerIdController = TextEditingController();
  String _selectedGateway = 'Zaad Mobile Money';
  String _selectedCryptoAsset = 'USDT_TRC20';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _txHashController.dispose();
    _playerIdController.dispose();
    super.dispose();
  }

  bool get _isBettingGateway =>
      _selectedGateway == '1xBet' || _selectedGateway == 'MobCash';

  Future<void> _startSelectedDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGateway == 'Crypto' || _isBettingGateway) {
      await _executeDeposit();
      return;
    }

    FocusScope.of(context).unfocus();
    final provider = _selectedGateway == 'eDahab Mobile Money'
        ? UssdProvider.edahab
        : UssdProvider.zaadUsd;
    final completed = await runUssdTransaction(
      context,
      provider: provider,
      amount: double.parse(_amountController.text.trim()),
    );
    if (completed && mounted) await _executeDeposit();
  }

  Future<void> _executeDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    var loaderVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: Text('Submitting securely…')),
          ],
        ),
      ),
    );
    try {
      final amount = double.parse(_amountController.text.trim());
      final wallet = context.read<WalletState>();
      String? transactionId;
      if (_selectedGateway == 'Crypto') {
        await wallet.submitCryptoDeposit(
          amount: amount,
          asset: _selectedCryptoAsset,
          txHash: _txHashController.text.trim(),
        );
      } else if (_selectedGateway == '1xBet') {
        transactionId = await wallet.submit1xBetDeposit(
          playerId: _playerIdController.text,
          amount: amount,
        );
      } else if (_selectedGateway == 'MobCash') {
        transactionId = await wallet.submitMobCashDeposit(
          playerId: _playerIdController.text,
          amount: amount,
        );
      } else {
        await wallet.submitMobileMoneyDeposit(
          amount: amount,
          gateway: _selectedGateway,
        );
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loaderVisible = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedGateway == 'Crypto'
                ? 'Crypto deposit submitted and marked pending approval.'
                : _isBettingGateway
                ? '$_selectedGateway deposit submitted as pending. Reference: $transactionId'
                : 'Mobile money deposit request submitted as pending.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      if (_selectedGateway != 'Crypto') {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop();
      }
    } on WalletApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message?.toString() ?? 'Invalid input.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        if (loaderVisible) Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite) return 'Enter a valid amount.';
    if (amount < 1) return 'Minimum deposit is \$1.00 USD.';
    if (amount > 1000000) return 'Enter an amount below \$1,000,000.';
    return null;
  }

  String? _validateTxHash(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the transaction hash.';
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value.trim())) {
      return 'Transaction hash must be 64 hexadecimal characters.';
    }
    return null;
  }

  String? _validatePlayerId(String? value) {
    final playerId = value?.trim() ?? '';
    if (playerId.isEmpty || playerId.length > 100) {
      return 'Enter a valid player account ID.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet deposit',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _DepositHeader(),
            const SizedBox(height: 26),
            Text(
              'Deposit details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter an amount and choose how to fund your wallet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8994A6),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      color: Color(0xFFF4F7FB),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (USD)',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      helperText: _selectedGateway == 'Crypto'
                          ? 'Verified deposits are credited to your Cali Black Exchange wallet balance.'
                          : 'Minimum deposit: \$1.00 USD.',
                    ),
                    validator: _validateAmount,
                  ),
                  if (_isBettingGateway) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _playerIdController,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: Color(0xFFF4F7FB),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: '$_selectedGateway User ID',
                        hintText: 'Enter your betting account ID',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: _validatePlayerId,
                    ),
                  ],
                  if (_selectedGateway == 'Crypto') ...[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCryptoAsset,
                      decoration: const InputDecoration(
                        labelText: 'Crypto asset',
                        prefixIcon: Icon(Icons.currency_bitcoin_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'USDT_TRC20',
                          child: Text('USDT (TRC-20)'),
                        ),
                        DropdownMenuItem(
                          value: 'USDC_BEP20',
                          child: Text('USDC (BEP-20)'),
                        ),
                      ],
                      onChanged: (asset) {
                        if (asset != null) {
                          setState(() => _selectedCryptoAsset = asset);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _txHashController,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: Color(0xFFF4F7FB),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Transaction Hash (TxHash)',
                        hintText: 'Paste the 64-character transaction hash',
                        prefixIcon: Icon(Icons.tag_rounded),
                        helperText: 'Use the transaction hash to verify the deposit to your Cali Black Exchange wallet.',
                      ),
                      validator: _validateTxHash,
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    'PAYMENT METHOD',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFA7B0C0),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 11),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 600 ? 3 : 2;
                      final tileWidth =
                          (constraints.maxWidth - 12 * (columns - 1)) /
                          columns;
                      final methods = [
                        (
                          title: 'Zaad',
                          subtitle: 'Zaad Mobile Money',
                          icon: Icons.phone_android_rounded,
                          gateway: 'Zaad Mobile Money',
                        ),
                        (
                          title: 'eDahab',
                          subtitle: 'eDahab Mobile Money',
                          icon: Icons.account_balance_rounded,
                          gateway: 'eDahab Mobile Money',
                        ),
                        (
                          title: '1xBet',
                          subtitle: 'Betting account deposit',
                          icon: Icons.sports_esports_rounded,
                          gateway: '1xBet',
                        ),
                        (
                          title: 'MobCash',
                          subtitle: 'Betting account deposit',
                          icon: Icons.point_of_sale_rounded,
                          gateway: 'MobCash',
                        ),
                        (
                          title: 'Crypto (USDT / USDC)',
                          subtitle: 'Crypto deposit',
                          icon: Icons.currency_bitcoin_rounded,
                          gateway: 'Crypto',
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final method in methods)
                            SizedBox(
                              width: tileWidth,
                              child: _PaymentMethodTile(
                                title: method.title,
                                subtitle: method.subtitle,
                                icon: method.icon,
                                selected:
                                    _selectedGateway == method.gateway,
                                onTap: () => setState(
                                  () => _selectedGateway = method.gateway,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  _SubmitButton(
                    isSubmitting: _isSubmitting,
                    onPressed: _isSubmitting
                        ? null
                        : _startSelectedDeposit,
                    label: _selectedGateway == 'Crypto'
                        ? 'Submit Crypto Deposit'
                        : _isBettingGateway
                        ? 'Submit $_selectedGateway Deposit'
                        : 'Pay with ${_selectedGateway == 'eDahab Mobile Money' ? 'eDahab' : 'ZAAD'}',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: Color(0xFF8994A6),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _selectedGateway == 'Crypto'
                              ? 'Crypto deposits remain pending until transaction verification.'
                              : _isBettingGateway
                              ? 'Betting deposits are processed securely by the cashier service.'
                              : 'Wallet deposits are recorded as pending requests.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8994A6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositHeader extends StatelessWidget {
  const _DepositHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2837), Color(0xFF141923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF00E676),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Secure Wallet Deposit Center',
                  style: TextStyle(
                    color: Color(0xFFF4F7FB),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.24),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF00E676),
                  size: 15,
                ),
                SizedBox(width: 7),
                Text(
                  'CALI BLACK EXCHANGE · SECURE DEPOSIT',
                  style: TextStyle(
                    color: Color(0xFF8DF5B5),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Add funds to your Cali Black Exchange wallet using a supported provider.',
            style: TextStyle(color: Color(0xFFA7B0C0), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF00E676);

    return Semantics(
      button: true,
      selected: selected,
      label: '$title $subtitle',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E676).withValues(alpha: 0.07)
              : const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? mint : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: mint.withValues(alpha: 0.08), blurRadius: 15)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 14, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        color: selected ? mint : const Color(0xFF9BA7B7),
                        size: 21,
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? mint : Colors.transparent,
                          border: Border.all(
                            color: selected ? mint : const Color(0xFF596476),
                            width: 1.3,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Color(0xFF062A18),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFF4F7FB)
                          : const Color(0xFFD5DCE6),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8994A6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isSubmitting,
    required this.onPressed,
    required this.label,
  });

  final bool isSubmitting;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF52665B), Color(0xFF3A4A43)],
              )
            : const LinearGradient(
                colors: [Color(0xFF00F080), Color(0xFF00C967)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                  blurRadius: 21,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSubmitting)
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF062A18),
                    ),
                  )
                else
                  Text(
                    label,
                    style: TextStyle(
                      color: Color(0xFF062A18),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF062A18),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
