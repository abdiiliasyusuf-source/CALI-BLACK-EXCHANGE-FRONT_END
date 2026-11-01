import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../services/ussd_dialer.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ussd_instruction_sheet.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  static const routeName = '/exchange';

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  static const _mint = Color(0xFF00E676);
  final _amountController = TextEditingController();
  bool _isUsdToSlsh = true;
  String? _amountErrorKey;
  String? _amountErrorText;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_handleAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    final input = _amountController.text.trim();
    final value = double.tryParse(input);
    final errorKey =
        input.isEmpty || value != null && value.isFinite && value > 0
        ? null
        : 'exchange.amountPositiveError';
    if (_amountErrorKey == errorKey && _amountErrorText == null) {
      setState(() {});
    } else {
      setState(() {
        _amountErrorKey = errorKey;
        _amountErrorText = null;
      });
    }
  }

  void _toggleDirection() {
    setState(() {
      _isUsdToSlsh = !_isUsdToSlsh;
      _amountErrorKey = null;
      _amountErrorText = null;
    });
  }

  Future<void> _confirmExchange() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() {
        _amountErrorKey = 'exchange.amountPositiveError';
        _amountErrorText = null;
      });
      return;
    }

    final wallet = context.read<WalletState>();
    final rate = _isUsdToSlsh ? wallet.usdToSlshRate : wallet.slshToUsdRate;
    if (!rate.isFinite || rate <= 0) {
      setState(() {
        _amountErrorKey = 'exchange.liveRatesUnavailableError';
        _amountErrorText = null;
      });
      return;
    }

    final converted = _isUsdToSlsh ? amount * rate : amount / rate;
    final fromCurrency = _isUsdToSlsh ? 'USD' : 'SLSH';
    final toCurrency = _isUsdToSlsh ? 'SLSH' : 'USD';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _ExchangeConfirmationSheet(
        amount: amount,
        converted: converted,
        rate: rate,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        isUsdToSlsh: _isUsdToSlsh,
      ),
    );
    if (confirmed != true || !mounted) return;

    final completed = await runUssdTransaction(
      context,
      provider: _isUsdToSlsh
          ? UssdProvider.zaadExchangeUsdToSlsh
          : UssdProvider.zaadExchangeSlshToUsd,
      amount: amount,
    );
    if (!completed || !mounted) return;

    try {
      await context.read<WalletState>().submitExchange(amount, _isUsdToSlsh);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.trRead('exchange.successSnackbar'))),
      );
      Navigator.of(context).pop();
    } on WalletApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _amountErrorKey = null;
        _amountErrorText = error.message;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _amountErrorKey = null;
        _amountErrorText = error.message?.toString();
      });
    } on StateError catch (error) {
      setState(() {
        _amountErrorKey = null;
        _amountErrorText = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();
    final fromCurrency = _isUsdToSlsh ? 'USD' : 'SLSH';
    final toCurrency = _isUsdToSlsh ? 'SLSH' : 'USD';
    final rate = _isUsdToSlsh ? wallet.usdToSlshRate : wallet.slshToUsdRate;
    final input = double.tryParse(_amountController.text.trim());
    final output =
        input == null || !input.isFinite || !rate.isFinite || rate <= 0
        ? 0.0
        : _isUsdToSlsh
        ? input * rate
        : input / rate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('exchange.appTitle'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: const LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _ExchangeHeader(
              usdRate: wallet.usdToSlshRate,
              sellRate: wallet.slshToUsdRate,
            ),
            const SizedBox(height: 24),
            _CurrencyCard(
              title: context.tr('exchange.from'),
              currency: fromCurrency,
              currencyLabel: _currencyLabel(fromCurrency),
              controller: _amountController,
              errorText: _amountErrorKey == null
                  ? _amountErrorText
                  : context.tr(_amountErrorKey!),
            ),
            Align(
              heightFactor: 1,
              child: Transform.translate(
                offset: const Offset(0, -1),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F080), Color(0xFF00C967)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _mint.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: context.tr('exchange.swapTooltip'),
                    onPressed: _toggleDirection,
                    icon: const Icon(
                      Icons.swap_vert_rounded,
                      color: Color(0xFF062A18),
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -1),
              child: _CurrencyCard(
                title: context.tr('exchange.to'),
                currency: toCurrency,
                currencyLabel: _currencyLabel(toCurrency),
                previewAmount: output,
              ),
            ),
            const SizedBox(height: 17),
            _RateSummary(
              rate: rate,
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              amount: input,
              convertedAmount: output,
            ),
            const SizedBox(height: 22),
            _ConfirmButton(
              onPressed: rate > 0 && rate.isFinite ? _confirmExchange : null,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('exchange.demoNote'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8994A6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _currencyLabel(String currency) {
    return currency == 'USD' ? 'USD  \$' : 'SLSH';
  }
}

class _ExchangeHeader extends StatelessWidget {
  const _ExchangeHeader({required this.usdRate, required this.sellRate});

  final double usdRate;
  final double sellRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2837), Color(0xFF141923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.currency_exchange_rounded,
                color: Color(0xFF00E676),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('exchange.headerTitle'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4F7FB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('exchange.headerDescription'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFA7B0C0), height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatePill(
                label: context.tr('exchange.usdToSlsh'),
                rate: usdRate > 0
                    ? _formatNumber(usdRate)
                    : context.tr('exchange.unavailable'),
              ),
              _RatePill(
                label: context.tr('exchange.slshToUsd'),
                rate: sellRate > 0
                    ? _formatNumber(sellRate)
                    : context.tr('exchange.unavailable'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatePill extends StatelessWidget {
  const _RatePill({required this.label, required this.rate});

  final String label;
  final String rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label  $rate',
        style: const TextStyle(
          color: Color(0xFF8DF5B5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.title,
    required this.currency,
    required this.currencyLabel,
    this.controller,
    this.errorText,
    this.previewAmount,
  });

  final String title;
  final String currency;
  final String currencyLabel;
  final TextEditingController? controller;
  final String? errorText;
  final double? previewAmount;

  @override
  Widget build(BuildContext context) {
    final isEditable = controller != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFA7B0C0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Text(
                  currencyLabel,
                  style: const TextStyle(
                    color: Color(0xFFEAF0F7),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isEditable)
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: const TextStyle(
                color: Color(0xFFF4F7FB),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                errorText: errorText,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                filled: true,
                fillColor: const Color(0xFF0F141D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color: Color(0xFF00E676),
                    width: 1.3,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141D),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                previewAmount == null
                    ? '0.00'
                    : _formatNumber(previewAmount!, decimals: 2),
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RateSummary extends StatelessWidget {
  const _RateSummary({
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
    required this.convertedAmount,
  });

  final double rate;
  final String fromCurrency;
  final String toCurrency;
  final double? amount;
  final double convertedAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF00E676),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              rate <= 0
                  ? context.tr('exchange.liveRateUnavailable')
                  : amount == null || amount == 0
                  ? context.tr('exchange.rateSummary', {
                      'rate': _formatNumber(rate),
                    })
                  : context.tr('exchange.conversionSummary', {
                      'amount': _formatNumber(amount!),
                      'fromCurrency': fromCurrency,
                      'convertedAmount': _formatNumber(
                        convertedAmount,
                        decimals: 2,
                      ),
                      'toCurrency': toCurrency,
                    }),
              style: const TextStyle(
                color: Color(0xFFB9C5D3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? null : const Color(0xFF303744),
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF00F080), Color(0xFF00C967)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(17),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.22),
                  blurRadius: 21,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
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
                Text(
                  context.tr('exchange.confirmAgent'),
                  style: TextStyle(
                    color: isEnabled
                        ? const Color(0xFF062A18)
                        : const Color(0xFF8994A6),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: isEnabled
                      ? const Color(0xFF062A18)
                      : const Color(0xFF8994A6),
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

class _ExchangeConfirmationSheet extends StatelessWidget {
  const _ExchangeConfirmationSheet({
    required this.amount,
    required this.converted,
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.isUsdToSlsh,
  });

  final double amount;
  final double converted;
  final double rate;
  final String fromCurrency;
  final String toCurrency;
  final bool isUsdToSlsh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF566174),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 23),
            Text(
              context.tr('exchange.reviewTitle'),
              style: const TextStyle(
                color: Color(0xFFF4F7FB),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _SummaryLine(
              label: context.tr('exchange.youExchange'),
              value: '${_formatNumber(amount, decimals: 2)} $fromCurrency',
            ),
            const SizedBox(height: 11),
            _SummaryLine(
              label: context.tr('exchange.youReceive'),
              value: '${_formatNumber(converted, decimals: 2)} $toCurrency',
              highlighted: true,
            ),
            const SizedBox(height: 11),
            _SummaryLine(
              label: context.tr('exchange.agentRate'),
              value: isUsdToSlsh
                  ? context.tr('exchange.agentRateValue', {
                      'rate': _formatNumber(rate),
                    })
                  : context.tr('exchange.agentRateValue', {
                      'rate': _formatNumber(rate),
                    }),
            ),
            const SizedBox(height: 23),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD7DFE9),
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(context.tr('exchange.cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: const Color(0xFF062A18),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      context.tr('exchange.confirm'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF9BA7B7), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlighted
                ? const Color(0xFF00E676)
                : const Color(0xFFF4F7FB),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

String _formatNumber(double value, {int decimals = 2}) {
  if (!value.isFinite) return '—';
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length == 1 ? grouped : '$grouped.${parts[1]}';
}
