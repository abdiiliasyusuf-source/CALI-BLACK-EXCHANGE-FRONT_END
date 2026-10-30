import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

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

const defaultAuthBaseUrl = String.fromEnvironment(
  'API_AUTH_BASE_URL',
  defaultValue: 'http://192.168.1.4:3000/api/auth',
);

class WalletState extends ChangeNotifier {
  WalletState({
    http.Client? httpClient,
    SupabaseService? supabaseService,
    String baseUrl = defaultAuthBaseUrl,
    this.requestTimeout = const Duration(seconds: 15),
    double usdBalance = 100,
    double slshBalance = 500000,
    double usdToSlshRate = 0,
    double slshToUsdRate = 0,
    List<WalletTransaction>? transactions,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _usdBalance = usdBalance,
       _slshBalance = slshBalance,
       _usdToSlshRate = usdToSlshRate,
       _slshToUsdRate = slshToUsdRate,
       _transactions = List.unmodifiable(transactions ?? const []) {
    _httpClient = httpClient ?? http.Client();
    _ownsHttpClient = httpClient == null;
    _supabaseService = supabaseService;
    _validateBalance(usdBalance, 'usdBalance');
    _validateBalance(slshBalance, 'slshBalance');
    if (usdToSlshRate != 0) _validateRate(usdToSlshRate, 'usdToSlshRate');
    if (slshToUsdRate != 0) _validateRate(slshToUsdRate, 'slshToUsdRate');
  }

  final String baseUrl;
  final Duration requestTimeout;
  late final SupabaseService? _supabaseService;
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
  String? _ratesError;
  String? _transactionsError;

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
  String? get ratesError => _ratesError;
  String? get transactionsError => _transactionsError;

  Future<void> fetchRates() async {
    final service = _supabaseService;
    if (service == null) {
      _ratesError = 'Supabase is not configured.';
      notifyListeners();
      return;
    }

    try {
      final row = await service.fetchLatestRates();
      if (row == null) {
        throw const WalletApiException('No exchange rates are available.');
      }

      updateRates(
        _parseRate(row['usd_to_slsh'], 'USD/SLSH'),
        _parseRate(row['slsh_to_usd'], 'SLSH/USD'),
      );
      _ratesError = null;
    } on Exception catch (error) {
      _ratesError = 'Could not load exchange rates: $error';
      debugPrint(_ratesError);
      notifyListeners();
    }
  }

  Future<void> fetchTransactions() async {
    final service = _supabaseService;
    if (service == null || service.currentUserId == null) return;

    try {
      final rows = await service.fetchTransactions();
      _transactions = List.unmodifiable(rows.map(_transactionFromRow));
      _transactionsError = null;
      notifyListeners();
    } on Exception catch (error) {
      _transactionsError = 'Could not load transaction history: $error';
      debugPrint(_transactionsError);
    }
  }

  void toggleLanguage() {
    _isSomali = !_isSomali;
    notifyListeners();
  }

  Future<void> _signOutQuietly() async {
    try {
      await _supabaseService?.signOut();
    } catch (_) {}
  }

  Future<bool> registerAccount({
    required String name,
    required String phone,
    required String pin,
  }) async {
    _validateRegistration(name: name, phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    final service = _requireSupabase();

    try {
      await service.signUpWithPhone(
        fullName: name.trim(),
        phone: normalizedPhone,
        pin: pin,
      );
      await service.signOut();
    } on AuthException catch (error) {
      throw WalletApiException(error.message);
    } on ProfileCreationException catch (error) {
      await _signOutQuietly();
      throw WalletApiException(error.message);
    } on PostgrestException catch (error) {
      await _signOutQuietly();
      throw WalletApiException('Could not save profile: ${error.message}');
    } catch (_) {
      await _signOutQuietly();
      throw WalletApiException(
        'Registration failed unexpectedly. Please try again.',
      );
    }

    _fullName = name.trim();
    _phoneNumber = normalizedPhone;
    notifyListeners();
    return true;
  }

  Future<bool> loginAccount({
    required String phone,
    required String pin,
  }) async {
    _validateLogin(phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    final service = _requireSupabase();

    try {
      final response = await service.signInWithPhone(
        phone: normalizedPhone,
        pin: pin,
      );
      final user = response.user;
      if (user == null) {
        throw const WalletApiException('Sign in failed. Check your details.');
      }

      final profile = await service.fetchProfile(user.id);
      _authToken = response.session?.accessToken;
      _fullName =
          (profile?['full_name'] as String?) ??
          (user.userMetadata?['full_name'] as String?) ??
          normalizedPhone;
      _phoneNumber = (profile?['phone_number'] as String?) ?? normalizedPhone;
      _usdBalance = _parseBalance(profile?['usd_balance'] ?? 0, 'USD');
      _slshBalance = _parseBalance(profile?['slsh_balance'] ?? 0, 'SLSH');
      _isAdminUser = profile?['is_admin'] == true;
      notifyListeners();
      await fetchTransactions();
      return true;
    } on AuthException catch (error) {
      throw WalletApiException(error.message);
    } on PostgrestException catch (error) {
      throw WalletApiException('Could not load profile: ${error.message}');
    }
  }

  SupabaseService _requireSupabase() {
    final service = _supabaseService;
    if (service == null) {
      throw const WalletApiException('Supabase is not configured.');
    }
    return service;
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

  Future<void> requestPinReset(String phone) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    await _postAuthEndpoint(
      path: '/auth/forgot-pin',
      body: {'phone_number': normalizedPhone},
      fallbackMessage: 'Could not send a reset code.',
    );
  }

  Future<void> resetPin({
    required String phone,
    required String code,
    required String newPin,
  }) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      throw ArgumentError.value(
        code,
        'code',
        'Verification code must contain exactly 4 digits.',
      );
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw ArgumentError.value(
        newPin,
        'newPin',
        'PIN must contain exactly 4 digits.',
      );
    }
    await _postAuthEndpoint(
      path: '/auth/reset-pin',
      body: {
        'phone_number': normalizedPhone,
        'otp_code': code,
        'new_pin': newPin,
      },
      fallbackMessage: 'Could not reset your PIN.',
    );
  }

  Future<void> _postAuthEndpoint({
    required String path,
    required Map<String, String> body,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _httpClient
          .post(
            _endpoint(path),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw WalletApiException(
          _responseErrorMessage(response, fallbackMessage),
          statusCode: response.statusCode,
        );
      }
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

  Future<bool> _postAuthAction({
    required String path,
    required Map<String, String> body,
    required int successStatus,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _httpClient
          .post(
            _absoluteUri('$baseUrl$path'),
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
    await _persistTransaction(
      type: 'deposit',
      amount: amount,
      gateway: asset,
      toCurrency: asset,
    );
  }

  /// Saves a transaction row for the signed-in user. A no-op when Supabase
  /// is not configured.
  Future<void> _persistTransaction({
    required String type,
    required double amount,
    required String gateway,
    String? fromCurrency,
    String? toCurrency,
  }) async {
    final service = _supabaseService;
    if (service == null) return;
    try {
      await service.insertTransaction(
        type: type,
        amount: amount,
        gateway: gateway,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        referencePhone: _phoneNumber,
      );
    } on TransactionException catch (error) {
      throw WalletApiException(error.message);
    } on Exception {
      throw const WalletApiException(
        'We could not save your transaction. Please try again.',
      );
    }
  }

  /// Executes an exchange and saves it; local balances are rolled back if
  /// the save fails.
  Future<void> submitExchange(double amount, bool isUsdToSlsh) async {
    final usd = _usdBalance;
    final slsh = _slshBalance;
    final previous = _transactions;
    executeLocalExchange(amount, isUsdToSlsh);
    try {
      await _persistTransaction(
        type: 'exchange',
        amount: amount,
        gateway: 'Sarif Exchange',
        fromCurrency: isUsdToSlsh ? 'USD' : 'SLSH',
        toCurrency: isUsdToSlsh ? 'SLSH' : 'USD',
      );
    } on WalletApiException {
      _usdBalance = usd;
      _slshBalance = slsh;
      _transactions = previous;
      notifyListeners();
      rethrow;
    }
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
    await _persistTransaction(
      type: 'withdrawal',
      amount: amount,
      gateway: asset,
      fromCurrency: 'USD',
      toCurrency: asset,
    );
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

  Future<String> submit1xBetDeposit({
    required String playerId,
    required double amount,
  }) {
    return _submitBettingDeposit(
      path: '/deposit/1xbet',
      gateway: '1xBet',
      playerId: playerId,
      amount: amount,
    );
  }

  Future<String> submitMobCashDeposit({
    required String playerId,
    required double amount,
  }) {
    return _submitBettingDeposit(
      path: '/deposit/mobcash',
      gateway: 'MobCash',
      playerId: playerId,
      amount: amount,
    );
  }

  Future<String> _submitBettingDeposit({
    required String path,
    required String gateway,
    required String playerId,
    required double amount,
  }) async {
    final normalizedPlayerId = playerId.trim();
    if (normalizedPlayerId.isEmpty || normalizedPlayerId.length > 100) {
      throw ArgumentError.value(
        playerId,
        'playerId',
        'Enter a valid player account ID.',
      );
    }
    if (!amount.isFinite || amount < 1 || amount > 1000000) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Enter an amount from \$1.00 to \$1,000,000.',
      );
    }

    final response = await _submitAuthenticatedCryptoRequest(
      path: path,
      body: {
        'playerId': normalizedPlayerId,
        'amount': amount,
        'currency': 'USD',
      },
      successStatuses: const {200, 201},
      fallbackMessage: '$gateway deposit submission failed.',
    );

    String transactionId;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['transactionId'] is! String ||
          (decoded['transactionId'] as String).trim().isEmpty ||
          decoded['status'] != 'pending') {
        throw const FormatException('Invalid deposit response.');
      }
      transactionId = (decoded['transactionId'] as String).trim();
    } on FormatException {
      throw WalletApiException(
        '$gateway returned an invalid deposit response.',
        statusCode: response.statusCode,
      );
    }

    addTransaction(
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.deposit,
        gateway: gateway,
        status: TransactionStatus.pending,
        fromCurrency: 'USD',
        toCurrency: 'USD',
      ),
    );
    return transactionId;
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

  static double _parseRate(Object? value, String currencyPair) {
    final rate = value is num ? value.toDouble() : double.tryParse('$value');
    if (rate == null || !rate.isFinite || rate <= 0) {
      throw WalletApiException(
        'The database returned an invalid $currencyPair rate.',
      );
    }
    return rate;
  }

  static WalletTransaction _transactionFromRow(Map<String, dynamic> row) {
    final typeName = row['type']?.toString();
    final statusName = row['status']?.toString();
    final amountValue = row['amount'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse('$amountValue');
    if (amount == null || !amount.isFinite) {
      throw const WalletApiException(
        'The database returned a transaction with an invalid amount.',
      );
    }

    return WalletTransaction(
      date:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      amount: amount,
      type: TransactionType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => TransactionType.deposit,
      ),
      gateway: row['gateway']?.toString() ?? '',
      status: TransactionStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => TransactionStatus.pending,
      ),
      fromCurrency: row['from_currency']?.toString(),
      toCurrency: row['to_currency']?.toString(),
      exchangeRate: (row['exchange_rate'] as num?)?.toDouble(),
      convertedAmount: (row['converted_amount'] as num?)?.toDouble(),
    );
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
    if (!executionRate.isFinite || executionRate <= 0) {
      throw StateError('A live exchange rate is not available.');
    }
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
    return _absoluteUri('$apiBaseUrl$path');
  }

  Uri _absoluteUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WalletApiException(
        'The API URL is not configured. Set API_AUTH_BASE_URL to an absolute URL such as https://host/api/auth.',
      );
    }
    return uri;
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

  Future<void> submitMobileMoneyDeposit({
    required double amount,
    required String gateway,
  }) async {
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

    final service = _supabaseService;
    if (service == null) {
      throw const WalletApiException('Supabase is not configured.');
    }
    final phone = _phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw const WalletApiException('Sign in before starting a deposit.');
    }

    try {
      await service.insertTransaction(
        type: 'deposit',
        amount: amount,
        gateway: gateway,
        fromCurrency: 'USD',
        toCurrency: 'USD',
        referencePhone: phone,
      );
    } on TransactionException catch (error) {
      throw WalletApiException(error.message);
    } on Exception {
      throw const WalletApiException(
        'We could not save your deposit. Please try again.',
      );
    }

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
}
