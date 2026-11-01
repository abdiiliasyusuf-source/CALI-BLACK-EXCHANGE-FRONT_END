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
import 'package:cali_black_exchange_frontend/screens/payment_methods_screen.dart';
import 'package:cali_black_exchange_frontend/screens/register_screen.dart';
import 'package:cali_black_exchange_frontend/screens/forgot_pin_screen.dart';
import 'package:cali_black_exchange_frontend/screens/withdrawal_screen.dart';
import 'package:cali_black_exchange_frontend/services/supabase_service.dart';
import 'package:cali_black_exchange_frontend/services/token_store.dart';

const _authBaseUrl = 'http://192.168.1.4:3000/api/auth';

const _loginBody =
    '{"token":"test-token","user":{"full_name":"Ada Lovelace","phone_number":"+252631234567"}}';

class _FakeSupabaseService implements SupabaseService {
  @override
  String? get currentUserId => null;

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

/// Answers the auth endpoints so tests can sign in, and forwards every other
/// request to [inner].
http.Client _withAuth(
  http.Client inner, {
  String loginBody = _loginBody,
  List<http.Request>? authRequests,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/auth/login' || path == '/api/auth/register') {
      authRequests?.add(request);
      return path.endsWith('/login')
          ? http.Response(loginBody, 200)
          : http.Response('{"success":true}', 201);
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..body = request.body;
    return http.Response.fromStream(await inner.send(forwarded));
  });
}

WalletState _walletWith(http.Client client, {TokenStore? tokenStore}) =>
    WalletState(
      httpClient: _withAuth(client),
      baseUrl: _authBaseUrl,
      supabaseService: _FakeSupabaseService(),
      tokenStore: tokenStore,
      transactions: const [],
    );

class _FailingClearTokenStore extends InMemoryTokenStore {
  @override
  Future<void> clear() async => throw StateError('storage unavailable');
}

