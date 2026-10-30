import 'package:cali_black_exchange_frontend/l10n/app_strings.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_admin.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_auth_login.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_auth_reset.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_dashboard.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_exchange.dart';
import 'package:cali_black_exchange_frontend/l10n/strings_wallet.dart';
import 'package:cali_black_exchange_frontend/models/wallet_state.dart';
import 'package:cali_black_exchange_frontend/screens/admin_rates_screen.dart';
import 'package:cali_black_exchange_frontend/screens/dashboard_screen.dart';
import 'package:cali_black_exchange_frontend/screens/deposit_screen.dart';
import 'package:cali_black_exchange_frontend/screens/exchange_screen.dart';
import 'package:cali_black_exchange_frontend/screens/forgot_pin_screen.dart';
import 'package:cali_black_exchange_frontend/screens/login_screen.dart';
import 'package:cali_black_exchange_frontend/screens/register_screen.dart';
import 'package:cali_black_exchange_frontend/screens/withdrawal_screen.dart';
import 'package:cali_black_exchange_frontend/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _AdminWallet extends WalletState {
  _AdminWallet() : super(transactions: const []);

  @override
  bool get isAdminUser => true;
}

Set<String> placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  test('English and Somali dictionaries have identical keys', () {
    expect(somaliStrings.keys.toSet(), englishStrings.keys.toSet());
  });

  test('area dictionaries do not define the same key twice', () {
    final total = [
      enAuthLogin,
      enAuthReset,
      enDashboard,
      enWallet,
      enExchange,
      enAdmin,
    ].fold<int>(0, (sum, area) => sum + area.length);
    expect(englishStrings.length, total);
  });

  test('Somali entries keep the same placeholders and are not empty', () {
    for (final entry in englishStrings.entries) {
      final somali = somaliStrings[entry.key]!;
      expect(somali.trim(), isNotEmpty, reason: entry.key);
      expect(
        placeholders(somali),
        placeholders(entry.value),
        reason: 'placeholders differ for ${entry.key}',
      );
    }
  });

  test('translate substitutes arguments and falls back safely', () {
    expect(translate('missing.key', somali: true), 'missing.key');
    final key = englishStrings.keys.firstWhere(
      (k) => placeholders(englishStrings[k]!).isNotEmpty,
      orElse: () => '',
    );
    if (key.isEmpty) return;
    final names = placeholders(englishStrings[key]!);
    final args = {for (final name in names) name: 'X'};
    expect(translate(key, somali: true, args: args), isNot(contains('{')));
  });

  const screens = <String, ({Widget screen, String titleKey})>{
    'deposit': (screen: DepositScreen(), titleKey: 'deposit.title'),
    'withdrawal': (screen: WithdrawalScreen(), titleKey: 'withdrawal.title'),
    'admin': (screen: AdminRatesScreen(), titleKey: 'admin.title'),
    'forgot pin': (screen: ForgotPinScreen(), titleKey: 'forgotPin.title'),
    'register': (screen: RegisterScreen(), titleKey: 'register.title'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} screen switches language via the toggle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final wallet = entry.key == 'admin'
          ? _AdminWallet()
          : WalletState(transactions: const []);
      addTearDown(wallet.dispose);
      final english = englishStrings[entry.value.titleKey]!;
      final somali = somaliStrings[entry.value.titleKey]!;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: wallet,
          child: MaterialApp(home: entry.value.screen),
        ),
      );
      expect(find.text(english), findsOneWidget);

      await tester.tap(find.byType(LanguageToggleButton));
      await tester.pumpAndSettle();
      expect(wallet.isSomali, isTrue);
      expect(find.text(somali), findsOneWidget);
      expect(find.text(english), findsNothing);

      await tester.tap(find.byType(LanguageToggleButton));
      await tester.pumpAndSettle();
      expect(find.text(english), findsOneWidget);
    });
  }

  testWidgets('dashboard, exchange and login follow the language state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = WalletState(transactions: const []);
    addTearDown(wallet.dispose);
    final pages = <Widget, String>{
      const DashboardScreen(): 'dashboard.empty_title',
      const ExchangeScreen(): 'exchange.headerTitle',
      const LoginScreen(): 'login.signIn',
    };

    for (final page in pages.entries) {
      final key = page.value;
      expect(englishStrings.containsKey(key), isTrue, reason: key);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: wallet,
          child: MaterialApp(home: page.key),
        ),
      );
      wallet.toggleLanguage();
      await tester.pumpAndSettle();
      expect(find.text(somaliStrings[key]!), findsWidgets, reason: key);
      wallet.toggleLanguage();
      await tester.pumpAndSettle();
      expect(find.text(englishStrings[key]!), findsWidgets, reason: key);
    }
  });
}
