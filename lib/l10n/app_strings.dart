import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';
import 'strings_admin.dart';
import 'strings_auth_login.dart';
import 'strings_auth_reset.dart';
import 'strings_dashboard.dart';
import 'strings_exchange.dart';
import 'strings_wallet.dart';

/// Every key must exist in both maps with the same `{placeholders}`;
/// `test/localization_test.dart` enforces this.
const englishStrings = <String, String>{
  ...enAuthLogin,
  ...enAuthReset,
  ...enDashboard,
  ...enWallet,
  ...enExchange,
  ...enAdmin,
};

const somaliStrings = <String, String>{
  ...soAuthLogin,
  ...soAuthReset,
  ...soDashboard,
  ...soWallet,
  ...soExchange,
  ...soAdmin,
};

/// Looks up [key] and substitutes `{name}` placeholders from [args].
/// Falls back to English, then to the key itself, so a missing entry is
/// visible instead of crashing.
String translate(
  String key, {
  required bool somali,
  Map<String, Object?> args = const {},
}) {
  var text = (somali ? somaliStrings[key] : null) ?? englishStrings[key] ?? key;
  args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
  return text;
}

extension AppLocalization on BuildContext {
  /// Use inside `build`: subscribes the widget so it rebuilds when the
  /// language is toggled.
  String tr(String key, [Map<String, Object?> args = const {}]) => translate(
    key,
    somali: select<WalletState, bool>((wallet) => wallet.isSomali),
    args: args,
  );

  /// Use in callbacks and async code, where listening is not allowed.
  String trRead(String key, [Map<String, Object?> args = const {}]) =>
      translate(key, somali: read<WalletState>().isSomali, args: args);
}
