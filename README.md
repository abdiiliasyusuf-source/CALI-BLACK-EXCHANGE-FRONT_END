# Cali Black Exchange Wallet

A cross-platform Flutter frontend scaffold for an iOS and Android mobile wallet.

## Run locally

```bash
flutter pub get
flutter run
```

Authentication calls use `http://192.168.1.4:3000/api/auth` by default, while
wallet API calls use its `/api` parent. Override the authentication base URL
when running on an Android emulator or physical device:

```bash
flutter run --dart-define=API_AUTH_BASE_URL=http://10.0.2.2:3000/api/auth
```

For a physical device, set `API_AUTH_BASE_URL` to the development machine's
reachable LAN address. Ensure the backend listens on the network interface and
the firewall allows port 3000. HTTP cleartext is enabled only for Android
debug/profile builds. Use HTTPS and keep cleartext disabled in production.

Run the checks with:

```bash
flutter analyze
flutter test
```

## Structure

- `lib/models/wallet_state.dart` — Provider-backed USD/SLSH balances, agent
  exchange rates, admin-view state, phone number, and transaction history.
- `lib/screens/login_screen.dart` — Validated phone number and passcode form.
- `lib/screens/dashboard_screen.dart` — Ledger balance, quick actions, and
  transaction history.
- `lib/screens/deposit_screen.dart` — Wallet deposits by amount, Zaad/eDahab,
  or supported crypto assets.
- `lib/screens/exchange_screen.dart` — Live local USD/SLSH conversion preview
  and exchange confirmation.
- `lib/screens/admin_rates_screen.dart` — Local buy/sell rate configuration.

Registration and sign-in send JSON requests to `/verify-register` and `/login`
relative to the configured authentication API base.
Login expects a response containing a token, full name, and USD/SLSH balances.
Balances, rates, and exchange history are otherwise stored in app memory;
exchange and deposit actions are local demo operations. The admin rates screen is
not an authenticated or server-persisted admin panel. Connect wallet, rate, and
payment services before using this interface with real accounts or funds.
`url_launcher` is included for a future configured dialer or USSD integration;
no gateway dial codes are assumed.
