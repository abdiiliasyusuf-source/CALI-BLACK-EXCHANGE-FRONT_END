import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../services/ussd_dialer.dart';
import '../widgets/language_toggle.dart';
import '../widgets/merchant_number_card.dart';
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
  String _betFundingSource = 'Zaad';
  bool _isSubmitting = false;
  bool _gatewayInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gatewayInitialized) return;
    _gatewayInitialized = true;
    final gateway = ModalRoute.of(context)?.settings.arguments;
    if (gateway is String) _selectedGateway = gateway;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _txHashController.dispose();
    _playerIdController.dispose();
    super.dispose();
  }

  bool get _isBettingGateway => _selectedGateway == '1xBet';

  bool get _usesCrypto =>
      _selectedGateway == 'Crypto' ||
      (_isBettingGateway && _betFundingSource == 'Crypto');

  /// `zaad` / `edahab` for the selected mobile money route, else null.
  String? get _merchantSource {
    if (_isBettingGateway) {
      return switch (_betFundingSource) {
        'Zaad' => 'zaad',
        'eDahab' => 'edahab',
        _ => null,
      };
    }
    return switch (_selectedGateway) {
      'Zaad Mobile Money' => 'zaad',
      'eDahab Mobile Money' => 'edahab',
      _ => null,
    };
  }

  UssdProvider get _ussdProvider {
    final edahab = _isBettingGateway
        ? _betFundingSource == 'eDahab'
        : _selectedGateway == 'eDahab Mobile Money';
    return edahab ? UssdProvider.edahab : UssdProvider.zaadUsd;
  }

  Future<void> _startSelectedDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usesCrypto) {
      await _executeDeposit();
      return;
    }

    FocusScope.of(context).unfocus();
    final amount = double.parse(_amountController.text.trim());
    final wallet = context.read<WalletState>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.trRead('deposit.alert_sent');
    final failurePrefix = context.trRead('deposit.alert_failed');

    // Fire the cashier alert concurrently with launching the dialer.
    final alert = wallet
        .sendManualDepositAlert(
          amount: amount,
          provider: _merchantSource ?? 'zaad',
          referenceId: _isBettingGateway
              ? _playerIdController.text
              : null,
        )
        .then<String?>((_) => null)
        .catchError((Object error) => error.toString());

    final completed = await runUssdTransaction(
      context,
      provider: _ussdProvider,
      amount: amount,
    );

    final alertError = await alert;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          alertError == null ? successMessage : '$failurePrefix $alertError',
        ),
        backgroundColor: alertError == null ? null : Colors.red.shade700,
      ),
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
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text(context.tr('deposit.submitting'))),
          ],
        ),
      ),
    );
    try {
      final amount = double.parse(_amountController.text.trim());
      final wallet = context.read<WalletState>();
      String? transactionId;
      if (_isBettingGateway) {
        final viaCrypto = _betFundingSource == 'Crypto';
        transactionId = await wallet.submit1xBetDeposit(
          playerId: _playerIdController.text,
          amount: amount,
          fundingSource: _betFundingSource,
          asset: viaCrypto ? _selectedCryptoAsset : null,
          txHash: viaCrypto ? _txHashController.text.trim() : null,
        );
      } else if (_selectedGateway == 'Crypto') {
        await wallet.submitCryptoDeposit(
          amount: amount,
          asset: _selectedCryptoAsset,
          txHash: _txHashController.text.trim(),
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
      if (_isBettingGateway) {
        setState(() => _isSubmitting = false);
        await _showResultDialog(
          title: context.trRead('deposit.success_title'),
          message: context.trRead('deposit.betting_success', {
            'gateway': _selectedGateway,
            'reference': transactionId,
          }),
          success: true,
        );
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedGateway == 'Crypto'
                  ? context.trRead('deposit.crypto_success')
                  : context.trRead('deposit.mobile_success'),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (_selectedGateway != 'Crypto') {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop();
      }
    } on WalletApiException catch (error) {
      if (mounted) {
        if (loaderVisible) {
          Navigator.of(context, rootNavigator: true).pop();
          loaderVisible = false;
        }
        if (_isBettingGateway) {
          setState(() => _isSubmitting = false);
          await _showResultDialog(
            title: context.trRead('deposit.error_title'),
            message: error.message,
            success: false,
          );
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ??
                  context.trRead('deposit.invalid_input'),
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

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool success,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          success ? Icons.check_circle : Icons.error_outline,
          color: success
              ? Colors.green
              : Theme.of(dialogContext).colorScheme.error,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.trRead('deposit.dialog_ok')),
          ),
        ],
      ),
    );
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite) {
      return context.trRead('deposit.invalid_amount');
    }
    if (amount < 1) return context.trRead('deposit.minimum_amount');
    if (amount > 1000000) return context.trRead('deposit.maximum_amount');
    return null;
  }

  String? _validateTxHash(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.trRead('deposit.enter_tx_hash');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value.trim())) {
      return context.trRead('deposit.invalid_tx_hash');
    }
    return null;
  }

  String? _validatePlayerId(String? value) {
    final playerId = value?.trim() ?? '';
    if (playerId.isEmpty || playerId.length > 100) {
      return context.trRead('deposit.invalid_player_id');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('deposit.title'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _DepositHeader(),
            const SizedBox(height: 26),
            Text(
              context.tr('deposit.details_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('deposit.details_description'),
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
                      labelText: context.tr('deposit.amount_label'),
                      hintText: '0.00',
                      prefixText: '\$ ',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      helperText: _usesCrypto
                          ? context.tr('deposit.crypto_amount_helper')
                          : context.tr('deposit.amount_helper'),
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
                        labelText: context.tr('deposit.player_id_label', {
                          'gateway': _selectedGateway,
                        }),
                        hintText: context.tr('deposit.player_id_hint'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: _validatePlayerId,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('deposit.funding_source'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFA7B0C0),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final source in const ['Zaad', 'eDahab', 'Crypto'])
                          ChoiceChip(
                            label: Text(
                              source == 'Crypto'
                                  ? context.tr('deposit.crypto_method_title')
                                  : source,
                            ),
                            selected: _betFundingSource == source,
                            onSelected: (_) =>
                                setState(() => _betFundingSource = source),
                          ),
                      ],
                    ),
                  ],
                  if (_usesCrypto) ...[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCryptoAsset,
                      decoration: InputDecoration(
                        labelText: context.tr('deposit.crypto_asset_label'),
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
                      decoration: InputDecoration(
                        labelText: context.tr('deposit.tx_hash_label'),
                        hintText: context.tr('deposit.tx_hash_hint'),
                        prefixIcon: Icon(Icons.tag_rounded),
                        helperText: context.tr('deposit.tx_hash_helper'),
                      ),
                      validator: _validateTxHash,
                    ),
                  ],
                  if (_merchantSource != null) ...[
                    const SizedBox(height: 20),
                    MerchantNumberCard(source: _merchantSource!),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    context.tr('deposit.payment_method'),
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
                          (constraints.maxWidth - 12 * (columns - 1)) / columns;
                      final methods = [
                        (
                          title: 'Zaad',
                          subtitle: context.tr('deposit.zaad_subtitle'),
                          icon: Icons.phone_android_rounded,
                          gateway: 'Zaad Mobile Money',
                        ),
                        (
                          title: 'eDahab',
                          subtitle: context.tr('deposit.edahab_subtitle'),
                          icon: Icons.account_balance_rounded,
                          gateway: 'eDahab Mobile Money',
                        ),
                        (
                          title: '1xBet',
                          subtitle: context.tr('deposit.betting_subtitle'),
                          icon: Icons.sports_esports_rounded,
                          gateway: '1xBet',
                        ),
                        (
                          title: context.tr('deposit.crypto_method_title'),
                          subtitle: context.tr('deposit.crypto_subtitle'),
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
                                selected: _selectedGateway == method.gateway,
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
                    onPressed: _isSubmitting ? null : _startSelectedDeposit,
                    label: _isBettingGateway
                        ? context.tr('deposit.submit_gateway', {
                            'gateway': _selectedGateway,
                          })
                        : _selectedGateway == 'Crypto'
                        ? context.tr('deposit.submit_crypto')
                        : context.tr(
                            _selectedGateway == 'eDahab Mobile Money'
                                ? 'deposit.pay_edahab'
                                : 'deposit.pay_zaad',
                          ),
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
                          _isBettingGateway
                              ? context.tr('deposit.betting_footer')
                              : _selectedGateway == 'Crypto'
                              ? context.tr('deposit.crypto_footer')
                              : context.tr('deposit.mobile_footer'),
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
              Expanded(
                child: Text(
                  context.tr('deposit.header_title'),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF00E676),
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  context.tr('deposit.secure_badge'),
                  style: const TextStyle(
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
          Text(
            context.tr('deposit.header_description'),
            style: const TextStyle(color: Color(0xFFA7B0C0), fontSize: 13),
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
