import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  static const routeName = '/forgot-pin';

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _codeRequested = false;
  bool _isSubmitting = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(value?.trim() ?? '')) {
      return 'Enter 9 digits starting with 63 or 65.';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (!RegExp(r'^\d{4}$').hasMatch(value ?? '')) {
      return 'Enter the 4-digit verification code.';
    }
    return null;
  }

  String? _validatePin(String? value) {
    if (!RegExp(r'^\d{4}$').hasMatch(value ?? '')) {
      return 'New PIN must contain exactly 4 digits.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final wallet = context.read<WalletState>();
    final messenger = ScaffoldMessenger.of(context);
    final phone = '+252${_phoneController.text.trim()}';
    try {
      if (_codeRequested) {
        await wallet.resetPin(
          phone: phone,
          code: _codeController.text,
          newPin: _pinController.text,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('PIN reset successfully. You can now sign in.'),
          ),
        );
        Navigator.of(context).pop();
      } else {
        await wallet.requestPinReset(phone);
        if (!mounted) return;
        setState(() => _codeRequested = true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists for this number, a reset code was sent.',
            ),
          ),
        );
      }
    } on WalletApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid input.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot PIN')),
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
                      _codeRequested
                          ? 'Enter the code we sent and choose a new PIN.'
                          : 'Enter your phone number to receive a reset code.',
                      style: const TextStyle(
                        color: Color(0xFFA7B0C0),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_codeRequested && !_isSubmitting,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '63 000 0000',
                        prefixText: '+252 ',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
                    ),
                    if (_codeRequested) ...[
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          hintText: '4 digits',
                          prefixIcon: Icon(Icons.sms_outlined),
                        ),
                        validator: _validateCode,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: _obscurePin,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: 'New 4-digit PIN',
                          hintText: '••••',
                          prefixIcon: const Icon(Icons.password_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePin = !_obscurePin),
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _validatePin,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _codeRequested
                                  ? 'Confirm New PIN'
                                  : 'Send Reset Code',
                            ),
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
