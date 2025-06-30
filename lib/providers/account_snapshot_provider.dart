import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import 'time_filter_provider.dart' as time_filter;

// Provider for the AccountService
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService();
});

// Provider for daily account snapshot
final dailyAccountSnapshotProvider = FutureProvider<void>((ref) async {
  final accountService = ref.watch(accountServiceProvider);
  await accountService.createDailyAccountSnapshot();
});

// Provider for filtered account snapshots based on time filter
final filteredAccountSnapshotsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final accountService = ref.watch(accountServiceProvider);
  final timeFilter = ref.watch(time_filter.timeFilterProvider);
  
  // For today, return empty list as we use current data
  if (timeFilter.option == time_filter.TimeFilterOption.today) {
    return [];
  }

  final dateRange = timeFilter.getDateRange();
  return accountService.getAccountSnapshots(DateTimeRange(
    start: dateRange.start,
    end: dateRange.end,
  ));
});

// Provider for latest account snapshot
final latestAccountSnapshotProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final accountService = ref.watch(accountServiceProvider);
  final timeFilter = ref.watch(time_filter.timeFilterProvider);
  
  // For today, return null as we use current data
  if (timeFilter.option == time_filter.TimeFilterOption.today) {
    return null;
  }

  final dateRange = timeFilter.getDateRange();
  final snapshots = await accountService.getAccountSnapshots(DateTimeRange(
    start: dateRange.start,
    end: dateRange.end,
  ));
  return snapshots.isNotEmpty ? snapshots.first : null;
}); 