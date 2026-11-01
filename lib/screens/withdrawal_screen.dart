import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';

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
      return context.trRead('withdrawal.invalid_amount');
    }
    if (amount < 1) return context.trRead('withdrawal.minimum_amount');
    if (amount > context.read<WalletState>().usdBalance) {
      return context.trRead('withdrawal.insufficient_balance');
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
          ? context.trRead('withdrawal.invalid_tron_address')
          : context.trRead('withdrawal.invalid_bep20_address');
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
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text(context.trRead('withdrawal.processing'))),
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
        SnackBar(content: Text(context.trRead('withdrawal.success'))),
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
            content: Text(
              error.message?.toString() ??
                  context.trRead('withdrawal.invalid_input'),
            ),
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
      appBar: AppBar(
        title: Text(context.tr('withdrawal.title')),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.south_west_rounded,
                    color: Color(0xFF00E676),
                    size: 28,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('withdrawal.header_title'),
                    style: const TextStyle(
                      color: Color(0xFFF4F7FB),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('withdrawal.header_description'),
                    style: const TextStyle(
                      color: Color(0xFFA7B0C0),
                      height: 1.45,
                    ),
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
                  Expanded(
                    child: Text(
                      context.tr('withdrawal.available_balance'),
                      style: const TextStyle(color: Color(0xFFA7B0C0)),
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
                    decoration: InputDecoration(
                      labelText: context.tr('withdrawal.asset_label'),
                      prefixIcon: const Icon(Icons.currency_bitcoin_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'USDT_TRC20',
                        child: const Text('USDT (TRC-20)'),
                      ),
                      DropdownMenuItem(
                        value: 'USDC_POLYGON',
                        child: const Text('USDC (Polygon)'),
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
                    decoration: InputDecoration(
                      labelText: context.tr('withdrawal.amount_label'),
                      hintText: '0.00',
                      prefixText: '\$ ',
                      helperText: context.tr('withdrawal.amount_helper'),
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
                      labelText: context.tr('withdrawal.address_label'),
                      hintText: _asset == 'USDT_TRC20'
                          ? context.tr('withdrawal.tron_address_hint')
                          : context.tr('withdrawal.bep20_address_hint'),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      helperText: _asset == 'USDT_TRC20'
                          ? context.tr('withdrawal.tron_address_helper')
                          : context.tr('withdrawal.bep20_address_helper'),
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
                Text(
                  context.tr('withdrawal.submit'),
                  style: const TextStyle(
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
