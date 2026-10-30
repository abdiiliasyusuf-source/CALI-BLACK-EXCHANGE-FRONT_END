import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';
import 'register_screen.dart';
import 'forgot_pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passcodeController = TextEditingController();
  bool _obscurePasscode = true;
  bool _isSubmitting = false;
  bool _isLoadingDialogVisible = false;

  bool get _isSomali => context.read<WalletState>().isSomali;

  @override
  void initState() {
    super.initState();
    final phone = context.read<WalletState>().phoneNumber ?? '';
    _phoneController.text = phone.startsWith('+252')
        ? phone.substring(4)
        : phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    _showLoadingDialog(
      _isSomali
          ? 'Si ammaan ah ayaa lagu soo galayaa…'
          : 'Signing in securely…',
    );
    String? failureMessage;
    var signedIn = false;
    try {
      signedIn = await Provider.of<WalletState>(context, listen: false)
          .loginAccount(
            phone: _phoneController.text.trim(),
            pin: _passcodeController.text,
          );
    } on WalletApiException catch (error) {
      failureMessage = error.message;
    } on ArgumentError catch (error) {
      failureMessage =
          error.message?.toString() ??
          (_isSomali
              ? 'Faahfaahinta gelitaanku sax ma aha.'
              : 'Invalid sign-in details.');
    } finally {
      _hideLoadingDialog();
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    if (failureMessage != null) {
      _showError(failureMessage);
      return;
    }
    if (!signedIn) {
      _showError(
        _isSomali
            ? 'Gelitaanku wuu fashilmay. Hubi xogtaada oo mar kale isku day.'
            : 'Sign-in failed. Please check your details and try again.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.pushReplacementNamed(context, '/dashboard');
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

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return _isSomali
          ? 'Geli 9 lambar oo ka bilaabma 63 ama 65.'
          : 'Enter 9 digits starting with 63 or 65.';
    }
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(phone)) {
      return _isSomali
          ? 'Lambarku waa inuu ku bilaabmaa 63 ama 65 oo yeeshaa 9 lambar.'
          : 'Number must start with 63 or 65 and contain 9 digits.';
    }
    return null;
  }

  String? _validatePasscode(String? value) {
    final passcode = value ?? '';
    if (passcode.isEmpty) {
      return _isSomali ? 'Geli PIN-kaaga.' : 'Enter your passcode.';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(passcode)) {
      return _isSomali
          ? 'PIN-ku waa inuu ka koobnaadaa 4 lambar.'
          : 'PIN must contain exactly 4 digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LanguageToggle(
                      isSomali: wallet.isSomali,
                      onPressed: wallet.toggleLanguage,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F080), Color(0xFF00C967)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676)
                                .withValues(alpha: 0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF062A18),
                        size: 29,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    wallet.isSomali ? 'Soo dhawoow' : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFFF4F7FB),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wallet.isSomali
                        ? 'Lacagtaada, si kalsooni leh u dhaqaaqaysa.'
                        : 'Your money, moving with confidence.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xFF9BA7B7)),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26),
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
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  autofillHints: const [
                                    AutofillHints.telephoneNumberNational,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: wallet.isSomali
                                        ? 'Lambarka taleefanka'
                                        : 'Phone number',
                                    hintText: '63 000 0000',
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                  ),
                                  validator: _validatePhone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _passcodeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            obscureText: _obscurePasscode,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              labelText: wallet.isSomali
                                  ? 'PIN-ka'
                                  : 'Passcode',
                              hintText: wallet.isSomali
                                  ? 'Geli PIN-kaaga 4-lambar ah'
                                  : 'Enter your 4-digit PIN',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePasscode
                                    ? (wallet.isSomali
                                          ? 'Muuji PIN-ka'
                                          : 'Show passcode')
                                    : (wallet.isSomali
                                          ? 'Qari PIN-ka'
                                          : 'Hide passcode'),
                                onPressed: () {
                                  setState(
                                    () => _obscurePasscode = !_obscurePasscode,
                                  );
                                },
                                icon: Icon(
                                  _obscurePasscode
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: _validatePasscode,
                          ),
                          const SizedBox(height: 23),
                          _SignInButton(
                            onPressed: _isSubmitting ? null : _signIn,
                            isSubmitting: _isSubmitting,
                            label: wallet.isSomali ? 'Soo Log-in' : 'Sign in',
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Navigator.of(context)
                                    .pushNamed(ForgotPinScreen.routeName);
                              },
                              child: Text(
                                wallet.isSomali
                                    ? 'Ma illowday PIN-ka?'
                                    : 'Forgot your PIN?',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context)
                                  .pushNamed(RegisterScreen.routeName);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00E676),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(
                              wallet.isSomali
                                  ? 'Abuur Koonto Cali Black Exchange'
                                  : 'Create Cali Black Exchange Account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF00E676),
                                size: 15,
                              ),
                              SizedBox(width: 7),
                              Text(
                                wallet.isSomali
                                    ? 'Waxaa ilaaliya sirgelin ammaan ah'
                                    : 'Protected with secure encryption',
                                style: const TextStyle(
                                  color: Color(0xFF8994A6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    wallet.isSomali
                        ? 'Tijaabo — xaqiijinta waa in lagu xiraa ka hor isticmaalka.'
                        : 'Demo interface — connect authentication before production use.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF778397), height: 1.5),
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

class _SignInButton extends StatelessWidget {
  const _SignInButton({
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
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 54,
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

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.isSomali, required this.onPressed});

  final bool isSomali;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.language_rounded, size: 17),
      label: Text(isSomali ? 'Soomaali 🇸🇴' : 'English 🇬🇧'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF00E676),
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