void main() {
  test('registerAccount registers, then logs in to obtain the token', () async {
    final requests = <http.Request>[];
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.url.path == '/api/auth/register'
            ? http.Response('{"success":true}', 201)
            : http.Response(_loginBody, 200);
      }),
      baseUrl: _authBaseUrl,
      tokenStore: store,
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    expect(
      await wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '631234567',
        pin: '1234',
      ),
      isTrue,
    );

    expect(requests.map((r) => r.url.path), [
      '/api/auth/register',
      '/api/auth/login',
    ]);
    expect(jsonDecode(requests[0].body), {
      'full_name': 'Ada Lovelace',
      'phone_number': '+252631234567',
      'pin': '1234',
    });
    expect(jsonDecode(requests[1].body), {
      'phone_number': '+252631234567',
      'pin': '1234',
    });
    expect(wallet.authToken, 'test-token');
    expect(store.token, 'test-token');
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
  });

  test('registerAccount surfaces 409 and does not log in', () async {
    final requests = <http.Request>[];
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{"message":"Phone already registered"}', 409);
      }),
      baseUrl: _authBaseUrl,
      tokenStore: store,
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '+252631234567',
        pin: '1234',
      ),
      throwsA(
        isA<WalletApiException>()
            .having((e) => e.message, 'message', 'Phone already registered')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
    expect(requests, hasLength(1));
    expect(wallet.authToken, isNull);
    expect(store.token, isNull);
    expect(wallet.fullName, isNull);
  });

  test('registerAccount validates input before calling the API', () async {
    var calls = 0;
    final wallet = WalletState(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 201);
      }),
      baseUrl: _authBaseUrl,
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    expect(
      () => wallet.registerAccount(name: 'Ada', phone: '631234567', pin: '12'),
      throwsArgumentError,
    );
    expect(calls, 0);
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

  test('mobile money deposits require a signed-in user', () async {
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
    );
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

  test('account reset posts the phone to /reset-account', () async {
    final requests = <http.Request>[];
    final wallet = _walletWith(
      MockClient((request) async {
        requests.add(request);
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(wallet.dispose);

    await wallet.resetAccount('631234567');

    expect(requests.single.url.path, '/api/auth/reset-account');
    expect(jsonDecode(requests.single.body), {'phone_number': '+252631234567'});
  });

  testWidgets('forgot PIN screen confirms before resetting the account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final wallet = _walletWith(
      MockClient((request) async {
        requests.add(request);
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: MaterialApp(
          routes: {
            RegisterScreen.routeName: (_) => const Text('Register page'),
          },
          home: const ForgotPinScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '631234567');
    await tester.tap(find.text('Reset account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    await tester.tap(find.text('Reset account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset account').last);
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/api/auth/reset-account');
    expect(find.text('Register page'), findsOneWidget);
  });

  testWidgets('forgot PIN screen shows backend errors', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = _walletWith(
      MockClient(
        (_) async =>
            http.Response('{"success":false,"message":"Rejected"}', 409),
      ),
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: const MaterialApp(home: ForgotPinScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '631234567');
    await tester.tap(find.text('Reset account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset account').last);
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsOneWidget);
  });

  test('loginAccount posts phone and PIN, then stores the token', () async {
    final requests = <http.Request>[];
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"token":"jwt-1","isAdmin":true,"user":{"full_name":"Ada Lovelace","phone_number":"+252631234567"}}',
          200,
        );
      }),
      baseUrl: _authBaseUrl,
      tokenStore: store,
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    expect(await wallet.loginAccount(phone: '631234567', pin: '1234'), isTrue);

    expect(requests.single.url.path, '/api/auth/login');
    expect(jsonDecode(requests.single.body), {
      'phone_number': '+252631234567',
      'pin': '1234',
    });
    expect(wallet.authToken, 'jwt-1');
    expect(store.token, 'jwt-1');
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
    expect(wallet.isAdminUser, isTrue);
  });

  test('loginAccount rejects a response without a token', () async {
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: _authBaseUrl,
      tokenStore: store,
      transactions: const [],
    );
    addTearDown(wallet.dispose);

    await expectLater(
      wallet.loginAccount(phone: '+252631234567', pin: '1234'),
      throwsA(isA<WalletApiException>()),
    );
    expect(wallet.authToken, isNull);
    expect(store.token, isNull);
  });

  test('loginAccount surfaces backend errors without mutation', () async {
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient(
        (_) async =>
            http.Response('{"message":"Invalid phone number or PIN"}', 401),
      ),
      baseUrl: _authBaseUrl,
      tokenStore: store,
      transactions: const [],
    );
    addTearDown(wallet.dispose);
    var expired = 0;
    wallet.onSessionExpired = () => expired++;

    await expectLater(
      wallet.loginAccount(phone: '+252631234567', pin: '1234'),
      throwsA(
        isA<WalletApiException>()
            .having((e) => e.message, 'message', 'Invalid phone number or PIN')
            .having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(wallet.authToken, isNull);
    expect(wallet.fullName, isNull);
    expect(store.token, isNull);
    expect(expired, 0);
  });

  test(
    'authenticated requests send the backend JWT as a Bearer token',
    () async {
      final requests = <http.Request>[];
      final wallet = _walletWith(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"success":true,"transactionId":"bet-1","status":"pending"}',
            201,
          );
        }),
      );
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await wallet.submit1xBetDeposit(
        playerId: 'player-one',
        amount: 15,
        fundingSource: 'Zaad',
      );

      expect(requests.single.url.path, '/api/deposit/1xbet');
      expect(
        requests.single.headers['authorization'],
        ['Bearer', 'test-token'].join(' '),
      );
    },
  );

  test(
    'authenticated requests read the persisted token after a restart',
    () async {
      final store = InMemoryTokenStore()..token = 'stored-jwt';
      final requests = <http.Request>[];
      final wallet = _walletWith(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"success":true,"transactionId":"bet-1","status":"pending"}',
            201,
          );
        }),
        tokenStore: store,
      );
      addTearDown(wallet.dispose);

      await wallet.submit1xBetDeposit(
        playerId: 'player-one',
        amount: 15,
        fundingSource: 'Zaad',
      );

      expect(
        requests.single.headers['authorization'],
        ['Bearer', 'stored-jwt'].join(' '),
      );
    },
  );

  test(
    'authenticated requests without a token fail before any request',
    () async {
      var calls = 0;
      final wallet = _walletWith(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 201);
        }),
      );
      addTearDown(wallet.dispose);

      await expectLater(
        wallet.submit1xBetDeposit(
          playerId: 'player-one',
          amount: 15,
          fundingSource: 'Zaad',
        ),
        throwsA(isA<WalletApiException>()),
      );
      expect(calls, 0);
    },
  );

  test('logout clears the token and signed-in state', () async {
    final store = InMemoryTokenStore();
    final wallet = _walletWith(
      MockClient((_) async => http.Response('{}', 201)),
      tokenStore: store,
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');
    expect(store.token, 'test-token');

    await wallet.logout();

    expect(wallet.authToken, isNull);
    expect(store.token, isNull);
    expect(wallet.fullName, isNull);
    expect(wallet.phoneNumber, isNull);
    await expectLater(
      wallet.submit1xBetDeposit(
        playerId: 'player-one',
        amount: 15,
        fundingSource: 'Zaad',
      ),
      throwsA(isA<WalletApiException>()),
    );
  });

  test('logout reports a failure to remove the saved token', () async {
    final wallet = _walletWith(
      MockClient((_) async => http.Response('{}', 201)),
      tokenStore: _FailingClearTokenStore(),
    );
    addTearDown(wallet.dispose);
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');

    await expectLater(wallet.logout(), throwsA(isA<WalletApiException>()));
    expect(wallet.authToken, isNull);
    expect(wallet.isAdminUser, isFalse);
  });

  test('a 401 clears the token and sends the user back to login', () async {
    final store = InMemoryTokenStore();
    final wallet = _walletWith(
      MockClient((_) async => http.Response('{"message":"jwt expired"}', 401)),
      tokenStore: store,
    );
    addTearDown(wallet.dispose);
    var expired = 0;
    wallet.onSessionExpired = () => expired++;
    await wallet.loginAccount(phone: '+252631234567', pin: '1234');
    expect(store.token, 'test-token');

    await expectLater(
      wallet.submit1xBetDeposit(
        playerId: 'player-one',
        amount: 15,
        fundingSource: 'Zaad',
      ),
      throwsA(
        isA<WalletApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );

    expect(wallet.authToken, isNull);
    expect(store.token, isNull);
    expect(expired, 1);
  });

  test('API requests fail clearly when the base URL is not absolute', () async {
    final wallet = WalletState(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: '/api/auth',
      tokenStore: InMemoryTokenStore()..token = 'test-token',
      transactions: const [],
    );
    addTearDown(wallet.dispose);

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
    'crypto withdrawals authenticate and record a pending withdrawal',
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
      expect(wallet.transactions.first.type, TransactionType.withdrawal);
      expect(wallet.transactions.first.status, TransactionStatus.pending);
    },
  );

  test('crypto withdrawal records nothing when backend rejects it', () async {
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
    expect(wallet.transactions, isEmpty);
  });

  test('wallet exchanges both currencies with published agent spreads', () {
    final wallet = WalletState(
      usdToSlshRate: 8500,
      slshToUsdRate: 8500,
      transactions: const [],
    );
    wallet.executeLocalExchange(10, true);
    expect(wallet.transactions.first.type, TransactionType.exchange);
    expect(wallet.transactions.first.convertedAmount, 85000);

    wallet.updateRates(9000, 8800);
    wallet.executeLocalExchange(88000, false);
    expect(wallet.transactions.first.convertedAmount, 10);
  });

  testWidgets('registration validates fields, registers and signs in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.url.path == '/api/auth/register'
            ? http.Response('{"success":true}', 201)
            : http.Response(_loginBody, 200);
      }),
      baseUrl: _authBaseUrl,
      supabaseService: _FakeSupabaseService(),
      tokenStore: store,
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
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your mobile money phone number.'), findsOneWidget);
    expect(find.text('Create your secure 4-digit PIN.'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), '631234567');
    await tester.enterText(find.byType(TextFormField).at(2), '1234');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(requests.map((r) => r.url.path), [
      '/api/auth/register',
      '/api/auth/login',
    ]);
    expect(store.token, 'test-token');
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('sign in validates input and opens the wallet dashboard', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(_loginBody, 200),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WalletState(
          httpClient: client,
          baseUrl: _authBaseUrl,
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

    expect(find.text('Current balance'), findsNothing);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Deposit / Withdraw 💵'), findsNothing);
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('Currency Exchange 🔄'), findsOneWidget);
    expect(find.text('Withdraw 🏦'), findsNothing);
    expect(find.text('1xBet'), findsNothing);
  });

  testWidgets('sign out clears the token and returns to login', (tester) async {
    final store = InMemoryTokenStore();
    final wallet = WalletState(
      httpClient: MockClient((_) async => http.Response(_loginBody, 200)),
      baseUrl: _authBaseUrl,
      supabaseService: _FakeSupabaseService(),
      tokenStore: store,
    );
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: wallet, child: const CaliWalletApp()),
    );
    await tester.enterText(find.byType(TextFormField).at(0), '631234567');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(store.token, 'test-token');

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();

    expect(store.token, isNull);
    expect(wallet.authToken, isNull);
    expect(find.text('Welcome back'), findsOneWidget);
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
          httpClient: MockClient((_) async {
            await gate.future;
            return http.Response(
              '{"message":"Invalid phone number or PIN"}',
              401,
            );
          }),
          baseUrl: _authBaseUrl,
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
    expect(find.text('1xBet User ID'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit 1xBet Deposit'));
    await tester.tap(find.text('Submit 1xBet Deposit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '0.09');
    await tester.ensureVisible(find.text('Submit 1xBet Deposit'));
    await tester.tap(find.text('Submit 1xBet Deposit'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum deposit is \$0.10 USD.'), findsOneWidget);
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

    await tester.tap(find.text('Crypto (USDT / USDC)').last);
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

    expect(find.text('1xBet User ID'), findsOneWidget);
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
    expect(find.text('Submit 1xBet Deposit'), findsOneWidget);
    expect(find.text('PAY 1XBET WITH'), findsOneWidget);
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

  Future<WalletState> pumpDashboardApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallet,
        child: MaterialApp(
          home: const DashboardScreen(),
          routes: {
            DepositScreen.routeName: (_) => const DepositScreen(),
            WithdrawalScreen.routeName: (_) => const WithdrawalScreen(),
            PaymentMethodsScreen.depositRouteName: (_) =>
                const PaymentMethodsScreen(flow: WalletFlow.deposit),
            PaymentMethodsScreen.withdrawRouteName: (_) =>
                const PaymentMethodsScreen(flow: WalletFlow.withdraw),
          },
        ),
      ),
    );
    return wallet;
  }

  testWidgets('dashboard Deposit lists only 1xBet and Crypto', (tester) async {
    await pumpDashboardApp(tester);

    await tester.tap(find.text('Deposit').first);
    await tester.pumpAndSettle();

    expect(find.text('Choose deposit method'), findsOneWidget);
    expect(find.text('Edahab'), findsNothing);
    expect(find.text('Zaad'), findsNothing);
    expect(find.text('1xBet'), findsOneWidget);
    expect(find.byType(DropdownButton), findsNothing);

    await tester.tap(find.byKey(const ValueKey('method-onexbet')));
    await tester.pumpAndSettle();
    expect(find.byType(DepositScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Choose deposit method'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('dashboard Withdraw opens method cards and routes by method', (
    tester,
  ) async {
    await pumpDashboardApp(tester);

    await tester.tap(find.text('Withdraw').first);
    await tester.pumpAndSettle();
    expect(find.text('Choose withdrawal method'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('method-zaad')));
    await tester.pump();
    expect(
      find.text('Withdrawals to this method are coming soon.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(const ValueKey('method-crypto')));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawalScreen), findsOneWidget);
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
      httpClient: MockClient(
        (_) async => http.Response(
          '{"token":"t","isAdmin":true,"user":{"full_name":"Admin User","phone_number":"+252631234567"}}',
          200,
        ),
      ),
      baseUrl: _authBaseUrl,
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
