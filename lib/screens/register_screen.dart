import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';
import '../widgets/language_toggle.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;
  bool _isSubmitting = false;
  bool _isLoadingDialogVisible = false;
  bool _legalAccepted = false;

  Future<void> _openPrivacyPolicy() async {
    try {
      final url = Uri.parse('$defaultApiBaseUrl/api/policies/privacy');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open privacy policy')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return context.trRead('register.fullNameRequired');
    }
    if (!RegExp(
      r"^[\p{L}]+(?:[ '-][\p{L}]+)*$",
      unicode: true,
    ).hasMatch(name)) {
      return context.trRead('register.fullNameCharacters');
    }
    if (name.replaceAll(RegExp(r"[^ \p{L}]", unicode: true), '').length < 2) {
      return context.trRead('register.fullNameMin');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return context.trRead('register.phoneRequired');
    }
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(phone)) {
      return context.trRead('register.phoneInvalid');
    }
    return null;
  }

  String? _validatePin(String? value) {
    final pin = value ?? '';
    if (pin.isEmpty) {
      return context.trRead('register.pinRequired');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return context.trRead('register.pinInvalid');
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_legalAccepted) {
      _showError(context.trRead('register.acceptLegal'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    _showLoadingDialog(context.trRead('register.loading'));
    String? failureMessage;
    var created = false;
    try {
      created = await Provider.of<WalletState>(context, listen: false)
          .registerAccount(
            name: _fullNameController.text.trim(),
            phone: '+252${_phoneController.text.trim()}',
            pin: _pinController.text,
          );
    } on WalletApiException catch (error) {
      failureMessage = error.message;
    } on ArgumentError catch (error) {
      failureMessage =
          error.message?.toString() ??
          (mounted ? context.trRead('register.invalidDetails') : '');
    } finally {
      _hideLoadingDialog();
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    if (failureMessage != null) {
      _showError(failureMessage);
      return;
    }
    if (!created) {
      _showError(context.trRead('register.failed'));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.trRead('register.success'))));
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(DashboardScreen.routeName, (route) => false);
  }

  void _showLoadingDialog(String message) {
    FocusScope.of(context).unfocus();
    _isLoadingDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (context) => _ProcessingDialog(message: message),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (!_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('register.title'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: const LanguageToggleButton(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1C2837), Color(0xFF141923)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFF00E676),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 19),
                        Text(
                          context.tr('register.formTitle'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFFF4F7FB),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('register.subtitle'),
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
                          TextFormField(
                            controller: _fullNameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: InputDecoration(
                              labelText: context.tr('register.fullNameLabel'),
                              hintText: context.tr('register.fullNameHint'),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: _validateFullName,
                          ),
                          const SizedBox(height: 18),
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
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumberNational,
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: context.tr(
                                      'register.phoneLabel',
                                    ),
                                    hintText: context.tr('register.phoneHint'),
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                    helperText: context.tr(
                                      'register.phoneStarts',
                                      {'count': _phoneController.text.length},
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: _validatePhone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            obscureText: _obscurePin,
                            autofillHints: const [AutofillHints.newPassword],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onFieldSubmitted: (_) => _register(),
                            decoration: InputDecoration(
                              labelText: context.tr('register.pinLabel'),
                              hintText: context.tr('register.pinHint'),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              helperText: context.tr('register.pinCount', {
                                'count': _pinController.text.length,
                              }),
                              suffixIcon: IconButton(
                                tooltip: context.tr(
                                  _obscurePin
                                      ? 'register.showPin'
                                      : 'register.hidePin',
                                ),
                                onPressed: () {
                                  setState(() => _obscurePin = !_obscurePin);
                                },
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: _validatePin,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(
                              () => _legalAccepted = !_legalAccepted,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2633),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _legalAccepted
                                      ? const Color(0xFF00E676)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _legalAccepted,
                                    onChanged: (accepted) => setState(
                                      () => _legalAccepted = accepted ?? false,
                                    ),
                                    activeColor: const Color(0xFF00E676),
                                    checkColor: const Color(0xFF062A18),
                                    side: const BorderSide(
                                      color: Color(0xFF8994A6),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'I agree to the ',
                                              style: TextStyle(
                                                color: Color(0xFFD5DCE6),
                                                height: 1.4,
                                                fontSize: 12,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'ALI BLACK Exchange Privacy Policy',
                                              style: const TextStyle(
                                                color: Color(0xFF00E676),
                                                height: 1.4,
                                                fontSize: 12,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = _openPrivacyPolicy,
                                            ),
                                            const TextSpan(
                                              text: '.',
                                              style: TextStyle(
                                                color: Color(0xFFD5DCE6),
                                                height: 1.4,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _RegisterButton(
                            onPressed: _isSubmitting || !_legalAccepted
                                ? null
                                : _register,
                            isSubmitting: _isSubmitting,
                            label: context.tr('register.createButton'),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.tr('register.pinReminder'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8994A6),
                              fontSize: 11,
                              height: 1.5,
                            ),
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

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF4F7FB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({
    required this.onPressed,
    required this.isSubmitting,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool isSubmitting;
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
          child: SizedBox(
            height: 56,
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
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
