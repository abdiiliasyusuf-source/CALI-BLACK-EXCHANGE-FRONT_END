import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';

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
  String? _amountError;

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
    final error = input.isEmpty || value != null && value.isFinite && value > 0
        ? null
        : 'Enter an amount greater than zero.';
    if (_amountError == error) {
      setState(() {});
    } else {
      setState(() => _amountError = error);
    }
  }

  void _toggleDirection() {
    setState(() {
      _isUsdToSlsh = !_isUsdToSlsh;
      _amountError = null;
    });
  }

  Future<void> _confirmExchange() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _amountError = 'Enter an amount greater than zero.');
      return;
    }

    final wallet = context.read<WalletState>();
    final available = _isUsdToSlsh ? wallet.usdBalance : wallet.slshBalance;
    if (amount > available) {
      setState(
        () => _amountError =
            'Insufficient ${_isUsdToSlsh ? 'USD' : 'SLSH'} balance.',
      );
      return;
    }

    final rate = _isUsdToSlsh ? wallet.usdToSlshRate : wallet.slshToUsdRate;
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

    try {
      context.read<WalletState>().executeLocalExchange(amount, _isUsdToSlsh);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exchange completed successfully.')),
      );
      Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      setState(() => _amountError = error.message?.toString());
    } on StateError catch (error) {
      setState(() => _amountError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();
    final fromCurrency = _isUsdToSlsh ? 'USD' : 'SLSH';
    final toCurrency = _isUsdToSlsh ? 'SLSH' : 'USD';
    final rate = _isUsdToSlsh ? wallet.usdToSlshRate : wallet.slshToUsdRate;
    final input = double.tryParse(_amountController.text.trim());
    final output = input == null || !input.isFinite
        ? 0.0
        : _isUsdToSlsh
        ? input * rate
        : input / rate;
    final outputBalance = _isUsdToSlsh ? wallet.slshBalance : wallet.usdBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sarif Exchange',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
              title: 'From',
              currency: fromCurrency,
              currencyLabel: _currencyLabel(fromCurrency),
              balance: _isUsdToSlsh ? wallet.usdBalance : wallet.slshBalance,
              controller: _amountController,
              errorText: _amountError,
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
                    tooltip: 'Swap exchange direction',
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
                title: 'To',
                currency: toCurrency,
                currencyLabel: _currencyLabel(toCurrency),
                balance: outputBalance,
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
            _ConfirmButton(onPressed: _confirmExchange),
            const SizedBox(height: 14),
            const Text(
              'This exchange is recorded locally in this demo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8994A6), fontSize: 11),
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
          const Row(
            children: [
              Icon(Icons.currency_exchange_rounded, color: Color(0xFF00E676)),
              SizedBox(width: 10),
              Text(
                'Exchange your currencies',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4F7FB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'USD to Somaliland Shillings and back, at the active agent rate.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFA7B0C0), height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatePill(label: 'USD → SLSH', rate: _formatNumber(usdRate)),
              _RatePill(label: 'SLSH → USD', rate: _formatNumber(sellRate)),
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
    required this.balance,
    this.controller,
    this.errorText,
    this.previewAmount,
  });

  final String title;
  final String currency;
  final String currencyLabel;
  final double balance;
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
          const SizedBox(height: 9),
          Text(
            'Available: ${_formatNumber(balance, decimals: currency == 'USD' ? 2 : 0)} $currency',
            style: const TextStyle(color: Color(0xFF8994A6), fontSize: 11),
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
              amount == null || amount == 0
                  ? 'Rate: 1 USD = ${_formatNumber(rate)} SLSH'
                  : '${_formatNumber(amount!)} $fromCurrency = '
                        '${_formatNumber(convertedAmount, decimals: 2)} $toCurrency',
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

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00F080), Color(0xFF00C967)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.22),
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
          child: const SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confirm Agent Exchange',
                  style: TextStyle(
                    color: Color(0xFF062A18),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 10),
                Icon(
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
            const Text(
              'Review your exchange',
              style: TextStyle(
                color: Color(0xFFF4F7FB),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _SummaryLine(
              label: 'You exchange',
              value: '${_formatNumber(amount, decimals: 2)} $fromCurrency',
            ),
            const SizedBox(height: 11),
            _SummaryLine(
              label: 'You receive',
              value: '${_formatNumber(converted, decimals: 2)} $toCurrency',
              highlighted: true,
            ),
            const SizedBox(height: 11),
            _SummaryLine(
              label: 'Agent rate',
              value: isUsdToSlsh
                  ? '1 USD = ${_formatNumber(rate)} SLSH'
                  : '1 USD = ${_formatNumber(rate)} SLSH',
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
                    child: const Text('Cancel'),
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
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
