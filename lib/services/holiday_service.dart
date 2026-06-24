import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/providers.dart';
import '../models/models.dart';

final holidayProvider =
    StateNotifierProvider<HolidayNotifier, List<HolidayItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HolidayNotifier(prefs);
});

class HolidayNotifier extends StateNotifier<List<HolidayItem>> {
  final SharedPreferences prefs;
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  HolidayNotifier(this.prefs) : super([]) {
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    final List<HolidayItem> userHolidays = [];
    final List<String>? stored = prefs.getStringList('holidays_v2');

    // Load User Holidays
    if (stored != null) {
      for (final s in stored) {
        try {
          userHolidays.add(HolidayItem.fromJson(jsonDecode(s)));
        } catch (_) {}
      }
    } else {
      // Migration from v1 (List<DateTime>)
      final List<String>? oldStored = prefs.getStringList('holidays');
      if (oldStored != null) {
        for (final s in oldStored) {
          try {
            userHolidays.add(HolidayItem(
              date: DateTime.parse(s),
              name: 'Manual Holiday',
              type: HolidayType.user,
            ));
          } catch (_) {}
        }
      }
    }

    // Load National Holidays
    final nationalHolidays = _getNationalHolidays();

    // Fetch Device Calendar Events (if permitted)
    List<HolidayItem> calendarHolidays = [];
    if (await Permission.calendarFullAccess.isGranted) {
      calendarHolidays = await _fetchCalendarEvents();
    }

    // Merge and Sort
    state = [...userHolidays, ...nationalHolidays, ...calendarHolidays]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> refresh() async {
    await _loadHolidays();
  }

  Future<bool> requestCalendarPermissions() async {
    if (await Permission.calendarFullAccess.request().isGranted) {
      await _loadHolidays();
      return true;
    }
    return false;
  }

  Future<List<HolidayItem>> _fetchCalendarEvents() async {
    List<HolidayItem> events = [];
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final now = DateTime.now();
        final startDate = DateTime(now.year - 1, 1, 1);
        final endDate = DateTime(now.year + 1, 12, 31);

        for (final calendar in calendarsResult.data!) {
          // Filter out read-only if desired, but user wants "from google calendar"
          // We can try to guess "Holidays" calendars by name

          // If user specifically requested "Google Calendar", we might want all events or just holidays?
          // User said "show all events holidays , national recognised holidays , and from google calender"
          // This implies: 1. Core National (hardcoded), 2. Calendar Events (All? or just Holidays?)
          // "all events holidays" might mean "all events AND holidays".
          // I will fetch ALL events from ALL calendars to be safe, but distinctive.

          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: startDate, endDate: endDate),
          );

          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (final e in eventsResult.data!) {
              if (e.start != null) {
                // Skip all day events that are clearly not important? No, keep them.
                // We only care about dates.
                final date = e.start!; // TZDateTime
                events.add(HolidayItem(
                  date: DateTime(date.year, date.month, date.day),
                  name: e.title ?? 'Event',
                  type: HolidayType.calendar,
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return events;
  }

  List<HolidayItem> _getNationalHolidays() {
    // Hardcoded India Holidays 2026 (Example subset)
    // Just returning a few for 2025-2026 for now as "National Recognised"
    return [
      HolidayItem(
          date: DateTime(2025, 1, 26),
          name: "Republic Day",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2025, 3, 14),
          name: "Holi",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2025, 8, 15),
          name: "Independence Day",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2025, 10, 2),
          name: "Gandhi Jayanti",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2025, 12, 25),
          name: "Christmas",
          type: HolidayType.national),

      HolidayItem(
          date: DateTime(2026, 1, 26),
          name: "Republic Day",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2026, 3, 3),
          name: "Holi",
          type: HolidayType.national), // Approx
      HolidayItem(
          date: DateTime(2026, 8, 15),
          name: "Independence Day",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2026, 10, 2),
          name: "Gandhi Jayanti",
          type: HolidayType.national),
      HolidayItem(
          date: DateTime(2026, 12, 25),
          name: "Christmas",
          type: HolidayType.national),
    ];
  }

  Future<void> addHoliday(DateTime date, String name) async {
    final newItem = HolidayItem(
      date: DateTime(date.year, date.month, date.day),
      name: name.isEmpty ? "Manual Holiday" : name,
      type: HolidayType.user,
    );

    // Check dupe in user holidays only? Or allow overlap?
    // Allow overlap but check if exact same item exists in state.
    if (!state.contains(newItem)) {
      // Add and persist
      await _persistUserHoliday(newItem);
      await _loadHolidays(); // Reload to re-sort and merge
    }
  }

  Future<void> removeHoliday(HolidayItem item) async {
    if (item.type != HolidayType.user) return; // Can only remove user holidays

    // Remove from persistence
    final List<String>? stored = prefs.getStringList('holidays_v2');
    if (stored != null) {
      List<HolidayItem> items =
          stored.map((e) => HolidayItem.fromJson(jsonDecode(e))).toList();
      items.removeWhere((e) => e == item);
      await prefs.setStringList(
          'holidays_v2', items.map((e) => jsonEncode(e.toJson())).toList());
    }

    // Also clear v1 if present to avoid resurrection
    await prefs.remove('holidays');

    await _loadHolidays();
  }

  Future<void> _persistUserHoliday(HolidayItem item) async {
    final List<String>? stored = prefs.getStringList('holidays_v2');
    List<HolidayItem> items = [];
    if (stored != null) {
      items = stored.map((e) => HolidayItem.fromJson(jsonDecode(e))).toList();
    }
    items.add(item);
    await prefs.setStringList(
        'holidays_v2', items.map((e) => jsonEncode(e.toJson())).toList());
  }

  bool isHoliday(DateTime date) {
    return state.any((e) =>
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);
  }
}
