import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/wallet_state.dart';
import 'services/token_store.dart';
import 'screens/admin_rates_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/deposit_screen.dart';
import 'screens/exchange_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_pin_screen.dart';
import 'screens/onexbet_withdrawal_screen.dart';
import 'screens/withdrawal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wallet = WalletState(
    tokenStore: SecureTokenStore(),
  );
  wallet.onSessionExpired = () => CaliWalletApp.navigatorKey.currentState
      ?.pushNamedAndRemoveUntil(LoginScreen.routeName, (_) => false);
  unawaited(wallet.fetchRates());
  runApp(
    ChangeNotifierProvider<WalletState>(
      create: (_) => wallet,
      child: const CaliWalletApp(),
    ),
  );
}

class CaliWalletApp extends StatelessWidget {
  const CaliWalletApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _background = Color(0xFF0B0E14);
  static const _surface = Color(0xFF161B26);
  static const _inputSurface = Color(0xFF1F2633);
  static const _mint = Color(0xFF00E676);
  static const _silver = Color(0xFFA7B0C0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ALI BLACK Money Exchange',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: _mint,
          onPrimary: Color(0xFF052414),
          secondary: Color(0xFF8FA4BC),
          onSecondary: Color(0xFF0B0E14),
          error: Color(0xFFFF6B74),
          onError: Color(0xFF2A080B),
          surface: _surface,
          onSurface: Color(0xFFF4F7FB),
        ),
        scaffoldBackgroundColor: _background,
        canvasColor: _background,
        dividerColor: Colors.white.withValues(alpha: 0.08),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFF4F7FB),
          displayColor: const Color(0xFFF4F7FB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Color(0xFFF4F7FB),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _inputSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          hintStyle: const TextStyle(color: Color(0xFF778397)),
          labelStyle: const TextStyle(color: _silver),
          helperStyle: const TextStyle(color: Color(0xFF8994A6)),
          prefixIconColor: const Color(0xFF8994A6),
          suffixIconColor: const Color(0xFF8994A6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _mint, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B74)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B74), width: 1.5),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _surface,
          contentTextStyle: const TextStyle(color: Color(0xFFF4F7FB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        ForgotPinScreen.routeName: (_) => const ForgotPinScreen(),
        DashboardScreen.routeName: (_) => const DashboardScreen(),
        DepositScreen.routeName: (_) => const DepositScreen(),
        PaymentMethodsScreen.depositRouteName: (_) =>
            const PaymentMethodsScreen(flow: WalletFlow.deposit),
        PaymentMethodsScreen.withdrawRouteName: (_) =>
            const PaymentMethodsScreen(flow: WalletFlow.withdraw),
        ExchangeScreen.routeName: (_) => const ExchangeScreen(),
        AdminRatesScreen.routeName: (_) => const AdminRatesScreen(),
        WithdrawalScreen.routeName: (_) => const WithdrawalScreen(),
        OneXBetWithdrawalScreen.routeName: (_) =>
            const OneXBetWithdrawalScreen(),
      },
    );
  }
}
