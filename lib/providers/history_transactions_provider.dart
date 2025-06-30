import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/unified_transaction.dart';
import './time_filter_provider.dart'; 
import 'dart:developer' as developer;

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
  final Ref _ref; 

  HistoryTransactionsNotifier(this._supabaseClient, this._ref) : super(HistoryTransactionsState()) { 
    developer.log('HistoryTransactionsNotifier initialized', name: 'history_transactions');
    
    // Set up the time filter listener
    _ref.listen<TimeFilter>(timeFilterProvider, (previous, next) {
      final previousRange = previous?.getDateRange();
      final nextRange = next.getDateRange();
      
      developer.log('TimeFilter changed: previous=${previousRange}, next=${nextRange}', name: 'history_transactions');
      
      // Compare date ranges properly using equality
      if (previous == null || previousRange != nextRange) {
        developer.log('TimeFilter changed significantly, fetching initial transactions', name: 'history_transactions');
        // Use Future.microtask to ensure we're not in a build phase
        Future.microtask(() => fetchInitialTransactions());
      }
    });
  }

  // Add a method to initialize the provider
  Future<void> initialize() async {
    developer.log('Initializing HistoryTransactionsNotifier', name: 'history_transactions');
    await fetchInitialTransactions();
  }

  Future<void> fetchInitialTransactions() async {
    if (state.isLoading) {
      developer.log('fetchInitialTransactions: Already loading, skipping', name: 'history_transactions');
      return;
    }
    
    developer.log('fetchInitialTransactions started', name: 'history_transactions');
    state = state.copyWith(isLoading: true, currentPage: 0, transactions: [], hasMore: true, clearError: true);
    await _fetchTransactions(page: 0);
    developer.log('fetchInitialTransactions completed with ${state.transactions.length} transactions', name: 'history_transactions');
  }

  Future<void> fetchMoreTransactions() async {
    developer.log('fetchMoreTransactions called, currentPage=${state.currentPage}', name: 'history_transactions');
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      developer.log('fetchMoreTransactions aborted: isLoading=${state.isLoading}, isLoadingMore=${state.isLoadingMore}, hasMore=${state.hasMore}', name: 'history_transactions');
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    await _fetchTransactions(page: state.currentPage + 1);
    developer.log('fetchMoreTransactions completed, now have ${state.transactions.length} transactions', name: 'history_transactions');
  }

  Future<void> _fetchTransactions({required int page}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        developer.log('_fetchTransactions: User not authenticated', name: 'history_transactions');
        state = state.copyWith(error: "User not authenticated.", isLoading: false, isLoadingMore: false, hasMore: false);
        return;
      }

      final timeFilter = _ref.read(timeFilterProvider);
      final dateRange = timeFilter.getDateRange();
      
      developer.log('_fetchTransactions: Fetching page=$page with date filter: ${timeFilter.option.name}, start=${dateRange.start.toIso8601String()}, end=${dateRange.end.toIso8601String()}', name: 'history_transactions');

      final offset = page * _transactionsPageLimit;

      DateTime effectiveEndDate;
      if (timeFilter.option == TimeFilterOption.today || 
          timeFilter.option == TimeFilterOption.lastWeek || 
          timeFilter.option == TimeFilterOption.lastMonth || 
          timeFilter.option == TimeFilterOption.lastThreeMonths) {
        effectiveEndDate = dateRange.end; // This is 'now' for these filter options
      } else {
        // For TimeFilterOption.custom (and any other future cases), use the end of the day of dateRange.end
        effectiveEndDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59, 999);
      }

      developer.log('_fetchTransactions: effectiveEndDate=${effectiveEndDate.toIso8601String()}', name: 'history_transactions');

      // Fetch from public.transactions
      var systemQuery = _supabaseClient
          .from('transactions')
          .select()
          .eq('user_id', userId);

      systemQuery = systemQuery.gte('created_at', dateRange.start.toIso8601String());
      systemQuery = systemQuery.lte('created_at', effectiveEndDate.toIso8601String()); // Use effectiveEndDate

      developer.log('_fetchTransactions: Executing systemQuery for transactions', name: 'history_transactions');
      
      final systemTransactionsResponse = await systemQuery
          .order('created_at', ascending: false)
          .limit(_transactionsPageLimit)
          .range(offset, offset + _transactionsPageLimit - 1);

      developer.log('_fetchTransactions: systemTransactionsResponse length=${(systemTransactionsResponse as List).length}', name: 'history_transactions');

      // Fetch from public.account_transactions
      var accountQuery = _supabaseClient
          .from('account_transactions')
          .select()
          .eq('user_id', userId);

      accountQuery = accountQuery.gte('created_at', dateRange.start.toIso8601String());
      accountQuery = accountQuery.lte('created_at', effectiveEndDate.toIso8601String()); // Use effectiveEndDate

      developer.log('_fetchTransactions: Executing accountQuery for account_transactions', name: 'history_transactions');

      final accountTransactionsResponse = await accountQuery
          .order('created_at', ascending: false)
          .limit(_transactionsPageLimit) 
          .range(offset, offset + _transactionsPageLimit -1);

      developer.log('_fetchTransactions: accountTransactionsResponse length=${(accountTransactionsResponse as List).length}', name: 'history_transactions');

      final List<UnifiedTransaction> fetchedSystemTransactions = (systemTransactionsResponse)
          .map((data) => UnifiedTransaction.fromSystemTransaction(data))
          .toList();

      final List<UnifiedTransaction> fetchedAccountTransactions = (accountTransactionsResponse)
          .map((data) => UnifiedTransaction.fromAccountTransaction(data))
          .toList();
      
      List<UnifiedTransaction> combined = [...fetchedSystemTransactions, ...fetchedAccountTransactions];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      developer.log('_fetchTransactions: Combined transactions length=${combined.length}', name: 'history_transactions');
      
      final newTransactions = combined; 

      final allTransactions = page == 0 ? newTransactions : [...state.transactions, ...newTransactions];
      
      // Deduplicate based on transaction ID to ensure uniqueness if items could come from different queries but be the same.
      final Map<String, UnifiedTransaction> uniqueMap = {};
      for (var tx in allTransactions) {
        uniqueMap[tx.id] = tx; // Assuming UnifiedTransaction has a unique 'id' field
      }
      final uniqueTransactions = uniqueMap.values.toList();
      uniqueTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      developer.log('_fetchTransactions: Final uniqueTransactions length=${uniqueTransactions.length}', name: 'history_transactions');
      
      state = state.copyWith(
        transactions: uniqueTransactions,
        isLoading: false,
        isLoadingMore: false,
        hasMore: newTransactions.length >= _transactionsPageLimit, 
        error: null,
        currentPage: page,
      );

    } catch (e) {
      String errorMessage = e.toString();
      if (e is PostgrestException) {
        errorMessage = 'Supabase error: ${e.message} (code: ${e.code})';
      }
      developer.log('_fetchTransactions ERROR: $errorMessage', name: 'history_transactions', error: e);
      state = state.copyWith(error: errorMessage, isLoading: false, isLoadingMore: false, hasMore: false);
    }
  }
  
  void retry() {
    developer.log('retry called', name: 'history_transactions');
    fetchInitialTransactions();
  }
}

final historyTransactionsProvider = StateNotifierProvider<HistoryTransactionsNotifier, HistoryTransactionsState>((ref) {
  final supabaseClient = Supabase.instance.client;
  return HistoryTransactionsNotifier(supabaseClient, ref); 
});

