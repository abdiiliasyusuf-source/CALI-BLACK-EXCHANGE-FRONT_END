import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/token_store.dart';
import '../services/ussd_dialer.dart';

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

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:10000',
);

class WalletState extends ChangeNotifier {
  WalletState({
    http.Client? httpClient,
    TokenStore? tokenStore,
    String baseUrl = defaultApiBaseUrl,
    this.requestTimeout = const Duration(seconds: 45),
    double usdBalance = 0,
    double slshBalance = 0,
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
    _tokenStore = tokenStore ?? InMemoryTokenStore();
    _validateBalance(usdBalance, 'usdBalance');
    _validateBalance(slshBalance, 'slshBalance');
    if (usdToSlshRate != 0) _validateRate(usdToSlshRate, 'usdToSlshRate');
    if (slshToUsdRate != 0) _validateRate(slshToUsdRate, 'slshToUsdRate');
  }

  final String baseUrl;
  final Duration requestTimeout;
  late final TokenStore _tokenStore;

  /// Called after a 401 clears the session so the UI can return to login.
  VoidCallback? onSessionExpired;
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
  String? _walletError;
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
  String? get walletError => _walletError;
  String? get ratesError => _ratesError;
  String? get transactionsError => _transactionsError;

  Future<void> fetchRates() async {
    try {
      final response = await _httpClient
          .get(_endpoint('/rates'))
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw WalletApiException(
          _responseErrorMessage(response, 'Could not load exchange rates'),
          statusCode: response.statusCode,
        );
      }

      final row = _decodeObject(response.body);
      updateRates(
        _parseRate(row['usd_to_slsh'], 'USD/SLSH'),
        _parseRate(row['slsh_to_usd'], 'SLSH/USD'),
      );
      _ratesError = null;
      notifyListeners();
    } on Exception catch (error) {
      _ratesError = 'Could not load exchange rates: $error';
      debugPrint(_ratesError);
      notifyListeners();
    }
  }

  Future<void> fetchWallet() async {
    try {
      if (!await _hasStoredToken()) return;
      final data = await _getAuthenticated('/wallet');
      final balances = data['balances'];
      if (balances is! Map<String, dynamic>) {
        throw const WalletApiException('The API returned invalid wallet balances.');
      }

      _usdBalance = _parseBalance(balances['USD'], 'USD');
      _slshBalance = _parseBalance(balances['SLSH'], 'SLSH');
      _walletError = null;
      notifyListeners();
    } on Exception catch (error) {
      _walletError = 'Could not load wallet balances: $error';
      debugPrint(_walletError);
      notifyListeners();
    }
  }

