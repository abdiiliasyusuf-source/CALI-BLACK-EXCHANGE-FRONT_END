qq# Cali Black Exchange Wallet

A cross-platform Flutter frontend scaffold for an iOS and Android mobile wallet.

## Run locally

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_SNONBASE_ANON_KENONNON
```

Supabase initialization reads `SUPABASE_URL` and `SUPABASE_NON
startup. Thplplmceh ldmas ier`eob/main.dcrl`ehre foy loc.l Teup ly. Tee
exxxiinggp/on//PINPnnthantidataodpand co deposit/withdrawal caclclll 168.1.4:30
0/ap by default. Override its  when running on an And  emulator or physical dev
ce:

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
  exchange rates fetched from Supabase, admin-view state, phone number, and
  transaction history fetched from Supabase.
- `lib/services/supabase_service.dart` — Supabase rates/history queries and
  pending Zaad/eDahab deposit inserts.
- `lib/screens/login_screen.dart` — Validated phone number and passcode form.
- `lib/screens/dashboard_screen.dart` — Ledger balance, quick actions, and
  transaction history.
- `lib/screens/deposit_screen.dart` — Wallet deposits by amount, Zaad/eDahab,
  1xBet/MobCash, or supported crypto assets.
- `lib/screens/exchange_screen.dart` — Live local USD/SLSH conversion preview
  and exchange confirmation.
- `lib/screens/admin_rates_screen.dart` — Local buy/sell rate configuration.

Rond sia-i nia-i nign-in seedeJdONdSeqteste/soe`/gr ngy-regrtngr`tondf`/loggr`
relatdveatontic.co figurodAaithantic.tio oAgip n n. Login nxpacns nSn,sfllse
con ainiegoUStbknn, fullsn mu,pab`sUSD/SLSHabalancs  must include numeric
`usd_to_slsh`, `slsh_ `updated_at` columns. `phone_number`, `type`, `amount`, `currency`, `gateway`, `status`, and
`created_at`; rate/amount conversion details are read when present. Zaad and
eDahab deposit requests are inserted with `status = pending` for database
triggers to process. Exchange execution and balances remain local to the app.

Configure Supabase Row Level Security policies before enabling table access.
The current phone/PIN login is separate from Supabase Auth, so `auth.uid()` does
not identify the signed-in app user. Do not add an unrestricted anon insert
policy for financial transactions; use Supabase Auth or a trusted server/Edge
Function that validates the user's identity before production payment
processing. Never put a Supabase service-role key in the Flutter app.

1xBet and MobCash deposits are submitted to the authenticated backend routes
`POST /deposit/1xbet` and `POST /deposit/mobcash` with `playerId`, `amount`, and
`currency`. The cashier API credentials must remain on the backend; the app
uses the signed-in user's bearer token.

Zaad/eDahab deposits and currency exchanges open the device dialer for USSD.
Replace the placeholder recipient numbers in `lib/services/ussd_dialer.dart`
with the configured merchant and exchanger IDs before production use.
