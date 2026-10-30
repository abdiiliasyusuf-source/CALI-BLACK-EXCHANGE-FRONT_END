import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cali_black_exchange_frontend/main.dart';
import 'package:cali_black_exchange_frontend/models/wallet_state.dart';
import 'package:cali_black_exchange_frontend/screens/admin_rates_screen.dart';
import 'package:cali_black_exchange_frontend/screens/dashboard_screen.dart';
import 'package:cali_black_exchange_frontend/screens/deposit_screen.dart';
import 'package:cali_black_exchange_frontend/screens/exchange_screen.dart';
import 'package:cali_black_exchange_frontend/screens/login_screen.dart';
import 'package:cali_black_exchange_frontend/screens/register_screen.dart';
import 'package:cali_black_exchange_frontend/screens/forgot_pin_screen.dart';
import 'package:cali_black_exchange_frontend/screens/withdrawal_screen.dart';
import 'package:cali_black_exchange_frontend/services/supabase_service.dart';

const _authBaseUrl = 'http://192.168.1.4:3000/api/auth';

AuthResponse _authResponse({String? token = 'test-token', bool user = true}) {
  final authUser = user
      ? const User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {'full_name': 'Metadata Name'},
          aud: 'authenticated',
          createdAt: '2024-01-01T00:00:00Z',
        )
      : null;
  return AuthResponse(
    session: token == null || authUser == null
        ? null
        : Session(accessToken: token, tokenType: 'bearer', user: authUser),
    user: authUser,
  );
}

class _FakeSupabaseService implements SupabaseService {
  _FakeSupabaseService({
    this.signInResult,
    this.signInError,
    this.signUpError,
    this.profile = const {
      'full_name': 'Ada Lovelace',
      'phone_number': '+252631234567',
      'usd_balance': 100,
      'slsh_balance': 500000,
    },
    this.signInGate,
    this.resetError,
  });

  AuthResponse? signInResult;
  final Object? signInError;
  final Object? signUpError;
  final Map<String, dynamic>? profile;
  final Future<void>? signInGate;
  final Object? resetError;
  final resetCodeRequests = <String>[];
  final pinResets = <Map<String, String>>[];
  final signUps = <Map<String, String>>[];
  var signOutCount = 0;

  @override
  Future<void> signUpWithPhone({
    required String fullName,
    required String phone,
    required String pin,
  }) async {
    final error = signUpError;
    if (error != null) throw error;
    signUps.add({'full_name': fullName, 'phone': phone, 'pin': pin});
  }