  Future<void> fetchTransactions() async {
    try {
      if (!await _hasStoredToken()) return;
      final data = await _getAuthenticated('/transactions');
      final rawRows = data['transactions'];
      if (rawRows is! List) {
        throw const WalletApiException(
          'The API returned invalid transaction history.',
        );
      }
      final rows = rawRows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw const WalletApiException(
            'The API returned an invalid transaction.',
          );
        }
        return row;
      });
      _transactions = List.unmodifiable(rows.map(_transactionFromRow));
      _transactionsError = null;
      notifyListeners();
    } on Exception catch (error) {
      _transactionsError = 'Could not load transaction history: $error';
      debugPrint(_transactionsError);
      notifyListeners();
    }
  }

  Future<void> refreshWalletData() async {
    await fetchWallet();
    await fetchTransactions();
  }

  void toggleLanguage() {
    _isSomali = !_isSomali;
    notifyListeners();
  }

  /// Registers the account and then signs in to obtain the JWT, because the
  /// register response carries no token.
  Future<bool> registerAccount({
    required String name,
    required String phone,
    required String pin,
  }) async {
    _validateRegistration(name: name, phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);

    await _postPublic('/auth/register', {
      'full_name': name.trim(),
      'phone_number': normalizedPhone,
      'pin': pin,
    }, 'Registration failed');

    await loginAccount(phone: normalizedPhone, pin: pin);
    _fullName = name.trim();
    notifyListeners();
    return true;
  }

  Future<bool> loginAccount({
    required String phone,
    required String pin,
  }) async {
    _validateLogin(phone: phone, pin: pin);
    final normalizedPhone = _normalizeSomalilandPhone(phone);

    final data = await _postPublic('/auth/login', {
      'phone_number': normalizedPhone,
      'pin': pin,
    }, 'Sign in failed. Check your details.');
    final token = data['token'];
    if (token is! String || token.trim().isEmpty) {
      throw const WalletApiException('Sign in failed. Check your details.');
    }

    final user = data['user'];
    final profile = user is Map<String, dynamic> ? user : data;
    final balances = profile['balances'];
    if (balances is! Map<String, dynamic>) {
      throw const WalletApiException('Sign in returned invalid wallet balances.');
    }
    final usdBalance = _parseBalance(balances['USD'], 'USD');
    final slshBalance = _parseBalance(balances['SLSH'], 'SLSH');
    await _tokenStore.write(token);
    _authToken = token;
    _fullName =
        (profile['full_name'] ?? profile['fullName']) as String? ??
        normalizedPhone;
    _phoneNumber =
        (profile['phone_number'] ?? profile['phoneNumber']) as String? ??
        normalizedPhone;
    _usdBalance = usdBalance;
    _slshBalance = slshBalance;
    // The backend sends `isAdmin` at the top level of the login response.
    _isAdminUser = data['isAdmin'] == true;
    notifyListeners();
    return true;
  }

  /// Clears the stored token and all signed-in state. The in-memory session is
  /// always cleared; throws [WalletApiException] if the saved token could not
  /// be removed, since it would otherwise return after a restart.
  Future<void> logout() async {
    final cleared = await _clearSession();
    if (!cleared) {
      throw const WalletApiException(
        'Signed out, but the saved login could not be removed from this device.',
      );
    }
  }

  Future<bool> _clearSession() async {
    _authToken = null;
    _fullName = null;
    _phoneNumber = null;
    _isAdminUser = false;
    _usdBalance = 0;
    _slshBalance = 0;
    _walletError = null;
    _transactionsError = null;
    _transactions = const [];
    var cleared = true;
    try {
      await _tokenStore.clear();
    } catch (_) {
      cleared = false;
    }
    notifyListeners();
    return cleared;
  }

  /// Deletes the account for the phone number so it can be registered again.
  /// The backend answers 200 even when no account exists, and 409 while a
  /// transaction is in progress.
  Future<void> resetAccount(String phone) async {
    final normalizedPhone = _normalizeSomalilandPhone(phone);
    await _postPublic('/auth/reset-account', {
      'phone_number': normalizedPhone,
    }, 'Could not reset your account');
    await _clearSession();
  }

  Future<Map<String, dynamic>> _postPublic(
    String path,
    Map<String, String> body,
    String fallbackMessage,
  ) async {
    try {
      final response = await _httpClient
          .post(
            _endpoint(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (response.statusCode == 429) {
        throw const WalletApiException(
          'Too many requests. Please wait a moment and try again.',
          statusCode: 429,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WalletApiException(
          _responseErrorMessage(response, fallbackMessage),
          statusCode: response.statusCode,
        );
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Empty or non-JSON success bodies carry no data.
      }
      return const <String, dynamic>{};
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

  Future<Map<String, dynamic>> _getAuthenticated(String path) async {
    final response = await _sendAuthenticatedRequest(
      method: 'GET',
      path: path,
      successStatuses: const {200},
      fallbackMessage: 'The request failed.',
    );
    return _decodeObject(response.body);
  }

  Future<http.Response> _sendAuthenticatedRequest({
    required String method,
    required String path,
    Map<String, Object>? body,
    required Set<int> successStatuses,
    required String fallbackMessage,
  }) async {
    final token = _authToken ?? await _tokenStore.read();
    if (token == null || token.trim().isEmpty) {
      throw const WalletApiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    try {
      final url = _endpoint(path);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final responseFuture = switch (method) {
        'GET' => _httpClient.get(url, headers: headers),
        'POST' => _httpClient.post(
          url,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'PUT' => _httpClient.put(
          url,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => throw ArgumentError.value(method, 'method', 'Unsupported HTTP method.'),
      };
      final response = await responseFuture.timeout(requestTimeout);

      if (response.statusCode == 401) {
        await _clearSession();
        onSessionExpired?.call();
        throw const WalletApiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        throw WalletApiException(
          retryAfter == null
              ? 'Too many requests. Please wait a moment and try again.'
              : 'Too many requests. Please try again in $retryAfter seconds.',
          statusCode: 429,
        );
      }
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

  Future<void> publishRates(double usdToSlsh, double slshToUsd) async {
    _validateRate(usdToSlsh, 'usdToSlsh');
    _validateRate(slshToUsd, 'slshToUsd');
    final response = await _sendAuthenticatedRequest(
      method: 'PUT',
      path: '/rates/update',
      body: {
        'usd_to_slsh': usdToSlsh,
        'slsh_to_usd': slshToUsd,
      },
      successStatuses: const {200},
      fallbackMessage: 'Could not update exchange rates.',
    );
    final rates = _decodeObject(response.body);
    updateRates(
      _parseRate(rates['usd_to_slsh'], 'USD/SLSH'),
      _parseRate(rates['slsh_to_usd'], 'SLSH/USD'),
    );
    final hadRatesError = _ratesError != null;
    _ratesError = null;
    if (hadRatesError) notifyListeners();
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

    await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/crypto/deposit',
      body: {
        'amount': amount,
        'cryptoCurrency': asset,
        'txHash': txHash.trim(),
      },
      successStatuses: const {200, 201},
      fallbackMessage: 'Crypto deposit submission failed.',
    );
    await refreshWalletData();
  }

  /// Requests an exchange; balances move only after an administrator approves it.
  Future<void> submitExchange(double amount, bool isUsdToSlsh) async {
    _validateCryptoAmount(amount);
    final response = await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/wallet/exchange',
      body: {
        'sourceCurrency': isUsdToSlsh ? 'USD' : 'SLSH',
        'amount': amount,
        'gateway': 'zaad',
      },
      successStatuses: const {201},
      fallbackMessage: 'Exchange request failed.',
    );
    final data = _decodeObject(response.body);
    final transaction = data['transaction'];
    if (transaction is! Map<String, dynamic>) {
      throw const WalletApiException(
        'The API returned an invalid exchange response.',
      );
    }
    addTransaction(_transactionFromRow(transaction));
    await refreshWalletData();
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

    await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/crypto/withdraw',
      body: {
        'amount': amount,
        'cryptoCurrency': asset,
        'destinationAddress': address.trim(),
      },
      successStatuses: const {202},
      fallbackMessage: 'Crypto withdrawal failed.',
    );

    addTransaction(
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
    );
    await refreshWalletData();
  }


  /// Alerts the cashier's Telegram group about a manual USSD deposit.
  /// [provider] is `zaad` or `edahab`.
  Future<void> sendManualDepositAlert({
    required double amount,
    required String provider,
    String? phoneNumber,
    String? referenceId,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    final phone = (phoneNumber ?? _phoneNumber ?? '').trim();
    if (phone.isEmpty) {
      throw const WalletApiException('Sign in before starting a deposit.');
    }
    final reference = referenceId?.trim();
    await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/manual-deposit-alert',
      body: {
        'phoneNumber': phone,
        'amount': amount,
        'provider': provider,
        if (reference != null && reference.isNotEmpty) 'referenceId': reference,
      },
      successStatuses: const {200, 201, 202},
      fallbackMessage: 'Could not alert the cashier',
    );
  }

  final Map<String, String> _merchantNumbers = {};

  /// Merchant number to pay for `zaad` or `edahab`: the latest value returned
  /// by the backend, otherwise the built-in default.
  String merchantNumberFor(String source) {
    final key = source.toLowerCase();
    return _merchantNumbers[key] ?? defaultMerchantNumbers[key] ?? '';
  }

  void _captureMerchantNumber(String responseBody, String fundingSource) {
    final key = fundingSource.toLowerCase();
    if (key != 'zaad' && key != 'edahab') return;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) return;
      final raw = decoded['merchantNumber'] ?? decoded['merchant_number'];
      final number = raw?.toString().trim() ?? '';
      if (RegExp(r'^\+?\d{3,15}$').hasMatch(number) &&
          _merchantNumbers[key] != number) {
        _merchantNumbers[key] = number;
        notifyListeners();
      }
    } on FormatException {
      // Keep the current number.
    }
  }

  /// Funds a 1xBet player account. [fundingSource] is the payment route the
  /// customer used (`Zaad`, `eDahab` or `Crypto`); crypto also needs the
  /// [asset] and on-chain [txHash] so the cashier can verify the payment.
  Future<String> submit1xBetDeposit({
    required String playerId,
    required double amount,
    required String fundingSource,
    String? asset,
    String? txHash,
  }) async {
    const gateway = '1xBet';
    final normalizedPlayerId = playerId.trim();
    if (!_playerIdPattern.hasMatch(normalizedPlayerId)) {
      throw ArgumentError.value(
        playerId,
        'playerId',
        'Enter a valid player account ID.',
      );
    }
    if (!amount.isFinite || amount < 0.1 || amount > 1000000) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Enter an amount from \$0.10 to \$1,000,000.',
      );
    }
    if (!const {'Zaad', 'eDahab', 'Crypto'}.contains(fundingSource)) {
      throw ArgumentError.value(
        fundingSource,
        'fundingSource',
        'Unsupported funding source.',
      );
    }
    final body = <String, Object>{
      'playerId': normalizedPlayerId,
      'amount': amount,
      'currency': 'USD',
      'fundingSource': fundingSource,
    };
    if (fundingSource == 'Crypto') {
      final hash = txHash?.trim() ?? '';
      _validateCryptoAsset(asset ?? '');
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError.value(
          txHash,
          'txHash',
          'Enter a valid 64-character transaction hash.',
        );
      }
      body['cryptoCurrency'] = asset!;
      body['txHash'] = hash;
    }

    final response = await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/deposit/1xbet',
      body: body,
      successStatuses: const {201},
      fallbackMessage: '$gateway deposit submission failed.',
    );

    _captureMerchantNumber(response.body, fundingSource);
    final transactionId = _parseTransactionId(response.body, 'pending');
    if (transactionId == null) {
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
    await refreshWalletData();
    return transactionId;
  }

  /// Requests a payout of a 1xBet withdrawal to a Zaad/eDahab number. The
  /// 1xBet balance is paid out by a cashier, so the wallet balance is untouched.
  /// Returns the transaction reference.
  Future<String> submit1xBetWithdrawal({
    required String playerId,
    required double amount,
    required String destinationPhone,
    required String fundingSource,
    required String withdrawalCode,
  }) async {
    const gateway = '1xBet';
    final normalizedPlayerId = playerId.trim();
    if (!_playerIdPattern.hasMatch(normalizedPlayerId)) {
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
    if (fundingSource != 'zaad' && fundingSource != 'edahab') {
      throw ArgumentError.value(
        fundingSource,
        'fundingSource',
        'Unsupported payout method.',
      );
    }
    final code = withdrawalCode.trim();
    if (!RegExp(r'^[A-Za-z0-9]{3,32}$').hasMatch(code)) {
      throw ArgumentError.value(
        withdrawalCode,
        'withdrawalCode',
        'Enter the withdrawal code generated by 1xBet.',
      );
    }

    final response = await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/withdrawal/1xbet',
      body: {
        'player': normalizedPlayerId,
        'amount': amount,
        'destinationPhone': _normalizeSomalilandPhone(destinationPhone),
        'fundingSource': fundingSource,
        'withdrawalCode': code,
      },
      successStatuses: const {201},
      fallbackMessage: '$gateway withdrawal submission failed.',
    );

    _captureMerchantNumber(response.body, fundingSource);
    final transactionId = _parseTransactionId(
      response.body,
      'pending_withdrawal',
    );
    if (transactionId == null) {
      throw WalletApiException(
        '$gateway returned an invalid withdrawal response.',
        statusCode: response.statusCode,
      );
    }
    addTransaction(
      WalletTransaction(
        date: DateTime.now(),
        amount: amount,
        type: TransactionType.withdrawal,
        gateway: gateway,
        status: TransactionStatus.pending,
        fromCurrency: 'USD',
        toCurrency: 'USD',
      ),
    );
    await refreshWalletData();
    return transactionId;
  }

  static final _playerIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Parses `{ success: true, transactionId, status }` from the deposit and
  /// withdrawal endpoints, requiring the given [expectedStatus].
  static String? _parseTransactionId(
    String responseBody,
    String expectedStatus,
  ) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> &&
          decoded['success'] == true &&
          decoded['status'] == expectedStatus &&
          decoded['transactionId'] is String &&
          (decoded['transactionId'] as String).trim().isNotEmpty) {
        return (decoded['transactionId'] as String).trim();
      }
    } on FormatException {
      // Falls through to null.
    }
    return null;
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
    if (asset != 'USDT_TRC20' && asset != 'USDC_POLYGON') {
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
    final amountValue = row['source_amount'] ?? row['amount'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse('$amountValue');
    if (amount == null || !amount.isFinite) {
      throw const WalletApiException(
        'The database returned a transaction with an invalid amount.',
      );
    }

    final convertedAmount = _parseOptionalNumber(
      row['destination_amount'] ?? row['converted_amount'],
    );
    final exchangeRate = _parseOptionalNumber(
      row['executed_rate'] ?? row['exchange_rate'],
    );
    return WalletTransaction(
      date:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      amount: amount,
      type: TransactionType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => TransactionType.deposit,
      ),
      gateway:
          (row['crypto_currency'] ?? row['gateway'])?.toString() ?? '',
      status: switch (statusName) {
        'completed' => TransactionStatus.completed,
        'failed' => TransactionStatus.failed,
        _ => TransactionStatus.pending,
      },
      fromCurrency:
          (row['source_currency'] ?? row['from_currency'])?.toString(),
      toCurrency:
          (row['destination_currency'] ?? row['to_currency'])?.toString(),
      exchangeRate: exchangeRate,
      convertedAmount: convertedAmount,
    );
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
    return _absoluteUri('$normalizedBaseUrl/api$path');
  }

  Uri _absoluteUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WalletApiException(
          'The API URL is not configured. Set API_BASE_URL to an absolute URL such as https://host.',
      );
    }
    return uri;
  }

  Future<bool> _hasStoredToken() async {
    final token = _authToken ?? await _tokenStore.read();
    return token != null && token.trim().isNotEmpty;
  }

  static Map<String, dynamic> _decodeObject(String body) {
    try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
        throw const WalletApiException('The API returned an invalid response.');
    }
    throw const WalletApiException('The API returned an invalid response.');
  }

  static double _parseBalance(Object? value, String currency) {
    final balance = value is num ? value.toDouble() : double.tryParse('$value');
    if (balance == null || !balance.isFinite || balance < 0) {
        throw WalletApiException('The API returned an invalid $currency balance.');
    }
    return balance;
  }

  static double? _parseOptionalNumber(Object? value) {
    if (value == null) return null;
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite) {
        throw const WalletApiException(
          'The API returned an invalid transaction amount or rate.',
        );
    }
    return number;
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

  Future<String> submitMobileMoneyDeposit({
    required double amount,
    required String gateway,
  }) async {
    if (!amount.isFinite || amount < 0.1) {
      throw ArgumentError.value(amount, 'amount', 'Must be at least 0.10 USD.');
    }
    if (gateway != 'Zaad Mobile Money' && gateway != 'eDahab Mobile Money') {
      throw ArgumentError.value(
        gateway,
        'gateway',
        'Unsupported payment method.',
      );
    }

    final phone = _phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw const WalletApiException('Sign in before starting a deposit.');
    }

    final gatewayCode = gateway == 'Zaad Mobile Money' ? 'zaad' : 'edahab';
    final response = await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/payments/$gatewayCode',
      body: {'amount': amount},
      successStatuses: const {201},
      fallbackMessage: 'Could not start the mobile money deposit.',
    );
    final data = _decodeObject(response.body);
    final transaction = data['transaction'];
    if (transaction is! Map<String, dynamic> || transaction['id'] == null) {
      throw const WalletApiException(
        'The API returned an invalid mobile money deposit response.',
      );
    }
    _captureMerchantNumber(response.body, gatewayCode);
    addTransaction(_transactionFromRow(transaction));
    await refreshWalletData();
    return transaction['id'].toString();
  }

  Future<void> markMobileMoneyDepositSubmitted({
    required String id,
    required String gateway,
  }) async {
    final gatewayCode = switch (gateway) {
      'Zaad Mobile Money' => 'zaad',
      'eDahab Mobile Money' => 'edahab',
      _ => throw ArgumentError.value(gateway, 'gateway', 'Unsupported payment method.'),
    };
    if (!RegExp(r'^[1-9]\d{0,18}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid transaction ID.');
    }
    await _sendAuthenticatedRequest(
      method: 'POST',
      path: '/payments/$gatewayCode/$id/submitted',
      body: const {},
      successStatuses: const {200},
      fallbackMessage: 'Could not confirm the mobile money payment.',
    );
    await refreshWalletData();
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
