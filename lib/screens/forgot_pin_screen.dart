import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';
import 'register_screen.dart';

/// "Forgot PIN" is an account reset: the account is deleted and the user
/// registers again with a new PIN.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  static const routeName = '/forgot-pin';

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(value?.trim() ?? '')) {
      return context.trRead('forgotPin.phoneValidation');
    }
    return null;
  }

  Future<void> _resetAccount() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('forgotPin.resetAccount')),
        content: Text(dialogContext.tr('forgotPin.resetAccountConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('forgotPin.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr('forgotPin.resetAccount')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final wallet = context.read<WalletState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await wallet.resetAccount('+252${_phoneController.text.trim()}');
      if (!mounted) return;
      navigator.pushReplacementNamed(RegisterScreen.routeName);
    } on WalletApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ??
                context.trRead('forgotPin.invalidInput'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('forgotPin.title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF00E676),
                      size: 36,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('forgotPin.phoneDescription'),
                      style: const TextStyle(
                        color: Color(0xFFA7B0C0),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: InputDecoration(
                        labelText: context.tr('forgotPin.phoneLabel'),
                        hintText: context.tr('forgotPin.phoneHint'),
                        prefixText: '+252 ',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _resetAccount,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('forgotPin.resetAccount')),
                    ),
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
