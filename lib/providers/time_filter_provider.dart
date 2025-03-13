import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimeFilterOption {
  today,
  lastWeek,
  lastMonth,
  last3Months,
  custom,
}

class TimeFilter {
  final TimeFilterOption option;
  final DateTime? startDate;
  final DateTime? endDate;

  TimeFilter({
    this.option = TimeFilterOption.lastMonth,
    this.startDate,
    this.endDate,
  });

  // Get the actual date range based on the selected option
  DateTimeRange getDateRange() {
    final now = DateTime.now();

    switch (option) {
      case TimeFilterOption.today:
        final today = DateTime(now.year, now.month, now.day);
        return DateTimeRange(
          start: today,
          end: now,
        );

      case TimeFilterOption.lastWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return DateTimeRange(
          start: weekAgo,
          end: now,
        );

      case TimeFilterOption.lastMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return DateTimeRange(
          start: monthAgo,
          end: now,
        );

      case TimeFilterOption.last3Months:
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return DateTimeRange(
          start: threeMonthsAgo,
          end: now,
        );

      case TimeFilterOption.custom:
        if (startDate != null && endDate != null) {
          return DateTimeRange(
            start: startDate!,
            end: endDate!,
          );
        } else {
          // Default to last month if custom dates are not set
          final monthAgo = DateTime(now.year, now.month - 1, now.day);
          return DateTimeRange(
            start: monthAgo,
            end: now,
          );
        }
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
      case TimeFilterOption.last3Months:
        return 'Last 3 Months';
      case TimeFilterOption.custom:
        if (startDate != null && endDate != null) {
          return 'Custom Period';
        } else {
          return 'Custom Period';
        }
    }
  }

  TimeFilter copyWith({
    TimeFilterOption? option,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return TimeFilter(
      option: option ?? this.option,
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
}

// Provider for time filter
final timeFilterProvider =
    StateNotifierProvider<TimeFilterNotifier, TimeFilter>((ref) {
  return TimeFilterNotifier();
});

class TimeFilterNotifier extends StateNotifier<TimeFilter> {
  TimeFilterNotifier() : super(TimeFilter());

  void setOption(TimeFilterOption option) {
    state = state.copyWith(option: option);
  }

  void setCustomDateRange(DateTime startDate, DateTime endDate) {
    state = state.copyWith(
      option: TimeFilterOption.custom,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
