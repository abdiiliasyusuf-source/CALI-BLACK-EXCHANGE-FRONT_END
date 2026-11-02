# Cali Black Exchange Wallet

Flutter client for the Cali Black Exchange backend. Authentication, rates,
balances, transaction history, and payment/exchange requests are served by the
Node.js API; the app does not read or write wallet data directly in Supabase.

## Run locally

Start the backend on port `10000`, then run:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:10000
```

The app's default API base URL is `http://localhost:10000`. Android emulators
usually need the host bridge address:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:10000
```

For a physical device, use the development machine's reachable LAN address.
For production, set `API_BASE_URL` to the HTTPS backend origin. The API routes
are mounted under `/api`; do not include `/api` in `API_BASE_URL`.

The backend must be configured with a `JWT_SECRET` of at least 32 bytes and a
reachable PostgreSQL database. Apply `database/schema.sql` from the backend
repository before starting the server. Use HTTPS in production.

## API-backed flows

- Phone/PIN login stores the backend JWT in secure storage and sends it as a
  bearer token on authenticated requests.
- The dashboard loads USD/SLSH balances and the latest 200 transactions from
  the backend. Pull down to refresh.
- Exchange rates come from `GET /api/rates`; administrators publish rates with
  `PUT /api/rates/update`. Both directions are quoted as SLSH per 1 USD.
- Exchange requests are created through `POST /api/wallet/exchange` and remain
  pending until an administrator verifies them. Balances do not change before
  approval.
- Zaad/eDahab deposits are recorded before opening the USSD dialer, then marked
  submitted after the user confirms payment. Cashiers still verify each
  deposit.
- Crypto deposits remain unavailable until the backend has an on-chain
  verifier configured; the client treats backend errors as failures, not as
  successful deposits.

## Checks

```bash
flutter analyze
flutter test
```