  @override
  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String pin,
  }) async {
    await signInGate;
    final error = signInError;
    if (error != null) throw error;
    return signInResult ?? _authResponse();
  }

  @override
  Future<void> signOut() async => signOutCount++;

  @override
  Future<void> sendPinResetCode(String phone) async {
    final error = resetError;
    if (error != null) throw error;
    resetCodeRequests.add(phone);
  }

  @override
  Future<void> resetPin({
    required String phone,
    required String code,
    required String newPin,
  }) async {
    final error = resetError;
    if (error != null) throw error;
    pinResets.add({'phone': phone, 'code': code, 'pin': newPin});
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async => profile;

  @override
  String? get currentUserId => null;

  @override
  String? get accessToken => null;

  @override
  Future<Map<String, dynamic>?> fetchLatestRates() async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchTransactions() async => const [];

  @override
  Future<void> insertTransaction({
    required String type,
    required double amount,
    required String gateway,
    String? fromCurrency,
    String? toCurrency,
    String? referencePhone,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletState _walletWith(http.Client client) => WalletState(
  httpClient: client,
  baseUrl: _authBaseUrl,
  supabaseService: _FakeSupabaseService(),
  transactions: const [],
);

void main() {
  test('registerAccount creates the Supabase account and signs out', () async {
    final service = _FakeSupabaseService();
    final wallet = WalletState(supabaseService: service);
    addTearDown(wallet.dispose);

    expect(
      await wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '631234567',
        pin: '1234',
      ),
      isTrue,
    );
    expect(service.signUps, [
      {'full_name': 'Ada Lovelace', 'phone': '+252631234567', 'pin': '1234'},
    ]);
    expect(service.signOutCount, 1);
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
  });

  test(
    'registerAccount surfaces auth errors and does not set profile on failure',
    () async {
      final wallet = WalletState(
        supabaseService: _FakeSupabaseService(
          signUpError: const AuthException('User already registered'),
        ),
      );
      addTearDown(wallet.dispose);

      await expectLater(
        wallet.registerAccount(
          name: 'Ada Lovelace',
          phone: '+252631234567',
          pin: '1234',
        ),
        throwsA(
          isA<WalletApiException>().having(
            (error) => error.message,
            'message',
            'User already registered',
          ),
        ),
      );
      expect(wallet.fullName, isNull);
      expect(wallet.phoneNumber, isNull);
    },
  );

  test('registerAccount signs out when the profile cannot be saved', () async {
    final service = _FakeSupabaseService(
      signUpError: const ProfileCreationException('Profile not saved'),
    );
    final wallet = WalletState(supabaseService: service);
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '+252631234567',
        pin: '1234',
      ),
      throwsA(
        isA<WalletApiException>().having(
          (error) => error.message,
          'message',
          'Profile not saved',
        ),
      ),
    );
    expect(service.signOutCount, 1);
    expect(wallet.fullName, isNull);
  });

  test('registerAccount requires a configured Supabase service', () async {
    final wallet = WalletState();
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '+252631234567',
        pin: '1234',
      ),
      throwsA(isA<WalletApiException>()),
    );
  });

  test('toggleLanguage updates Somali state and notifies listeners', () {
    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    var notifications = 0;
    wallet.addListener(() => notifications++);

    wallet.toggleLanguage();

    expect(wallet.isSomali, isTrue);
    expect(notifications, 1);
  });

  test('fetchRates reads the latest USD/SLSH rates from Supabase', () async {
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/rates');
        return http.Response(
          '[{"usd_to_slsh":9000,"slsh_to_usd":8800}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(supabase.dispose);
    final wallet = WalletState(
      supabaseService: SupabaseService(client: supabase),
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    await wallet.fetchRates();

    expect(wallet.usdToSlshRate, 9000);
    expect(wallet.slshToUsdRate, 8800);
    expect(wallet.ratesError, isNull);
  });

  test('mobile money deposits require a signed-in Supabase user', () async {
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        fail('No request should be sent without a signed-in user.');
      }),
    );
    addTearDown(supabase.dispose);
    final wallet = WalletState(
      supabaseService: SupabaseService(client: supabase),
      transactions: const [],
    )..setPhoneNumber('+252631234567');
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.submitMobileMoneyDeposit(amount: 25, gateway: 'Zaad Mobile Money'),
      throwsA(isA<WalletApiException>()),
    );
    expect(wallet.transactions, isEmpty);
  });

  test(
    'fetchRates records Supabase network failures without throwing',
    () async {
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async {
          throw http.ClientException('network unavailable');
        }),
      );
      addTearDown(supabase.dispose);
      final wallet = WalletState(
        supabaseService: SupabaseService(client: supabase),
        transactions: const [],
      );
      addTearDown(wallet.dispose);

      await wallet.fetchRates();

      expect(wallet.usdToSlshRate, 0);
      expect(wallet.ratesError, contains('network unavailable'));
    },
  );

  test(
    'PIN reset sends a Supabase SMS code and then sets the new PIN',
    () async {
      final service = _FakeSupabaseService();
      final wallet = WalletState(supabaseService: service);
      addTearDown(wallet.dispose);

      await wallet.requestPinReset('631234567');
      await wallet.resetPin(phone: '631234567', code: '123456', newPin: '9876');

      expect(service.resetCodeRequests, ['+252631234567']);
      expect(service.pinResets, [
        {'phone': '+252631234567', 'code': '123456', 'pin': '9876'},
      ]);
    },
  );

  test(
    'PIN reset validates the code and PIN before calling Supabase',
    () async {
      final service = _FakeSupabaseService();
      final wallet = WalletState(supabaseService: service);
      addTearDown(wallet.dispose);

      await expectLater(
        wallet.resetPin(phone: '631234567', code: '1234', newPin: '9876'),
        throwsArgumentError,
      );
      await expectLater(
        wallet.resetPin(phone: '631234567', code: '123456', newPin: '98'),
        throwsArgumentError,
      );
      expect(service.pinResets, isEmpty);
    },
  );

  test('PIN reset surfaces Supabase AuthException unchanged', () async {
    final wallet = WalletState(
      supabaseService: _FakeSupabaseService(
        resetError: const AuthException('Token has expired or is invalid'),
      ),
    );
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.requestPinReset('631234567'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      wallet.resetPin(phone: '631234567', code: '123456', newPin: '9876'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Token has expired or is invalid',
        ),
      ),
    );
  });

  testWidgets('forgot PIN screen requests a code, then confirms the new PIN', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeSupabaseService();
    final wallet = WalletState(
      supabaseService: service,
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ForgotPinScreen(),
                  ),
                ),
                child: const Text('Open reset'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open reset'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm New PIN'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '631234567');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(service.resetCodeRequests, ['+252631234567']);
    expect(find.text('Confirm New PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '654321');
    await tester.enterText(find.byType(TextFormField).at(2), '7890');
    await tester.tap(find.text('Confirm New PIN'));
    await tester.pumpAndSettle();
    expect(service.pinResets, [
      {'phone': '+252631234567', 'code': '654321', 'pin': '7890'},
    ]);
    expect(find.text('Open reset'), findsOneWidget);
  });

  testWidgets('forgot PIN screen shows Supabase auth errors', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(
      supabaseService: _FakeSupabaseService(
        resetError: const AuthException('Signups not allowed for otp'),
      ),
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: ForgotPinScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '631234567');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(find.text('Signups not allowed for otp'), findsOneWidget);
    expect(find.text('Confirm New PIN'), findsNothing);
  });

  test(
    'loginAccount applies the authenticated profile and wallet balances',
    () async {
      final wallet = WalletState(
        supabaseService: _FakeSupabaseService(
          profile: const {
            'full_name': 'Ada Lovelace',
            'phone_number': '+252631234567',
            'is_admin': true,
            'usd_balance': 72.5,
            'slsh_balance': 123456,
          },
        ),
      );
      addTearDown(wallet.dispose);
      var notificationCount = 0;
      wallet.addListener(() => notificationCount++);

      expect(
        await wallet.loginAccount(phone: '+252631234567', pin: '1234'),
        isTrue,
      );
      expect(wallet.authToken, 'test-token');
      expect(wallet.fullName, 'Ada Lovelace');
      expect(wallet.phoneNumber, '+252631234567');
      expect(wallet.usdBalance, 72.5);
      expect(wallet.slshBalance, 123456);
      expect(wallet.isAdminUser, isTrue);
      expect(notificationCount, 1);
    },
  );

  test('loginAccount rejects a response without a user', () async {
    final wallet = WalletState(
      supabaseService: _FakeSupabaseService(
        signInResult: _authResponse(user: false),
      ),
    );
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.loginAccount(phone: '+252631234567', pin: '1234'),
      throwsA(isA<WalletApiException>()),
    );
    expect(wallet.authToken, isNull);
    expect(wallet.usdBalance, 100);
    expect(wallet.slshBalance, 500000);
  });

  test('loginAccount surfaces Supabase auth errors without mutation', () async {
    final wallet = WalletState(
      supabaseService: _FakeSupabaseService(
        signInError: const AuthException('Invalid login credentials'),
      ),
    );
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.loginAccount(phone: '+252631234567', pin: '1234'),
      throwsA(
        isA<WalletApiException>().having(
          (error) => error.message,
          'message',
          'Invalid login credentials',
        ),
      ),
    );
    expect(wallet.authToken, isNull);
    expect(wallet.fullName, isNull);
  });

  test('loginAccount requires a configured Supabase service', () async {
    final wallet = WalletState();
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.loginAccount(phone: '+252631234567', pin: '1234'),
      throwsA(isA<WalletApiException>()),
    );
  });

  test('API requests fail clearly when the base URL is not absolute', () async {
    final wallet = WalletState(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: '/api/auth',
      supabaseService: _FakeSupabaseService(),
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');

    await expectLater(
      wallet.submitCryptoDeposit(
        amount: 5,
        asset: 'USDT_TRC20',
        txHash: 'a' * 64,
      ),
      throwsA(
        isA<WalletApiException>().having(
          (error) => error.message,
          'message',
          contains('API_AUTH_BASE_URL'),
        ),
      ),
    );
  });

  test('default base URL is an absolute http(s) URL', () {
    final uri = Uri.parse(defaultAuthBaseUrl);
    expect(uri.hasAuthority, isTrue);
    expect(uri.host, isNotEmpty);
  });

  test(
    'crypto deposits authenticate and are recorded pending approval',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/crypto/deposit');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'amount': 7.5,
          'cryptoCurrency': 'USDT_TRC20',
          'txHash': 'a' * 64,
        });
        return http.Response('{}', 201);
      });
      final wallet = _walletWith(client);
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await wallet.submitCryptoDeposit(
        amount: 7.5,
        asset: 'USDT_TRC20',
        txHash: 'a' * 64,
      );

      expect(wallet.transactions, hasLength(1));
      expect(wallet.transactions.first.type, TransactionType.deposit);
      expect(wallet.transactions.first.status, TransactionStatus.pending);
      expect(wallet.usdBalance, 100);
    },
  );

  test('1xBet deposits post to /api/deposit/1xbet', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/deposit/1xbet');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['content-type'], 'application/json');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        '{"success":true,"transactionId":"bet-${bodies.length}","status":"pending"}',
        201,
      );
    });
    final wallet = _walletWith(client);
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');

    expect(
      await wallet.submit1xBetDeposit(
        playerId: ' player-one ',
        amount: 15.5,
        fundingSource: 'Zaad',
      ),
      'bet-1',
    );
    expect(
      await wallet.submit1xBetDeposit(
        playerId: 'player-one',
        amount: 20,
        fundingSource: 'Crypto',
        asset: 'USDC_POLYGON',
        txHash: 'a' * 64,
      ),
      'bet-2',
    );
    expect(bodies[0], {
      'playerId': 'player-one',
      'amount': 15.5,
      'currency': 'USD',
      'fundingSource': 'Zaad',
    });
    expect(bodies[1], {
      'playerId': 'player-one',
      'amount': 20,
      'currency': 'USD',
      'fundingSource': 'Crypto',
      'cryptoCurrency': 'USDC_POLYGON',
      'txHash': 'a' * 64,
    });
    expect(wallet.transactions, hasLength(2));
    expect(wallet.transactions.first.status, TransactionStatus.pending);
  });

  test('1xBet deposits surface 429 rate-limit responses', () async {
    final wallet = _walletWith(
      MockClient(
        (_) async => http.Response('{}', 429, headers: {'retry-after': '30'}),
      ),
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');

    await expectLater(
      wallet.submit1xBetDeposit(
        playerId: 'p',
        amount: 5,
        fundingSource: 'Zaad',
      ),
      throwsA(
        isA<WalletApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.message, 'message', contains('30 seconds')),
      ),
    );
    expect(wallet.transactions, isEmpty);
  });

  test('1xBet withdrawals post the cashier payout request', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/withdrawal/1xbet');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {
        'player': 'player-one',
        'amount': 12.5,
        'destinationPhone': '+252631234567',
        'fundingSource': 'edahab',
        'withdrawalCode': 'AB12CD',
      });
      return http.Response(
        '{"success":true,"transactionId":"wd-7","status":"pending_withdrawal"}',
        201,
      );
    });
    final wallet = _walletWith(client);
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');

    expect(
      await wallet.submit1xBetWithdrawal(
        playerId: ' player-one ',
        amount: 12.5,
        destinationPhone: '631234567',
        fundingSource: 'edahab',
        withdrawalCode: ' AB12CD ',
      ),
      'wd-7',
    );
    expect(wallet.usdBalance, 100);
    expect(wallet.transactions.first.type, TransactionType.withdrawal);
    expect(wallet.transactions.first.status, TransactionStatus.pending);
  });

  test(
    '1xBet deposits validate the funding source and crypto details',
    () async {
      final wallet = _walletWith(
        MockClient((_) async => fail('No request should be sent.')),
      );
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      for (final call in [
        () => wallet.submit1xBetDeposit(
          playerId: 'p',
          amount: 5,
          fundingSource: 'Cash',
        ),
        () => wallet.submit1xBetDeposit(
          playerId: 'p',
          amount: 5,
          fundingSource: 'Crypto',
          asset: 'USDT_TRC20',
          txHash: 'bad',
        ),
        () => wallet.submit1xBetDeposit(
          playerId: 'p',
          amount: 5,
          fundingSource: 'Crypto',
          asset: 'DOGE',
          txHash: 'a' * 64,
        ),
        () => wallet.submit1xBetDeposit(
          playerId: ' ',
          amount: 5,
          fundingSource: 'Zaad',
        ),
      ]) {
        await expectLater(call(), throwsArgumentError);
      }
    },
  );

  test(
    'crypto withdrawals authenticate and deduct balance only on success',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/crypto/withdraw');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'amount': 12.25,
          'cryptoCurrency': 'USDC_POLYGON',
          'destinationAddress': '0x${'a' * 40}',
        });
        return http.Response('{}', 200);
      });
      final wallet = _walletWith(client);
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await wallet.submitCryptoWithdrawal(
        amount: 12.25,
        asset: 'USDC_POLYGON',
        address: '0x${'a' * 40}',
      );

      expect(wallet.usdBalance, 87.75);
      expect(wallet.transactions.first.type, TransactionType.withdrawal);
      expect(wallet.transactions.first.status, TransactionStatus.pending);
    },
  );

  test(
    'crypto withdrawal leaves balance unchanged when backend rejects it',
    () async {
      final client = MockClient((request) async {
        return http.Response('{"message":"Address rejected"}', 422);
      });
      final wallet = _walletWith(client);
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await expectLater(
        wallet.submitCryptoWithdrawal(
          amount: 12,
          asset: 'USDC_POLYGON',
          address: '0x${'a' * 40}',
        ),
        throwsA(isA<WalletApiException>()),
      );
      expect(wallet.usdBalance, 100);
      expect(wallet.transactions, isEmpty);
    },
  );

  test('wallet exchanges both currencies with published agent spreads', () {
    final wallet = WalletState(
      usdToSlshRate: 8500,
      slshToUsdRate: 8500,
      transactions: const [],
    );

    expect(wallet.usdBalance, 100);
    expect(wallet.slshBalance, 500000);
    wallet.executeLocalExchange(10, true);
    expect(wallet.usdBalance, 90);
    expect(wallet.slshBalance, 585000);
    expect(wallet.transactions.first.type, TransactionType.exchange);
    expect(wallet.transactions.first.convertedAmount, 85000);

    wallet.updateRates(9000, 8800);
    wallet.executeLocalExchange(88000, false);
    expect(wallet.usdBalance, 100);
    expect(wallet.slshBalance, 497000);
    expect(wallet.transactions.first.convertedAmount, 10);
  });

  test('wallet rejects exchange amounts above the available balance', () {
    final wallet = WalletState(transactions: const []);

    expect(() => wallet.executeLocalExchange(101, true), throwsArgumentError);
    expect(wallet.usdBalance, 100);
    expect(wallet.slshBalance, 500000);
    expect(wallet.transactions, isEmpty);
  });

  testWidgets('registration validates fields and saves the profile mapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeSupabaseService();
    final wallet = WalletState(
      supabaseService: service,
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: MaterialApp(
          home: const RegisterScreen(),
          routes: {
            LoginScreen.routeName: (_) => const LoginScreen(),
            DashboardScreen.routeName: (_) => const DashboardScreen(),
          },
        ),
      ),
    );

    expect(find.text('Create Cali Black Exchange Account'), findsOneWidget);
    expect(
      find.text(
        'I agree to the Cali Black Exchange Privacy Policy and Anti-Money Laundering Framework.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsNothing);
    expect(service.signUps, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your mobile money phone number.'), findsOneWidget);
    expect(find.text('Create your secure 4-digit PIN.'), findsOneWidget);
    expect(service.signUps, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), '631234567');
    await tester.enterText(find.byType(TextFormField).at(2), '1234');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(service.signUps, hasLength(1));
    expect(service.signOutCount, 1);
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('sign in validates input and opens the wallet dashboard', (
    tester,
  ) async {
    final client = MockClient((request) async => http.Response('{}', 404));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WalletState(
          httpClient: client,
          supabaseService: _FakeSupabaseService(),
        ),
        child: const CaliWalletApp(),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter 9 digits starting with 63 or 65.'), findsOneWidget);
    expect(find.text('Enter your passcode.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '631234567');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('500,000'), findsOneWidget);
    expect(find.text('Deposit / Withdraw 💵'), findsOneWidget);
    expect(find.text('Currency Exchange 🔄'), findsOneWidget);
    expect(find.text('Withdraw 🏦'), findsNothing);
    expect(find.text('1xBet'), findsNothing);
  });

  testWidgets('login language toggle localizes labels and validation', (
    tester,
  ) async {
    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('English 🇬🇧'));
    await tester.pumpAndSettle();
    expect(wallet.isSomali, isTrue);
    expect(find.text('PIN-ka'), findsOneWidget);
    expect(find.text('Soo Log-in'), findsOneWidget);

    await tester.tap(find.text('Soo Log-in'));
    await tester.pumpAndSettle();
    expect(
      find.text('Geli 9 lambar oo ka bilaabma 63 ama 65.'),
      findsOneWidget,
    );
    expect(find.text('Geli PIN-kaaga.'), findsOneWidget);
  });

  testWidgets('login shows a modal loader and reports auth errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gate = Completer<void>();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WalletState(
          supabaseService: _FakeSupabaseService(
            signInGate: gate.future,
            signInError: const AuthException('Invalid phone number or PIN'),
          ),
        ),
        child: const CaliWalletApp(),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '631234567');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Signing in securely…'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Signing in securely…'), findsNothing);
    expect(find.text('Invalid phone number or PIN'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('wallet deposit validates minimum amount', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DepositScreen(),
                      ),
                    );
                  },
                  child: const Text('Open deposit'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open deposit'));
    await tester.pumpAndSettle();
    expect(find.text('Secure Wallet Deposit Center'), findsOneWidget);
    expect(find.text('1xBet User ID'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.ensureVisible(find.text('Pay with ZAAD'));
    await tester.tap(find.text('Pay with ZAAD'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '0.99');
    await tester.ensureVisible(find.text('Pay with ZAAD'));
    await tester.tap(find.text('Pay with ZAAD'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum deposit is \$1.00 USD.'), findsOneWidget);
    expect(wallet.transactions, isEmpty);
  });

  testWidgets('crypto deposit selection shows transaction hash field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: DepositScreen()),
      ),
    );

    await tester.tap(find.text('Crypto (USDT / USDC)'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Hash (TxHash)'), findsOneWidget);
    expect(
      find.textContaining(
        'credited to your Cali Black Exchange wallet balance',
      ),
      findsOneWidget,
    );
    expect(find.text('1xBet'), findsOneWidget);
  });

  testWidgets('1xBet is the only betting option and offers funding sources', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: DepositScreen()),
      ),
    );

    expect(find.text('MobCash'), findsNothing);
    expect(find.text('PAY 1XBET WITH'), findsNothing);

    await tester.tap(find.text('1xBet').first);
    await tester.pumpAndSettle();
    expect(find.text('1xBet User ID'), findsOneWidget);
    expect(find.text('Submit 1xBet Deposit'), findsOneWidget);
    expect(find.text('PAY 1XBET WITH'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Transaction Hash (TxHash)'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Crypto (USDT / USDC)'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Hash (TxHash)'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));

    await tester.tap(find.widgetWithText(ChoiceChip, 'eDahab'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Hash (TxHash)'), findsNothing);
  });

  testWidgets('1xBet crypto funding submits the player ID and tx hash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? sent;
    final wallet = _walletWith(
      MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"success":true,"transactionId":"bet-9","status":"pending"}',
          201,
        );
      }),
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: DepositScreen()),
      ),
    );

    await tester.tap(find.text('1xBet').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Crypto (USDT / USDC)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '25');
    await tester.enterText(find.byType(TextFormField).at(1), 'player-77');
    await tester.enterText(find.byType(TextFormField).at(2), 'b' * 64);
    await tester.ensureVisible(find.text('Submit 1xBet Deposit'));
    await tester.tap(find.text('Submit 1xBet Deposit'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pending cashier'), findsOneWidget);
    expect(sent, {
      'playerId': 'player-77',
      'amount': 25,
      'currency': 'USD',
      'fundingSource': 'Crypto',
      'cryptoCurrency': 'USDT_TRC20',
      'txHash': 'b' * 64,
    });
    expect(wallet.transactions.first.gateway, '1xBet');
  });

  testWidgets('withdrawal screen validates and displays the crypto flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(transactions: const []);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: WithdrawalScreen()),
      ),
    );

    expect(find.text('Withdraw to crypto'), findsOneWidget);
    await tester.tap(find.text('Submit Crypto Withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid withdrawal amount.'), findsOneWidget);
    expect(find.text('Enter a valid TRON (TRC-20) address.'), findsOneWidget);
  });

  testWidgets('exchange preview uses current rates and can swap direction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(
      usdToSlshRate: 8500,
      slshToUsdRate: 8500,
      transactions: const [],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: ExchangeScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('2.00 USD = 17,000.00 SLSH'), findsOneWidget);

    await tester.tap(find.byTooltip('Swap exchange direction'));
    await tester.pumpAndSettle();
    expect(find.text('SLSH → USD  8,500.00'), findsOneWidget);
    expect(find.text('2.00 SLSH = 0.00 USD'), findsOneWidget);
  });

  testWidgets('admin panel publishes the conversion spreads to wallet state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(
      supabaseService: _FakeSupabaseService(
        profile: const {
          'full_name': 'Admin User',
          'phone_number': '+252631234567',
          'is_admin': true,
          'usd_balance': 100,
          'slsh_balance': 500000,
        },
      ),
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: AdminRatesScreen()),
      ),
    );

    expect(wallet.isAdminUser, isTrue);
    await tester.enterText(find.byType(TextFormField).at(0), '9000');
    await tester.enterText(find.byType(TextFormField).at(1), '8800');
    await tester.tap(find.text('Publish Live Agency Spreads'));
    await tester.pumpAndSettle();

    expect(wallet.usdToSlshRate, 9000);
    expect(wallet.slshToUsdRate, 8800);
  });
}
