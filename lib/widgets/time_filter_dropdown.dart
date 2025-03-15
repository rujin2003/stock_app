import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/time_filter_provider.dart' hide DateTimeRange;

class TimeFilterDropdown extends ConsumerWidget {
  const TimeFilterDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFilter = ref.watch(timeFilterProvider);
    final theme = Theme.of(context);

    return PopupMenuButton<TimeFilterOption>(
      tooltip: 'Filter by time period',
      onSelected: (TimeFilterOption option) {
        if (option == TimeFilterOption.custom) {
          _showCustomDateRangePicker(context, ref);
        } else {
          ref.read(timeFilterProvider.notifier).setOption(option);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<TimeFilterOption>>[
        _buildMenuItem(
          context,
          TimeFilterOption.today,
          'Today',
          Icons.today,
          timeFilter.option == TimeFilterOption.today,
        ),
        _buildMenuItem(
          context,
          TimeFilterOption.lastWeek,
          'Last Week',
          Icons.calendar_view_week,
          timeFilter.option == TimeFilterOption.lastWeek,
        ),
        _buildMenuItem(
          context,
          TimeFilterOption.lastMonth,
          'Last Month',
          Icons.calendar_month,
          timeFilter.option == TimeFilterOption.lastMonth,
        ),
        _buildMenuItem(
          context,
          TimeFilterOption.last3Months,
          'Last 3 Months',
          Icons.calendar_today,
          timeFilter.option == TimeFilterOption.last3Months,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          context,
          TimeFilterOption.custom,
          'Custom Period',
          Icons.date_range,
          timeFilter.option == TimeFilterOption.custom,
        ),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list, size: 18),
        label: Text(
          timeFilter.getDisplayName(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  PopupMenuItem<TimeFilterOption> _buildMenuItem(
    BuildContext context,
    TimeFilterOption option,
    String text,
    IconData icon,
    bool isSelected,
  ) {
    final theme = Theme.of(context);

    return PopupMenuItem<TimeFilterOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? theme.colorScheme.primary : null,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  void _showCustomDateRangePicker(BuildContext context, WidgetRef ref) async {
    final timeFilter = ref.read(timeFilterProvider);
    final initialDateRange = timeFilter.option == TimeFilterOption.custom &&
            timeFilter.startDate != null &&
            timeFilter.endDate != null
        ? DateTimeRange(start: timeFilter.startDate!, end: timeFilter.endDate!)
        : DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          );

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      ref.read(timeFilterProvider.notifier).setCustomDateRange(
            pickedDateRange.start,
            pickedDateRange.end,
          );
    }
  }
}
