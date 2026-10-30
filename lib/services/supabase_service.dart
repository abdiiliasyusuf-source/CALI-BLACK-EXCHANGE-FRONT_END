import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCreationException implements Exception {
  const ProfileCreationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TransactionException implements Exception {
  const TransactionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Supabase Auth needs an email and a 6+ char password, so the phone and PIN are mapped to both.
  static String _email(String phone) =>
      '${phone.replaceAll(RegExp(r'\D'), '')}@users.caliblackexchange.com';

  static String _password(String phone, String pin) =>
      'cbx-$pin-${phone.replaceAll(RegExp(r'\D'), '')}';

  Future<void> signUpWithPhone({
    required String fullName,
    required String phone,
    required String pin,
  }) async {
    final response = await _client.auth.signUp(
      email: _email(phone),
      password: _password(phone, pin),
      data: {'full_name': fullName, 'phone_number': phone},
    );
    final user = response.user;
    if (user == null || response.session == null) {
      throw const AuthException(
        'Account created but no session was returned. Disable email confirmation in Supabase Auth settings.',
      );
    }
    try {
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'phone_number': phone,
      });
    } on PostgrestException catch (error) {
      throw ProfileCreationException(
        'Your account was created, but we could not save your profile (${error.message}). Please try again.',
      );
    } catch (_) {
      throw const ProfileCreationException(
        'Your account was created, but we could not save your profile. Please check your connection and try again.',
      );
    }
  }

  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String pin,
  }) {
    return _client.auth.signInWithPassword(
      email: _email(phone),
      password: _password(phone, pin),
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Sends a Supabase SMS code to an existing user's verified phone number.
  Future<void> sendPinResetCode(String phone) {
    return _client.auth.signInWithOtp(phone: phone, shouldCreateUser: false);
  }

  /// Verifies the SMS code, replaces the PIN-derived password, then signs out.
  Future<void> resetPin({
    required String phone,
    required String code,
    required String newPin,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );
    if (response.session == null) {
      throw const AuthException('The verification code could not be verified.');
    }
    try {
      await _client.auth.updateUser(
        UserAttributes(password: _password(phone, newPin)),
      );
    } finally {
      await _client.auth.signOut();
    }
  }

  String? get accessToken => _client.auth.currentSession?.accessToken;

  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _client.from('profiles').select().eq('id', userId).maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchLatestRates() async {
    final rows = await _client
        .from('rates')
        .select('usd_to_slsh, slsh_to_usd')
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Fetches the signed-in user's transactions, newest first.
  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final userId = currentUserId;
    if (userId == null) {
      throw const TransactionException(
        'Sign in to view your transaction history.',
      );
    }
    try {
      final rows = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map(Map<String, dynamic>.from).toList(growable: false);
    } on PostgrestException catch (error) {
      throw TransactionException(
        'Could not load your transaction history (${error.message}).',
      );
    } catch (_) {
      throw const TransactionException(
        'Could not load your transaction history. Check your connection and try again.',
      );
    }
  }

  /// Inserts a transaction for the signed-in user. `status` and `created_at`
  /// are left to their database defaults.
  Future<void> insertTransaction({
    required String type,
    required double amount,
    required String gateway,
    String? fromCurrency,
    String? toCurrency,
    String? referencePhone,
  }) async {
    if (type != 'exchange' && type != 'deposit' && type != 'withdrawal') {
      throw ArgumentError.value(type, 'type', 'Unsupported transaction type.');
    }
    final userId = currentUserId;
    if (userId == null) {
      throw const TransactionException(
        'You must be signed in to save a transaction.',
      );
    }

    try {
      await _client.from('transactions').insert({
        'user_id': userId,
        'type': type,
        'amount': amount,
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'gateway': gateway,
        'reference_phone': referencePhone,
      });
    } on PostgrestException catch (error) {
      throw TransactionException(
        'We could not save your transaction (${error.message}). Please try again.',
      );
    } catch (_) {
      throw const TransactionException(
        'We could not save your transaction. Check your connection and try again.',
      );
    }
  }
}
