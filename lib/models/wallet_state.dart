import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum TransactionType { deposit, withdrawal, exchange }

enum TransactionStatus { completed, pending, failed }

class WalletApiException implements Exception {
  const WalletApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

@immutable
class WalletTransaction {
  const WalletTransaction({
    required this.date,
    required this.amount,
    required this.type,
    required this.gateway,
    required this.status,
    this.fromCurrency,
    this.toCurrency,
    this.exchangeRate,
    this.convertedAmount,
  });

  final DateTime date;
  final double amount;
  final TransactionType type;
  final String gateway;
  final TransactionStatus status;
  final String? fromCurrency;
  final String? toCurrency;
  final double? exchangeRate;
  final double? convertedAmount;
}

class WalletState extends ChangeNotifier {
  WalletState({
    http.Client? httpClient,
    String baseUrl = const String.fromEnvironment(
      'API_AUTH_BASE_URL',
      defaultValue: 'http://192.168.1.4:3000/api/auth',
    ),
    this.requestTimeout = const Duration(seconds: 15),
    double usdBalance = 100,
    double slshBalance = 500000,
    double usdToSlshRate = 8500,
    double slshToUsdRate = 8500,
    List<WalletTransaction>? transactions,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _usdBalance = usdBalance,
       _slshBalance = slshBalance,
       _usdToSlshRate = usdToSlshRate,
       _slshToUsdRate = slshToUsdRate,
       _transactions = List.unmodifiable(transactions ?? _demoTransactions()) {
    _httpClient = httpClient ?? http.Client();
    _ownsHttpClient = httpClient == null;
    _validateBalance(usdBalance, 'usdBalance');
    _validateBalance(slshBalance, 'slshBalance');
    _validateRate(usdToSlshRate, 'usdToSlshRate');
    _validateRate(slshToUsdRate, 'slshToUsdRate');
  }

  final String baseUrl;
  final Duration requestTimeout;
  late final http.Client _httpClient;
  late final bool _ownsHttpClient;
  double _usdBalance;
  double _slshBalance;
  double _usdToSlshRate;
  double _slshToUsdRate;
  bool _isAdminUser = false;
  String? _authToken;
  String? _fullName;
  String? _phoneNumber;
  List<WalletTransaction> _transactions;
  bool _isSomali = false;

  double get usdBalance => _usdBalance;
  double get slshBalance => _slshBalance;
  double get usdToSlshRate => _usdToSlshRate;
  double get slshToUsdRate => _slshToUsdRate;
  bool get isAdminUser => _isAdminUser;
  String? get authToken => _authToken;
  String? get fullName => _fullName;
  String? get phoneNumber => _phoneNumber;
  List<WalletTransaction> get transactions => _transactions;
  bool get isSomali => _isSomali;

  void toggleLanguage() {
    _isSomali = !_isSomali;
    notifyListeners();
  }

  Future<bool> requestSmsOtp(String phone) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/request-otp'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'phone_number': normalizedPhone}),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw WalletApiException(
          _responseErrorMessage(response, 'Could not send verification code.'),
          statusCode: response.statusCode,
        );
      }
      return true;
    } on WalletApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw WalletApiException(
        'Could not connect to the API: ${error.message}',
      );
    } on TimeoutException {
      throw const WalletApiException('The API request timed out. Try again.');
    } on FormatException {
      throw const WalletApiException(
        'The API returned an invalid verification response.',
      );
    }
  }

  Future<bool> registerAccount({
    required String name,
    required String phone,
    required String pin,
    required String otpCode,
  }) async {
    _validateRegistration(name: name, phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    if (!RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      throw ArgumentError.value(
        otpCode,
        'otpCode',
        'Verification code must contain exactly 6 digits.',
      );
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/verify-register'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'full_name': name.trim(),
              'phone_number': normalizedPhone,
              'pin': pin,
              'otp_code': otpCode,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 201) {
        throw WalletApiException(
          _responseErrorMessage(response, 'Account registration failed.'),
          statusCode: response.statusCode,
        );
      }

      _fullName = name.trim();
      _phoneNumber = normalizedPhone;
      notifyListeners();
      return true;
    } on WalletApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw WalletApiException(
        'Could not connect to the API: ${error.message}',
      );
    } on TimeoutException {
      throw const WalletApiException('The API request timed out. Try again.');
    } on FormatException {
      throw const WalletApiException(
        'The API returned an invalid registration response.',
      );
    }
  }

  Future<bool> loginAccount({
    required String phone,
    required String pin,
  }) async {
    _validateLogin(phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': normalizedPhone, 'pin': pin}),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw WalletApiException(
          _responseErrorMessage(
            response,
            'Sign in failed. Check your details.',
          ),
          statusCode: response.statusCode,
        );
      }

      final profile = _parseLoginResponse(response.body);
      _authToken = profile.token;
      _fullName = profile.fullName;
      _phoneNumber = profile.phoneNumber ?? normalizedPhone;
      _usdBalance = profile.usdBalance;
      _slshBalance = profile.slshBalance;
      _isAdminUser = profile.isAdminUser;
      notifyListeners();
      return true;
    } on WalletApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw WalletApiException(
        'Could not connect to the API: ${error.message}',
      );
    } on TimeoutException {
      throw const WalletApiException('The API request timed out. Try again.');
    } on FormatException {
      throw const WalletApiException('The API returned invalid JSON.');
    }
  }

  Future<bool> requestPasswordResetOtp(String phone) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    return _postAuthAction(
      path: '/reset-otp',
      body: {'phone_number': normalizedPhone},
      successStatus: 200,
      fallbackMessage: 'Could not request a password reset code.',
    );
  }

  Future<bool> confirmPasswordReset({
    required String phone,
    required String otpCode,
    required String newPin,
  }) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    if (!RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      throw ArgumentError.value(
        otpCode,
        'otpCode',
        'Verification code must contain exactly 6 digits.',
      );
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw ArgumentError.value(
        newPin,
        'newPin',
        'PIN must contain exactly 4 digits.',
      );
    }
    return _postAuthAction(
      path: '/confirm-reset',
      body: {
        'phone_number': normalizedPhone,
        'otp_code': otpCode,
        'new_pin': newPin,
      },
      successStatus: 200,
      fallbackMessage: 'Could not reset your PIN.',
    );
  }

  Future<bool> _postAuthAction({
    required String path,
    required Map<String, String> body,
    required int successStatus,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (response.statusCode != successStatus) {
        throw WalletApiException(
          _responseErrorMessage(response, fallbackMessage),
          statusCode: response.statusCode,
        );
      }
      return true;
    } on WalletApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw WalletApiException(
        'Could not connect to the API: ${error.message}',
      );
    } on TimeoutException {
      throw const WalletApiException('The API request timed out. Try again.');
    } on FormatException {
      throw const WalletApiException('The API returned invalid JSON.');
    }
  }

  Future<void> submitCryptoDeposit({
    required double amount,
    required String asset,
    required String txHash,
  }) async {
    _validateCryptoAmount(amount);
    _validateCryptoAsset(asset);
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(txHash.trim())) {
      throw ArgumentError.value(
        txHash,
        'txHash',
        'Enter a valid 64-character transaction hash.',
      );
    }

    final response = await _submitAuthenticatedCryptoRequest(
      path: '/crypto/deposit',
      body: {
        'amount': amount,
        'cryptoCurrency': asset,
        'txHash': txHash.trim(),
      },
      successStatuses: const {200, 201},
      fallbackMessage: 'Crypto deposit submission failed.',
    );

    _transactions = List.unmodifiable([
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.deposit,
        gateway: asset,
        status: TransactionStatus.pending,
        toCurrency: asset,
        convertedAmount: amount,
      ),
      ..._transactions,
    ]);
    notifyListeners();
    debugPrint(
      'Crypto deposit recorded for approval: HTTP ${response.statusCode}',
    );
  }

  Future<void> submitCryptoWithdrawal({
    required double amount,
    required String asset,
    required String address,
  }) async {
    _validateCryptoAmount(amount);
    _validateCryptoAsset(asset);
    if (!_isValidCryptoAddress(address.trim(), asset)) {
      throw ArgumentError.value(
        address,
        'address',
        'Enter a valid destination address for $asset.',
      );
    }
    if (amount > _usdBalance) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Withdrawal amount exceeds your available USD balance.',
      );
    }

    await _submitAuthenticatedCryptoRequest(
      path: '/crypto/withdraw',
      body: {
        'amount': amount,
        'cryptoCurrency': asset,
        'destinationAddress': address.trim(),
      },
      successStatuses: const {200},
      fallbackMessage: 'Crypto withdrawal failed.',
    );

    _usdBalance -= amount;
    _transactions = List.unmodifiable([
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.withdrawal,
        gateway: asset,
        status: TransactionStatus.pending,
        fromCurrency: 'USD',
        toCurrency: asset,
        convertedAmount: amount,
      ),
      ..._transactions,
    ]);
    notifyListeners();
  }

  Future<http.Response> _submitAuthenticatedCryptoRequest({
    required String path,
    required Map<String, Object> body,
    required Set<int> successStatuses,
    required String fallbackMessage,
  }) async {
    final token = _authToken;
    if (token == null || token.trim().isEmpty) {
      throw const WalletApiException(
        'Your session has expired. Please sign in again.',
      );
    }

    try {
      final response = await _httpClient
          .post(
            _endpoint(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (!successStatuses.contains(response.statusCode)) {
        throw WalletApiException(
          _responseErrorMessage(response, fallbackMessage),
          statusCode: response.statusCode,
        );
      }
      return response;
    } on WalletApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw WalletApiException(
        'Could not connect to the API: ${error.message}',
      );
    } on TimeoutException {
      throw const WalletApiException('The API request timed out. Try again.');
    }
  }

  static void _validateCryptoAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be a finite value greater than zero.',
      );
    }
  }

  static void _validateCryptoAsset(String asset) {
    if (asset != 'USDT_TRC20' && asset != 'USDC_BEP20') {
      throw ArgumentError.value(asset, 'asset', 'Unsupported crypto asset.');
    }
  }

  static bool _isValidCryptoAddress(String address, String asset) {
    if (asset == 'USDT_TRC20') {
      return RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address);
    }
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
  }

  void updateRates(double buy, double sell) {
    _validateRate(buy, 'buy');
    _validateRate(sell, 'sell');
    if (_usdToSlshRate == buy && _slshToUsdRate == sell) return;
    _usdToSlshRate = buy;
    _slshToUsdRate = sell;
    notifyListeners();
  }

  void executeLocalExchange(double amount, bool isUsdToSlsh) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be finite and greater than zero.',
      );
    }

    final fromCurrency = isUsdToSlsh ? 'USD' : 'SLSH';
    final toCurrency = isUsdToSlsh ? 'SLSH' : 'USD';
    final availableBalance = isUsdToSlsh ? _usdBalance : _slshBalance;
    if (amount > availableBalance) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Exceeds the available $fromCurrency balance.',
      );
    }

    final executionRate = isUsdToSlsh ? _usdToSlshRate : _slshToUsdRate;
    final convertedAmount = isUsdToSlsh
        ? amount * executionRate
        : amount / executionRate;
    if (!convertedAmount.isFinite || convertedAmount <= 0) {
      throw StateError('The exchange result is outside the supported range.');
    }

    if (isUsdToSlsh) {
      _usdBalance -= amount;
      _slshBalance += convertedAmount;
    } else {
      _slshBalance -= amount;
      _usdBalance += convertedAmount;
    }
    _transactions = List.unmodifiable([
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.exchange,
        gateway: 'Sarif Exchange',
        status: TransactionStatus.completed,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        exchangeRate: executionRate,
        convertedAmount: convertedAmount,
      ),
      ..._transactions,
    ]);
    notifyListeners();
  }

  void setPhoneNumber(String phoneNumber) {
    if (_phoneNumber == phoneNumber) return;
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }

  Uri _endpoint(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final apiBaseUrl = normalizedBaseUrl.endsWith('/auth')
        ? normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 5)
        : normalizedBaseUrl;
    return Uri.parse('$apiBaseUrl$path');
  }

  void _validateRegistration({
    required String name,
    required String phone,
    required String pin,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty ||
        !RegExp(
          r"^[\p{L}]+(?:[ '-][\p{L}]+)*$",
          unicode: true,
        ).hasMatch(normalizedName)) {
      throw ArgumentError.value(name, 'name', 'Enter a valid full name.');
    }
    if (!_isValidSomalilandPhone(phone)) {
      throw ArgumentError.value(
        phone,
        'phone',
        'Enter 9 digits starting with 63 or 65.',
      );
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(
        pin,
        'pin',
        'PIN must contain exactly 4 digits.',
      );
    }
  }

  void _validateLogin({required String phone, required String pin}) {
    if (!_isValidSomalilandPhone(phone)) {
      throw ArgumentError.value(
        phone,
        'phone',
        'Enter 9 digits starting with 63 or 65.',
      );
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(
        pin,
        'pin',
        'PIN must contain exactly 4 digits.',
      );
    }
  }

  static bool _isValidSomalilandPhone(String phone) {
    final value = phone.trim();
    return RegExp(r'^(?:\+252)?(?:63|65)\d{7}$').hasMatch(value);
  }

  static String _normalizeSomalilandPhone(String phone) {
    final value = phone.trim();
    if (!_isValidSomalilandPhone(value)) {
      throw ArgumentError.value(
        phone,
        'phone',
        'Enter 9 digits starting with 63 or 65.',
      );
    }
    final localNumber = value.startsWith('+252') ? value.substring(4) : value;
    return '+252$localNumber';
  }

  _LoginProfile _parseLoginResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const WalletApiException(
        'The API returned an invalid login response.',
      );
    }

    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    final token =
        data['token'] ??
        data['access_token'] ??
        data['accessToken'] ??
        decoded['token'];
    final name =
        user['full_name'] ??
        user['fullName'] ??
        user['name'] ??
        user['username'];
    final phone = user['phone_number'] ?? user['phoneNumber'];
    final balances = user['balances'] is Map<String, dynamic>
        ? user['balances'] as Map<String, dynamic>
        : data['balances'] is Map<String, dynamic>
        ? data['balances'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final usd =
        user['usd_balance'] ??
        user['usdBalance'] ??
        data['usd_balance'] ??
        data['usdBalance'] ??
        balances['USD'] ??
        balances['usd'];
    final slsh =
        user['slsh_balance'] ??
        user['slshBalance'] ??
        data['slsh_balance'] ??
        data['slshBalance'] ??
        balances['SLSH'] ??
        balances['slsh'];
    final isAdmin =
        user['isAdmin'] ??
        user['is_admin'] ??
        data['isAdmin'] ??
        data['is_admin'] ??
        decoded['isAdmin'] ??
        decoded['is_admin'] ??
        false;

    if (token is! String || token.trim().isEmpty) {
      throw const WalletApiException(
        'The API response is missing a valid token.',
      );
    }
    if (name is! String || name.trim().isEmpty) {
      throw const WalletApiException(
        'The API response is missing the account name.',
      );
    }
    if (isAdmin is! bool) {
      throw const WalletApiException(
        'The API response contains an invalid admin role.',
      );
    }

    return _LoginProfile(
      token: token,
      fullName: name.trim(),
      phoneNumber: phone is String ? phone : null,
      usdBalance: _parseBalance(usd, 'USD'),
      slshBalance: _parseBalance(slsh, 'SLSH'),
      isAdminUser: isAdmin,
    );
  }

  static double _parseBalance(Object? value, String currency) {
    final balance = value is num ? value.toDouble() : double.tryParse('$value');
    if (balance == null || !balance.isFinite || balance < 0) {
      throw WalletApiException(
        'The API response contains an invalid $currency balance.',
      );
    }
    return balance;
  }

  String _responseErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return '$fallback (HTTP ${response.statusCode}).';
    }
    return '$fallback (HTTP ${response.statusCode}).';
  }

  void addTransaction(WalletTransaction transaction) {
    _transactions = List.unmodifiable([transaction, ..._transactions]);
    notifyListeners();
  }

  void submitMobileMoneyDeposit({
    required double amount,
    required String gateway,
  }) {
    if (!amount.isFinite || amount < 1) {
      throw ArgumentError.value(amount, 'amount', 'Must be at least 1 USD.');
    }
    if (gateway != 'Zaad Mobile Money' && gateway != 'eDahab Mobile Money') {
      throw ArgumentError.value(
        gateway,
        'gateway',
        'Unsupported payment method.',
      );
    }

    debugPrint(
      'Mobile money deposit request: '
      'amount=\$${amount.toStringAsFixed(2)} USD, gateway=$gateway',
    );
    addTransaction(
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.deposit,
        gateway: gateway,
        status: TransactionStatus.pending,
      ),
    );
  }

  static void _validateBalance(double balance, String name) {
    if (!balance.isFinite || balance < 0) {
      throw ArgumentError.value(
        balance,
        name,
        'Must be finite and non-negative.',
      );
    }
  }

  static void _validateRate(double rate, String name) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(
        rate,
        name,
        'Must be finite and greater than zero.',
      );
    }
  }

  static List<WalletTransaction> _demoTransactions() {
    final now = DateTime.now();
    return [
      WalletTransaction(
        date: now.subtract(const Duration(hours: 2)),
        amount: 250,
        type: TransactionType.deposit,
        gateway: 'Zaad',
        status: TransactionStatus.completed,
      ),
      WalletTransaction(
        date: now.subtract(const Duration(days: 1)),
        amount: 75,
        type: TransactionType.withdrawal,
        gateway: 'eDahab',
        status: TransactionStatus.completed,
      ),
      WalletTransaction(
        date: now.subtract(const Duration(days: 3)),
        amount: 100,
        type: TransactionType.deposit,
        gateway: 'eDahab',
        status: TransactionStatus.completed,
      ),
    ];
  }
}

class _LoginProfile {
  const _LoginProfile({
    required this.token,
    required this.fullName,
    required this.phoneNumber,
    required this.usdBalance,
    required this.slshBalance,
    required this.isAdminUser,
  });

  final String token;
  final String fullName;
  final String? phoneNumber;
  final double usdBalance;
  final double slshBalance;
  final bool isAdminUser;
}
