import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';

class AdminRatesScreen extends StatefulWidget {
  const AdminRatesScreen({super.key});

  static const routeName = '/admin_rates';

  @override
  State<AdminRatesScreen> createState() => _AdminRatesScreenState();
}

class _AdminRatesScreenState extends State<AdminRatesScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usdToSlshController;
  late final TextEditingController _slshToUsdController;

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletState>();
    _usdToSlshController = TextEditingController(
      text: wallet.usdToSlshRate.toString(),
    );
    _slshToUsdController = TextEditingController(
      text: wallet.slshToUsdRate.toString(),
    );
  }

  @override
  void dispose() {
    _usdToSlshController.dispose();
    _slshToUsdController.dispose();
    super.dispose();
  }

  String? _validateRate(String? value) {
    final rate = double.tryParse(value?.trim() ?? '');
    if (rate == null || !rate.isFinite || rate <= 0) {
      return 'Enter a rate greater than zero.';
    }
    return null;
  }

  void _publishRates() {
    if (!_formKey.currentState!.validate()) return;
    final buy = double.parse(_usdToSlshController.text.trim());
    final sell = double.parse(_slshToUsdController.text.trim());
    context.read<WalletState>().updateRates(buy, sell);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live agency spreads published.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();

    if (!wallet.isAdminUser) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Client Configuration Desk',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Container(
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
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFF00E676),
                    size: 25,
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agency rate controls',
                          style: TextStyle(
                            color: Color(0xFFF4F7FB),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Published spreads update the Sarif exchange calculations immediately.',
                          style: TextStyle(
                            color: Color(0xFFA7B0C0),
                            height: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'Active conversion figures',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            const Text(
              'Set the number of Somaliland Shillings per US Dollar for each direction.',
              style: TextStyle(color: Color(0xFF8994A6), height: 1.5),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _usdToSlshController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'USD → SLSH',
                      helperText: 'SLSH received for 1 USD.',
                      prefixIcon: Icon(Icons.trending_up_rounded),
                    ),
                    validator: _validateRate,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _slshToUsdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'SLSH → USD',
                      helperText: 'SLSH charged for 1 USD received.',
                      prefixIcon: Icon(Icons.trending_down_rounded),
                    ),
                    validator: _validateRate,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      'Currently active: ${_formatRate(wallet.usdToSlshRate)} '
                      'SLSH/USD buy · ${_formatRate(wallet.slshToUsdRate)} '
                      'SLSH/USD sell',
                      style: const TextStyle(
                        color: Color(0xFFA7B0C0),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PublishButton(onPressed: _publishRates),
                  const SizedBox(height: 15),
                  const Text(
                    'Demo configuration only: rates are stored in app memory and are not persisted to a server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8994A6),
                      fontSize: 11,
                      height: 1.5,
                    ),
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

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.onPressed});

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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.2),
            blurRadius: 19,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            height: 56,
            child: Center(
              child: Text(
                'Publish Live Agency Spreads',
                style: TextStyle(
                  color: Color(0xFF062A18),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRate(double rate) {
  final fixed = rate.toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$grouped.${parts.last}';
}
