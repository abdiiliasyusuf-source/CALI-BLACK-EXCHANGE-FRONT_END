import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  static const routeName = '/withdraw';

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  String _asset = 'USDT_TRC20';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Enter a valid withdrawal amount.';
    }
    if (amount < 1) return 'Minimum withdrawal is \$1.00 USD.';
    if (amount > context.read<WalletState>().usdBalance) {
      return 'Amount exceeds your available USD balance.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';
    final valid = _asset == 'USDT_TRC20'
        ? RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address)
        : RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
    if (!valid) {
      return _asset == 'USDT_TRC20'
          ? 'Enter a valid TRON (TRC-20) address.'
          : 'Enter a valid BNB Smart Chain (BEP-20) address.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
            Expanded(child: Text('Processing withdrawal securely…')),
          ],
        ),
      ),
    );

    try {
      await context.read<WalletState>().submitCryptoWithdrawal(
        amount: double.parse(_amountController.text.trim()),
        asset: _asset,
        address: _addressController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loaderVisible = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal submitted. Your USD balance was updated.'),
        ),
      );
      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<WalletState>().usdBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Crypto withdrawal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2837), Color(0xFF141923)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.south_west_rounded,
                    color: Color(0xFF00E676),
                    size: 28,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Withdraw to crypto',
                    style: TextStyle(
                      color: Color(0xFFF4F7FB),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Review the network and wallet address carefully before submitting.',
                    style: TextStyle(color: Color(0xFFA7B0C0), height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Available USD balance',
                      style: TextStyle(color: Color(0xFFA7B0C0)),
                    ),
                  ),
                  Text(
                    '\$${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _asset,
                    decoration: const InputDecoration(
                      labelText: 'Crypto asset and network',
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
                      if (asset != null) setState(() => _asset = asset);
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Amount (USD)',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      helperText: 'Minimum withdrawal: \$1.00 USD.',
                    ),
                    validator: _validateAmount,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _addressController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Destination wallet address',
                      hintText: _asset == 'USDT_TRC20'
                          ? 'TRON address starting with T'
                          : 'BEP-20 address starting with 0x',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      helperText: _asset == 'USDT_TRC20'
                          ? 'USDT withdrawals use the TRC-20 network.'
                          : 'USDC withdrawals use the BEP-20 network.',
                    ),
                    validator: _validateAddress,
                  ),
                  const SizedBox(height: 24),
                  _WithdrawalButton(
                    isSubmitting: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
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

class _WithdrawalButton extends StatelessWidget {
  const _WithdrawalButton({
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF52665B), Color(0xFF3A4A43)],
              )
            : const LinearGradient(
                colors: [Color(0xFF00F080), Color(0xFF00C967)],
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
                const Text(
                  'Submit Crypto Withdrawal',
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
    );
  }
}
