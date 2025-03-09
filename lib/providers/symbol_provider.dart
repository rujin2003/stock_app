import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/symbol.dart';
import '../services/supabase_service.dart';

// Provider for all symbols fetched from API
final allSymbolsProvider =
    StateNotifierProvider<AllSymbolsNotifier, AsyncValue<List<Symbol>>>((ref) {
  return AllSymbolsNotifier(ref);
});

// Provider for filtered symbols based on search query
final filteredSymbolsProvider =
    StateProvider.family<List<Symbol>, SymbolFilter>((ref, filter) {
  final allSymbolsAsync = ref.watch(allSymbolsProvider);

  return allSymbolsAsync.when(
    data: (allSymbols) {
      if (filter.query.isEmpty) {
        return allSymbols;
      }

      final query = filter.query.toLowerCase();
      return allSymbols.where((symbol) {
        return symbol.code.toLowerCase().contains(query) ||
            symbol.name.toLowerCase().contains(query) ||
            symbol.exchange.toLowerCase().contains(query);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final watchlistProvider = FutureProvider<List<Symbol>>((ref) async {
  final supabaseService = SupabaseService();
  return await supabaseService.getWatchlist();
});

class SymbolFilter {
  final String type;
  final String region;
  final String query;

  SymbolFilter({
    required this.type,
    required this.region,
    this.query = '',
  });
}

class AllSymbolsNotifier extends StateNotifier<AsyncValue<List<Symbol>>> {
  final Ref _ref;

  AllSymbolsNotifier(this._ref) : super(const AsyncValue.data([]));
  final _dio = Dio();
  final _supabaseService = SupabaseService();

  Future<void> fetchSymbols(String type, String region) async {
    try {
      state = const AsyncValue.loading();

      final queryParams = {
        'type': type,
        'region': region,
      };

      final response = await _dio.get(
        'https://api.itick.org/symbol/list',
        queryParameters: queryParams,
        options: Options(
          headers: {'token': dotenv.env['ITICK_API_KEY']!},
        ),
      );

      if (response.data['code'] == 200) {
        final symbols = (response.data['data'] as List)
            .map((item) => Symbol.fromJson(item))
            .toList();

        // Check which symbols are in the watchlist
        final watchlist = await _supabaseService.getWatchlist();
        final watchlistCodes = watchlist.map((s) => s.code).toSet();

        for (var symbol in symbols) {
          symbol.isInWatchlist = watchlistCodes.contains(symbol.code);
        }

        state = AsyncValue.data(symbols);
      } else {
        state = AsyncValue.error('Failed to fetch symbols', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleWatchlist(Symbol symbol) async {
    try {
      if (symbol.isInWatchlist) {
        await _supabaseService.removeFromWatchlist(symbol.code);
      } else {
        await _supabaseService.addToWatchlist(symbol);
      }

      state = AsyncValue.data(state.value!.map((s) {
        if (s.code == symbol.code) {
          return Symbol(
            code: s.code,
            name: s.name,
            type: s.type,
            exchange: s.exchange,
            isInWatchlist: !s.isInWatchlist,
          );
        }
        return s;
      }).toList());

      // Invalidate the watchlist provider to trigger a refresh
      // ignore: unused_result
      _ref.refresh(watchlistProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
