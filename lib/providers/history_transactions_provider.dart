import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/unified_transaction.dart';

const int _transactionsPageLimit = 20;

class HistoryTransactionsState {
  final List<UnifiedTransaction> transactions;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int currentPage;

  HistoryTransactionsState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  HistoryTransactionsState copyWith({
    List<UnifiedTransaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    int? currentPage,
  }) {
    return HistoryTransactionsState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class HistoryTransactionsNotifier extends StateNotifier<HistoryTransactionsState> {
  final SupabaseClient _supabaseClient;

  HistoryTransactionsNotifier(this._supabaseClient) : super(HistoryTransactionsState()) {
    fetchInitialTransactions();
  }

  Future<void> fetchInitialTransactions() async {
    state = state.copyWith(isLoading: true, currentPage: 0, transactions: [], hasMore: true, clearError: true);
    await _fetchTransactions(page: 0);
  }

  Future<void> fetchMoreTransactions() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    await _fetchTransactions(page: state.currentPage + 1);
  }

  Future<void> _fetchTransactions({required int page}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(error: "User not authenticated.", isLoading: false, isLoadingMore: false, hasMore: false);
        return;
      }

      final offset = page * _transactionsPageLimit;

      // Fetch from public.transactions
      final systemTransactionsResponse = await _supabaseClient
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(_transactionsPageLimit)
          .range(offset, offset + _transactionsPageLimit - 1);

      // Fetch from public.account_transactions
      final accountTransactionsResponse = await _supabaseClient
          .from('account_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(_transactionsPageLimit) 
          .range(offset, offset + _transactionsPageLimit -1); // Apply same limit logic for combining fairly

      final List<UnifiedTransaction> fetchedSystemTransactions = (systemTransactionsResponse as List)
          .map((data) => UnifiedTransaction.fromSystemTransaction(data as Map<String, dynamic>))
          .toList();

      final List<UnifiedTransaction> fetchedAccountTransactions = (accountTransactionsResponse as List)
          .map((data) => UnifiedTransaction.fromAccountTransaction(data as Map<String, dynamic>))
          .toList();
      
      List<UnifiedTransaction> combined = [...fetchedSystemTransactions, ...fetchedAccountTransactions];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Take top N after combining and sorting for the current page if we fetched more than needed from each source
      // This is a simplified combination strategy. A more robust one might fetch _transactionsPageLimit from each,
      // combine, sort, and then take the top _transactionsPageLimit from the combined pool for that "page",
      // managing separate cursors/offsets for each table if true chronological pagination across both is needed.
      // For now, we combine current page fetches and sort them.

      final newTransactions = combined; // Potentially more than _transactionsPageLimit if both sources had data

      final allTransactions = page == 0 ? newTransactions : [...state.transactions, ...newTransactions];
      // Deduplicate, just in case, though unlikely with UUIDs and separate tables
      final uniqueTransactions = allTransactions.toSet().toList(); 
      uniqueTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));


      state = state.copyWith(
        transactions: uniqueTransactions,
        isLoading: false,
        isLoadingMore: false,
        hasMore: newTransactions.length >= _transactionsPageLimit, // Approximation: if combined fetch was less than limit, likely no more.
                                                              // More accurate: check if *both* sources returned less than their individual limits.
                                                              // Or, if the combined list after sorting and taking _transactionsPageLimit still has items.
                                                              // For simplicity, if the combined new items are less than page limit, assume no more.
                                                              // This might need refinement for perfect pagination.
        error: null,
        currentPage: page,
      );

    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false, isLoadingMore: false, hasMore: false);
    }
  }
  
  void retry() {
    fetchInitialTransactions();
  }
}

final historyTransactionsProvider = StateNotifierProvider<HistoryTransactionsNotifier, HistoryTransactionsState>((ref) {
  final supabaseClient = Supabase.instance.client;
  return HistoryTransactionsNotifier(supabaseClient);
});
