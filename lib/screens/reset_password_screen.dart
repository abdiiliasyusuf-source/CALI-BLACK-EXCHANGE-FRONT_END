import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const routeName = '/reset-password';

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  bool _otpRequested = false;
  bool _isSubmitting = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(value?.trim() ?? '')) {
      return context.trRead('resetPassword.phoneValidation');
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
      return context.trRead('resetPassword.otpValidation');
    }
    return null;
  }

  String? _validatePin(String? value) {
    if (!RegExp(r'^\d{4}$').hasMatch(value ?? '')) {
      return context.trRead('resetPassword.pinValidation');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    var loaderVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    context.trRead(
                      _otpRequested
                          ? 'resetPassword.updatingPin'
                          : 'resetPassword.requestingCode',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final phone = '+252${_phoneController.text.trim()}';
      if (_otpRequested) {
        await context.read<WalletState>().confirmPasswordReset(
          phone: phone,
          otpCode: _otpController.text,
          newPin: _pinController.text,
        );
      } else {
        await context.read<WalletState>().requestPasswordResetOtp(phone);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loaderVisible = false;
      if (_otpRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.trRead('resetPassword.resetSuccess'),
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        setState(() => _otpRequested = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.trRead('resetPassword.codeSent'),
            ),
          ),
        );
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
            content: Text(
              error.message?.toString() ??
                  context.trRead('resetPassword.invalidInput'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('resetPassword.title')),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(23),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1C2837), Color(0xFF141923)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_reset_rounded,
                          color: Color(0xFF00E676),
                          size: 31,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('resetPassword.recoverHeading'),
                          style: const TextStyle(
                            color: Color(0xFFF4F7FB),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('resetPassword.description'),
                          style: const TextStyle(
                            color: Color(0xFFA7B0C0),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 56,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F2633),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  '+252',
                                  style: TextStyle(
                                    color: Color(0xFFA7B0C0),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  enabled: !_otpRequested,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  decoration: InputDecoration(
                                    labelText:
                                        context.tr('resetPassword.phoneLabel'),
                                    hintText:
                                        context.tr('resetPassword.phoneHint'),
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                  ),
                                  validator: _validatePhone,
                                ),
                              ),
                            ],
                          ),
                          if (_otpRequested) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText:
                                    context.tr('resetPassword.otpLabel'),
                                hintText: context.tr('resetPassword.otpHint'),
                                prefixIcon: const Icon(Icons.sms_outlined),
                              ),
                              validator: _validateOtp,
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
                                labelText:
                                    context.tr('resetPassword.newPinLabel'),
                                hintText: '••••',
                                prefixIcon: const Icon(Icons.password_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePin = !_obscurePin,
                                  ),
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
                          _ResetActionButton(
                            isSubmitting: _isSubmitting,
                            label: context.tr(
                              _otpRequested
                                  ? 'resetPassword.confirmReset'
                                  : 'resetPassword.sendCode',
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ],
                      ),
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

class _ResetActionButton extends StatelessWidget {
  const _ResetActionButton({
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
  });

  final bool isSubmitting;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF52665B), Color(0xFF3A4A43)],
              )
            : const LinearGradient(
                colors: [Color(0xFF00F080), Color(0xFF00C967)],
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF062A18),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF062A18),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
