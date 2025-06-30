import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';

enum TimeFilterOption {
  today,
  lastWeek,
  lastMonth,
  lastThreeMonths,
  lastYear,
  allTime,
  custom,
}

class TimeFilter {
  final TimeFilterOption option;
  final DateTime? startDate;
  final DateTime? endDate;

  TimeFilter(this.option, {this.startDate, this.endDate});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeFilter &&
        other.option == option &&
        (other.startDate == null && startDate == null || 
         other.startDate != null && startDate != null && other.startDate!.isAtSameMomentAs(startDate!)) &&
        (other.endDate == null && endDate == null || 
         other.endDate != null && endDate != null && other.endDate!.isAtSameMomentAs(endDate!));
  }
  
  @override
  int get hashCode => option.hashCode ^ startDate.hashCode ^ endDate.hashCode;

  DateTimeRange getDateRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    switch (option) {
      case TimeFilterOption.today:
        return DateTimeRange(
          start: startOfDay,
          end: now,
        );
      case TimeFilterOption.lastWeek:
        return DateTimeRange(
          start: startOfDay.subtract(const Duration(days: 7)),
          end: now,
        );
      case TimeFilterOption.lastMonth:
        return DateTimeRange(
          start: startOfDay.subtract(const Duration(days: 30)),
          end: now,
        );
      case TimeFilterOption.lastThreeMonths:
        return DateTimeRange(
          start: startOfDay.subtract(const Duration(days: 90)),
          end: now,
        );
      case TimeFilterOption.lastYear:
        return DateTimeRange(
          start: startOfDay.subtract(const Duration(days: 365)),
          end: now,
        );
      case TimeFilterOption.allTime:
        return DateTimeRange(
          start: DateTime(2000),
          end: now,
        );
      case TimeFilterOption.custom:
        if (startDate != null && endDate != null) {
          return DateTimeRange(start: startDate!, end: endDate!);
        }
        // Default to last month if custom dates not set
        return DateTimeRange(
          start: startOfDay.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  // Get display name for the filter option
  String getDisplayName() {
    switch (option) {
      case TimeFilterOption.today:
        return 'Today';
      case TimeFilterOption.lastWeek:
        return 'Last Week';
      case TimeFilterOption.lastMonth:
        return 'Last Month';
      case TimeFilterOption.lastThreeMonths:
        return 'Last 3 Months';
      case TimeFilterOption.lastYear:
        return 'Last Year';
      case TimeFilterOption.allTime:
        return 'All Time';
      case TimeFilterOption.custom:
        if (startDate != null && endDate != null) {
          return '${DateFormat('MMM d').format(startDate!)} - ${DateFormat('MMM d').format(endDate!)}';
        }
        return 'Custom Period';
    }
  }

  TimeFilter copyWith({
    TimeFilterOption? newOption,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return TimeFilter(
      newOption ?? option,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

// Date range helper class
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({
    required this.start,
    required this.end,
  });

  bool includes(DateTime date) {
    return date.isAfter(start) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  @override
  String toString() {
    return 'DateTimeRange(start: ${start.toIso8601String()}, end: ${end.toIso8601String()})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateTimeRange &&
        other.start.isAtSameMomentAs(start) &&
        other.end.isAtSameMomentAs(end);
  }
  
  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

// Provider for time filter
final timeFilterProvider = StateNotifierProvider<TimeFilterNotifier, TimeFilter>((ref) {
  return TimeFilterNotifier();
});

class TimeFilterNotifier extends StateNotifier<TimeFilter> {
  TimeFilterNotifier() : super(TimeFilter(TimeFilterOption.today));

  void setOption(TimeFilterOption option) {
    state = state.copyWith(newOption: option);
  }

  void setCustomDateRange(DateTime startDate, DateTime endDate) {
    state = state.copyWith(
      newOption: TimeFilterOption.custom,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
