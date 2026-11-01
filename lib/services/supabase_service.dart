import 'package:supabase_flutter/supabase_flutter.dart';

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
