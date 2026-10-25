import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';
import 'login_screen.dart';

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
  final _otpController = TextEditingController();
  bool _obscurePin = true;
  bool _isSubmitting = false;
  bool _isLoadingDialogVisible = false;
  bool _otpRequested = false;
  bool _legalAccepted = false;

  bool get _isSomali => context.read<WalletState>().isSomali;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return _isSomali ? 'Geli magacaaga oo buuxa.' : 'Enter your full name.';
    }
    if (!RegExp(
      r"^[\p{L}]+(?:[ '-][\p{L}]+)*$",
      unicode: true,
    ).hasMatch(name)) {
      return _isSomali
          ? 'Isticmaal xarfo, firaaqo, hakad, ama jiitin oo keliya.'
          : 'Use letters, spaces, apostrophes, or hyphens only.';
    }
    if (name.replaceAll(RegExp(r"[^ \p{L}]", unicode: true), '').length < 2) {
      return _isSomali
          ? 'Magacu waa inuu ka koobnaadaa ugu yaraan laba xaraf.'
          : 'Name must contain at least two letters.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return _isSomali
          ? 'Geli lambarka taleefankaaga.'
          : 'Enter your mobile money phone number.';
    }
    if (!RegExp(r'^(63|65)\d{7}$').hasMatch(phone)) {
      return _isSomali
          ? 'Lambarku waa inuu ku bilaabmaa 63 ama 65 oo yeeshaa 9 lambar.'
          : 'Number must start with 63 or 65 and contain 9 digits.';
    }
    return null;
  }

  String? _validatePin(String? value) {
    final pin = value ?? '';
    if (pin.isEmpty) {
      return _isSomali ? 'Samee PIN ammaan ah oo 4-lambar ah.' : 'Create your secure 4-digit PIN.';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return _isSomali
          ? 'PIN-ku waa inuu ka koobnaadaa 4 lambar.'
          : 'PIN must contain exactly 4 digits.';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    final otp = value ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return _isSomali
          ? 'Geli koodhka SMS-ka oo ka kooban 6 lambar.'
          : 'Enter the 6-digit SMS code.';
    }
    return null;
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_legalAccepted) {
      _showError(
        _isSomali
            ? 'Aqbal siyaasadda asturnaanta iyo xeerka ka-hortagga lacag-dhaqidda.'
            : 'Accept the Privacy Policy and Anti-Money Laundering Framework to continue.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    _showLoadingDialog(
      _isSomali ? 'Koodhka SMS-ka ayaa la dirayaa…' : 'Sending SMS code…',
    );
    String? failureMessage;
    var sent = false;
    try {
      sent = await context.read<WalletState>().requestSmsOtp(
        '+252${_phoneController.text.trim()}',
      );
    } on WalletApiException catch (error) {
      failureMessage = error.message;
    } on ArgumentError catch (error) {
      failureMessage = error.message?.toString() ??
          (_isSomali ? 'Lambarka taleefanku sax ma aha.' : 'Invalid phone number.');
    } finally {
      _hideLoadingDialog();
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    if (failureMessage != null) {
      _showError(failureMessage);
      return;
    }
    if (!sent) {
      _showError(
        _isSomali
            ? 'Koodhka lama diri karin. Mar kale isku day.'
            : 'Could not send the verification code. Try again.',
      );
      return;
    }
    setState(() => _otpRequested = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSomali
              ? 'Koodhka xaqiijinta waxaa loo diray SMS.'
              : 'Verification code sent by SMS.',
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_legalAccepted) {
      _showError(
        _isSomali
            ? 'Aqbal siyaasadda asturnaanta iyo xeerka ka-hortagga lacag-dhaqidda.'
            : 'Accept the Privacy Policy and Anti-Money Laundering Framework to continue.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    _showLoadingDialog(
      _isSomali ? 'Koontada waa la abuurayaa…' : 'Creating your account…',
    );
    String? failureMessage;
    var created = false;
    try {
      created = await Provider.of<WalletState>(context, listen: false)
          .registerAccount(
            name: _fullNameController.text.trim(),
            phone: '+252${_phoneController.text.trim()}',
            pin: _pinController.text,
            otpCode: _otpController.text,
          );
    } on WalletApiException catch (error) {
      failureMessage = error.message;
    } on ArgumentError catch (error) {
      failureMessage = error.message?.toString() ??
          (_isSomali ? 'Faahfaahinta koontadu sax ma aha.' : 'Invalid account details.');
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
      _showError(
        _isSomali
            ? 'Diiwaangelintu way fashilantay. Mar kale isku day.'
            : 'Registration failed. Please try again.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSomali
              ? 'Koontada waa la abuuray. Fadlan soo gal.'
              : 'Your account was created successfully. Please sign in.',
        ),
      ),
    );
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  void _showLoadingDialog(String message) {
    FocusScope.of(context).unfocus();
    _isLoadingDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (context) =>
            _ProcessingDialog(message: message),
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
    final wallet = context.watch<WalletState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          wallet.isSomali ? 'Abuur koonto' : 'Create account',
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
                    child: TextButton.icon(
                      onPressed: wallet.toggleLanguage,
                      icon: const Icon(Icons.language_rounded, size: 17),
                      label: Text(
                        wallet.isSomali ? 'Soomaali 🇸🇴' : 'English 🇬🇧',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00E676),
                        backgroundColor: const Color(0xFF161B26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
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
                          wallet.isSomali
                              ? 'Abuur Koonto Cali Black Exchange'
                              : 'Create Cali Black Exchange Account',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFFF4F7FB),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          wallet.isSomali
                              ? 'Samee xogtaada ammaan ah si aad u maamusho boorsadaada.'
                              : 'Set up your secure profile to manage your wallet.',
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
                              labelText: wallet.isSomali
                                  ? 'Magaca oo buuxa'
                                  : 'Full Name',
                              hintText: wallet.isSomali
                                  ? 'Geli magacaaga oo buuxa'
                                  : 'Enter your full name',
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
                                    labelText: wallet.isSomali
                                        ? 'Lambarka taleefanka'
                                        : 'Phone Number',
                                    hintText: '63 000 0000',
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                    helperText:
                                        '${_phoneController.text.length}/9 · ${wallet.isSomali ? 'ku bilow 63 ama 65' : 'starts with 63 or 65'}',
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
                            onFieldSubmitted: (_) =>
                                _otpRequested ? _register() : _requestOtp(),
                            decoration: InputDecoration(
                              labelText: wallet.isSomali
                                  ? 'PIN ammaan ah oo 4-lambar ah'
                                  : 'Secure 4-Digit PIN',
                              hintText: wallet.isSomali
                                  ? 'Samee PIN afar-lambar ah'
                                  : 'Create a four-digit PIN',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              helperText:
                                  wallet.isSomali
                                      ? '${_pinController.text.length}/4 lambar'
                                      : '${_pinController.text.length}/4 digits',
                              suffixIcon: IconButton(
                                tooltip: _obscurePin
                                    ? (wallet.isSomali ? 'Muuji PIN-ka' : 'Show PIN')
                                    : (wallet.isSomali ? 'Qari PIN-ka' : 'Hide PIN'),
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
                          if (_otpRequested) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText: wallet.isSomali
                                    ? 'Geli Lambarka OTP-ga'
                                    : 'Enter SMS Code',
                                hintText: wallet.isSomali
                                    ? 'Koodh 6-lambar ah'
                                    : '6-digit code',
                                prefixIcon: const Icon(Icons.sms_outlined),
                                helperText: wallet.isSomali
                                    ? 'Koodhka SMS-ku wuxuu dhacayaa 5 daqiiqo gudahood.'
                                    : 'The SMS code expires in 5 minutes.',
                              ),
                              onFieldSubmitted: (_) => _register(),
                              validator: _otpRequested ? _validateOtp : null,
                            ),
                          ],
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
                                      child: Text(
                                        wallet.isSomali
                                            ? 'Waxaan aqbalayaa Siyaasadda Asturnaanta Cali Black Exchange iyo Qaab-dhismeedka Ka-hortagga Lacag-dhaqidda.'
                                            : 'I agree to the Cali Black Exchange Privacy Policy and Anti-Money Laundering Framework.',
                                        style: const TextStyle(
                                          color: Color(0xFFD5DCE6),
                                          height: 1.4,
                                          fontSize: 12,
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
                            onPressed: _isSubmitting
                                || !_legalAccepted
                                ? null
                                : _otpRequested
                                ? _register
                                : _requestOtp,
                            isSubmitting: _isSubmitting,
                            label: _otpRequested
                                ? (wallet.isSomali
                                      ? 'Xaqiiji & Abuur Koonto'
                                      : 'Confirm & Create Account')
                                : (wallet.isSomali
                                      ? 'Dir Lambarka Hubinta'
                                      : 'Send Verification Code'),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            wallet.isSomali
                                ? 'PIN-kaagu wuxuu ilaaliyaa koontadaada. Qofna ha la wadaagin.'
                                : 'Your PIN is used to secure your account. Never share it.',
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
