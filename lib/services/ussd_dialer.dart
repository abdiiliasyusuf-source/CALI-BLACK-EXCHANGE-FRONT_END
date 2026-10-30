import 'package:url_launcher/url_launcher.dart';

enum UssdProvider {
  zaadUsd('zaad_usd', '883'),
  zaadSlsh('zaad_slsh', '223'),
  edahab('edahab', '110'),
  zaadExchangeUsdToSlsh('zaad_exchange_usd_slsh', '377'),
  zaadExchangeSlshToUsd('zaad_exchange_slsh_usd', '277');

  const UssdProvider(this.id, this.serviceCode);

  final String id;
  final String serviceCode;

  static UssdProvider fromId(String id) => UssdProvider.values.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ArgumentError.value(id, 'provider', 'Unknown'),
      );
}

class UssdDialerException implements Exception {
  const UssdDialerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Official merchant numbers shown to users, keyed by `zaad` / `edahab`.
const defaultMerchantNumbers = <String, String>{
  'zaad': '414018',
  'edahab': '22097',
};

/// Receiving merchant numbers (payments) and exchanger IDs (exchanges).
const ussdMerchantNumbers = <UssdProvider, String>{
  UssdProvider.zaadUsd: '414018',
  UssdProvider.zaadSlsh: '414018',
  UssdProvider.edahab: '22097',
  UssdProvider.zaadExchangeUsdToSlsh: '100000',
  UssdProvider.zaadExchangeSlshToUsd: '100000',
};

/// Builds e.g. `*883*0630000000*10#`; [merchantNumber] is the exchanger ID
/// for exchange providers.
String buildUssdString({
  required UssdProvider provider,
  required String merchantNumber,
  required num amount,
}) {
  final number = merchantNumber.replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+?\d{3,15}$').hasMatch(number)) {
    throw ArgumentError.value(merchantNumber, 'merchantNumber', 'Invalid');
  }
  if (!amount.isFinite || amount <= 0) {
    throw ArgumentError.value(amount, 'amount', 'Must be positive');
  }
  final amountText = amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
  return '*${provider.serviceCode}*$number*$amountText#';
}

/// Builds `tel:` URI with `*` and `#` percent-encoded (`#` -> `%23`).
Uri buildUssdUri(String ussd) {
  final encoded = Uri.encodeComponent(ussd).replaceAll('*', '%2A');
  return Uri.parse('tel:$encoded');
}

/// Opens the native dialer with the USSD code prefilled.
/// Throws [UssdDialerException] if the dialer cannot be launched.
Future<void> launchUssdDialer({
  required UssdProvider provider,
  required String merchantNumber,
  required num amount,
}) async {
  final Uri uri;
  try {
    uri = buildUssdUri(buildUssdString(
      provider: provider,
      merchantNumber: merchantNumber,
      amount: amount,
    ));
  } on ArgumentError {
    throw const UssdDialerException('Invalid payment details.');
  }

  try {
    if (!await canLaunchUrl(uri) || !await launchUrl(uri)) {
      throw const UssdDialerException(
        'This device cannot open the phone dialer. Use a phone with a SIM card.',
      );
    }
  } on UssdDialerException {
    rethrow;
  } catch (_) {
    throw const UssdDialerException(
      'Could not open the phone dialer. Please try again.',
    );
  }
}
