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
import 'package:cali_black_exchange_frontend/screens/reset_password_screen.dart';
import 'package:cali_black_exchange_frontend/screens/withdrawal_screen.dart';
import 'package:cali_black_exchange_frontend/services/supabase_service.dart';

void main() {
  test('registerAccount posts fields and accepts HTTP 201', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://192.168.1.4:3000/api/auth/verify-register',
      );
      expect(
        request.headers['content-type'],
        'application/json; charset=UTF-8',
      );
      expect(jsonDecode(request.body), {
        'full_name': 'Ada Lovelace',
        'phone_number': '+252631234567',
        'pin': '1234',
        'otp_code': '123456',
      });
      return http.Response('', 201);
    });
    final wallet = WalletState(httpClient: client);
    addTearDown(wallet.dispose);

    expect(
      await wallet.registerAccount(
        name: 'Ada Lovelace',
        phone: '+252631234567',
        pin: '1234',
        otpCode: '123456',
      ),
      isTrue,
    );
    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
  });

  test(
    'registerAccount surfaces API errors and does not set profile on failure',
    () async {
      final client = MockClient(
        (_) async =>
            http.Response('{"message":"Phone is already registered"}', 409),
      );
      final wallet = WalletState(httpClient: client);
      addTearDown(wallet.dispose);

      await expectLater(
        wallet.registerAccount(
          name: 'Ada Lovelace',
          phone: '+252631234567',
          pin: '1234',
          otpCode: '123456',
        ),
        throwsA(
          isA<WalletApiException>().having(
            (error) => error.message,
            'message',
            'Phone is already registered',
          ),
        ),
      );
      expect(wallet.fullName, isNull);
      expect(wallet.phoneNumber, isNull);
    },
  );

  test(
    'requestSmsOtp posts the phone number to the auth OTP endpoint',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/request-otp');
        expect(jsonDecode(request.body), {'phone_number': '+252631234567'});
        return http.Response(
          '{"success":true,"message":"Verification code dispatched via SMS."}',
          200,
        );
      });
      final wallet = WalletState(httpClient: client);
      addTearDown(wallet.dispose);

      expect(await wallet.requestSmsOtp('+252631234567'), isTrue);
    },
  );

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

  test('fetchRates records Supabase network failures without throwing', () async {
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
  });

  test(
    'password reset methods use the backend request and confirm contracts',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        if (request.url.path == '/api/auth/reset-otp') {
          expect(jsonDecode(request.body), {'phone_number': '+252631234567'});
          return http.Response('{"success":true}', 200);
        }
        expect(request.url.path, '/api/auth/confirm-reset');
        expect(jsonDecode(request.body), {
          'phone_number': '+252631234567',
          'otp_code': '123456',
          'new_pin': '9876',
        });
        return http.Response('{"success":true}', 200);
      });
      final wallet = WalletState(httpClient: client);
      addTearDown(wallet.dispose);

      expect(await wallet.requestPasswordResetOtp('631234567'), isTrue);
      expect(
        await wallet.confirmPasswordReset(
          phone: '+252631234567',
          otpCode: '123456',
          newPin: '9876',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'password reset screen reveals confirmation fields after OTP request',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/reset-otp') {
          expect(jsonDecode(request.body), {'phone_number': '+252631234567'});
          return http.Response('{"success":true}', 200);
        }
        expect(request.url.path, '/api/auth/confirm-reset');
        expect(jsonDecode(request.body), {
          'phone_number': '+252631234567',
          'otp_code': '654321',
          'new_pin': '7890',
        });
        return http.Response('{"success":true}', 200);
      });
      final wallet = WalletState(httpClient: client, transactions: const []);
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
                      builder: (_) => const ResetPasswordScreen(),
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
      expect(find.text('New 4-digit PIN'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '631234567');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('New 4-digit PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '654321');
      await tester.enterText(find.byType(TextFormField).at(2), '7890');
      await tester.tap(find.text('Confirm & Reset PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Open reset'), findsOneWidget);
    },
  );

  test(
    'loginAccount applies the authenticated profile and wallet balances',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://192.168.1.4:3000/api/auth/login',
        );
        expect(jsonDecode(request.body), {
          'phone_number': '+252631234567',
          'pin': '1234',
        });
        return http.Response(
          jsonEncode({
            'token': 'session-token',
            'user': {
              'full_name': 'Ada Lovelace',
              'phone_number': '+252631234567',
              'isAdmin': true,
              'balances': {'USD': 72.5, 'SLSH': 123456},
            },
          }),
          200,
        );
      });
      final wallet = WalletState(httpClient: client);
      addTearDown(wallet.dispose);
      var notificationCount = 0;
      wallet.addListener(() => notificationCount++);

      expect(
        await wallet.loginAccount(phone: '+252631234567', pin: '1234'),
        isTrue,
      );
      expect(wallet.authToken, 'session-token');
      expect(wallet.fullName, 'Ada Lovelace');
      expect(wallet.phoneNumber, '+252631234567');
      expect(wallet.usdBalance, 72.5);
      expect(wallet.slshBalance, 123456);
      expect(wallet.isAdminUser, isTrue);
      expect(notificationCount, 1);
    },
  );

  test(
    'loginAccount rejects an incomplete success response without mutation',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"token":"x"}', 200),
      );
      final wallet = WalletState(httpClient: client);
      addTearDown(wallet.dispose);

      await expectLater(
        wallet.loginAccount(phone: '+252631234567', pin: '1234'),
        throwsA(isA<WalletApiException>()),
      );
      expect(wallet.authToken, isNull);
      expect(wallet.usdBalance, 100);
      expect(wallet.slshBalance, 500000);
    },
  );

  test(
    'crypto deposits authenticate and are recorded pending approval',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'full_name': 'Ada Lovelace',
                'usd_balance': 100,
                'slsh_balance': 500000,
              },
            }),
            200,
          );
        }

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
      final wallet = WalletState(httpClient: client, transactions: const []);
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

  test(
    'crypto withdrawals authenticate and deduct balance only on success',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'full_name': 'Ada Lovelace',
                'usd_balance': 100,
                'slsh_balance': 500000,
              },
            }),
            200,
          );
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/api/crypto/withdraw');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'amount': 12.25,
          'cryptoCurrency': 'USDC_BEP20',
          'destinationAddress': '0x${'a' * 40}',
        });
        return http.Response('{}', 200);
      });
      final wallet = WalletState(httpClient: client, transactions: const []);
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await wallet.submitCryptoWithdrawal(
        amount: 12.25,
        asset: 'USDC_BEP20',
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
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'full_name': 'Ada Lovelace',
                'usd_balance': 100,
                'slsh_balance': 500000,
              },
            }),
            200,
          );
        }
        return http.Response('{"message":"Address rejected"}', 422);
      });
      final wallet = WalletState(httpClient: client, transactions: const []);
      addTearDown(wallet.dispose);
      await wallet.loginAccount(phone: '+252631234567', pin: '1234');

      await expectLater(
        wallet.submitCryptoWithdrawal(
          amount: 12,
          asset: 'USDC_BEP20',
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

    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/request-otp') {
        expect(jsonDecode(request.body), {'phone_number': '+252631234567'});
        return http.Response('{"success":true}', 200);
      }
      expect(request.url.path, '/api/auth/verify-register');
      expect(jsonDecode(request.body), {
        'full_name': 'Ada Lovelace',
        'phone_number': '+252631234567',
        'pin': '1234',
        'otp_code': '654321',
      });
      return http.Response('', 201);
    });
    final wallet = WalletState(httpClient: client, transactions: const []);
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
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsNothing);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your mobile money phone number.'), findsOneWidget);
    expect(find.text('Create your secure 4-digit PIN.'), findsOneWidget);
    expect(find.text('Enter SMS Code'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), '631234567');
    await tester.enterText(find.byType(TextFormField).at(2), '1234');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter SMS Code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), '654321');
    await tester.tap(find.text('Confirm & Create Account'));
    await tester.pumpAndSettle();

    expect(wallet.fullName, 'Ada Lovelace');
    expect(wallet.phoneNumber, '+252631234567');
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('sign in validates input and opens the wallet dashboard', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/login');
      return http.Response(
        jsonEncode({
          'token': 'test-token',
          'user': {
            'full_name': 'Ada Lovelace',
            'phone_number': '+252631234567',
            'usd_balance': 100,
            'slsh_balance': 500000,
          },
        }),
        200,
      );
    });
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WalletState(httpClient: client),
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

  testWidgets('login shows a modal loader and reports API errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final responseCompleter = Completer<http.Response>();
    final client = MockClient((_) => responseCompleter.future);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WalletState(httpClient: client),
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

    responseCompleter.complete(
      http.Response('{"message":"Invalid phone number or PIN"}', 401),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signing in securely…'), findsNothing);
    expect(find.text('Invalid phone number or PIN'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('wallet deposit validates minimum amount', (
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

    await tester.ensureVisible(find.text('Continue to payment'));
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '0.99');
    await tester.ensureVisible(find.text('Continue to payment'));
    await tester.tap(find.text('Continue to payment'));
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
    expect(find.text('1xBet User ID'), findsNothing);
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
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'admin-session-token',
            'user': {
              'full_name': 'Admin User',
              'phone_number': '+252631234567',
              'isAdmin': true,
              'balances': {'USD': 100, 'SLSH': 500000},
            },
          }),
          200,
        ),
      ),
      transactions: const [],
    );
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
