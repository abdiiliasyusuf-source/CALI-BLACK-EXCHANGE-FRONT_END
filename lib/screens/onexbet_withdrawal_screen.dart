import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/merchant_number_card.dart';

class OneXBetWithdrawalScreen extends StatefulWidget {
  const OneXBetWithdrawalScreen({super.key});

  static const routeName = '/withdraw-1xbet';

  @override
  State<OneXBetWithdrawalScreen> createState() =>
      _OneXBetWithdrawalScreenState();
}

class _OneXBetWithdrawalScreenState extends State<OneXBetWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _fundingSource = 'zaad';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _playerController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final wallet = context.read<WalletState>();
    String? title;
    String? message;
    var success = false;
    try {
      final reference = await wallet.submit1xBetWithdrawal(
        playerId: _playerController.text,
        amount: double.parse(_amountController.text.trim()),
        destinationPhone: _phoneController.text,
        fundingSource: _fundingSource,
        withdrawalCode: _codeController.text,
      );
      success = true;
      if (!mounted) return;
      title = context.trRead('wd1x.success_title');
      message = [
        context.trRead('wd1x.success_body'),
        context.trRead('wd1x.reference', {'reference': reference}),
      ].join('\n\n');
    } on WalletApiException catch (error) {
      if (!mounted) return;
      title = context.trRead('wd1x.error_title');
      message = error.message;
    } on ArgumentError catch (error) {
      if (!mounted) return;
      title = context.trRead('wd1x.error_title');
      message = error.message?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          success ? Icons.check_circle : Icons.error_outline,
          color: success
              ? Colors.green
              : Theme.of(dialogContext).colorScheme.error,
          size: 48,
        ),
        title: Text(title!),
        content: Text(message!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.trRead('wd1x.ok')),
          ),
        ],
      ),
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite) {
      return context.trRead('withdrawal.invalid_amount');
    }
    if (amount < 1) return context.trRead('withdrawal.minimum_amount');
    if (amount > 1000000) return context.trRead('deposit.maximum_amount');
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    return RegExp(r'^(\+252)?6[35]\d{7}$').hasMatch(phone)
        ? null
        : context.trRead('wd1x.phone_invalid');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('wd1x.title')),
        actions: const [
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
            Text(
              context.tr('wd1x.header_title'),
              style: const TextStyle(
                color: Color(0xFFF4F7FB),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('wd1x.header_description'),
              style: const TextStyle(color: Color(0xFFA7B0C0), height: 1.45),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _playerController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: context.tr('wd1x.player_label'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z0-9_-]{1,64}$')
                            .hasMatch((value ?? '').trim())
                        ? null
                        : context.trRead('wd1x.player_required'),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
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
                      labelText: context.tr('wd1x.amount_label'),
                      hintText: '0.00',
                      prefixText: '\$ ',
                    ),
                    validator: _validateAmount,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _fundingSource,
                    decoration: InputDecoration(
                      labelText: context.tr('wd1x.source_label'),
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'zaad', child: Text('ZAAD')),
                      DropdownMenuItem(value: 'edahab', child: Text('eDahab')),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _fundingSource = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  MerchantNumberCard(source: _fundingSource),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                    ],
                    decoration: InputDecoration(
                      labelText: context.tr('wd1x.phone_label'),
                      hintText: '63XXXXXXX',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _codeController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('wd1x.code_label'),
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (value) {
                      return RegExp(r'^[A-Za-z0-9]{3,32}$')
                              .hasMatch((value ?? '').trim())
                          ? null
                          : context.trRead('wd1x.code_invalid');
                    },
                    onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(context.tr('wd1x.submitting')),
                            ],
                          )
                        : Text(context.tr('wd1x.submit')),
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
