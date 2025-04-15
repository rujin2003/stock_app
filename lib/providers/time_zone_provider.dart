import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimeZone {
  indianStandardTime,
  greenwichMeanTime,
}

class TimeZoneNotifier extends StateNotifier<TimeZone> {
  TimeZoneNotifier() : super(TimeZone.indianStandardTime) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimeZone = prefs.getString('time_zone');
    if (savedTimeZone != null) {
      state = TimeZone.values.firstWhere(
        (tz) => tz.toString() == savedTimeZone,
        orElse: () => TimeZone.indianStandardTime,
      );
    }
  }

  Future<void> setTimeZone(TimeZone timeZone) async {
    state = timeZone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('time_zone', timeZone.toString());
  }
}

final timeZoneProvider = StateNotifierProvider<TimeZoneNotifier, TimeZone>((ref) {
  return TimeZoneNotifier();
});

// Helper function to convert time to the selected timezone
DateTime convertToTimeZone(DateTime dateTime, TimeZone timeZone) {
  switch (timeZone) {
    case TimeZone.indianStandardTime:
      // IST is UTC+5:30
      final utcDateTime = dateTime.toUtc();
      return utcDateTime.add(const Duration(hours: 5, minutes: 30));
    case TimeZone.greenwichMeanTime:
      // GMT is UTC+0
      return dateTime.toUtc();
  }
}

// Mapping for display names
Map<TimeZone, String> timeZoneDisplayNames = {
  TimeZone.indianStandardTime: 'Indian Standard Time (IST)',
  TimeZone.greenwichMeanTime: 'Greenwich Mean Time (GMT)',
};

// Mapping for time offsets
Map<TimeZone, String> timeZoneOffsets = {
  TimeZone.indianStandardTime: 'UTC+5:30',
  TimeZone.greenwichMeanTime: 'UTC+0:00',
};
