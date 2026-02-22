import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:google_fonts/google_fonts.dart'; // Add this import

import '../services/holiday_service.dart';
import '../models/models.dart';
import '../widgets/unified_top_bar.dart';
import '../utils/morph_dialog.dart';
import '../widgets/morphing_widget.dart'; // Add this import

class HolidayScreen extends ConsumerWidget {
  const HolidayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidayProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      body: Stack(
        children: [
          // 1. Content
          Positioned.fill(
            child: holidays.isEmpty
                ? _buildEmptyState(context)
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 80 + 16,
                        left: 16,
                        right: 16,
                        bottom: 100, // FAB padding
                      ),
                      itemCount: holidays.length,
                      itemBuilder: (context, index) {
                        final item = holidays[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child:
                                  _buildHolidayTile(context, ref, item, isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // 2. FAB
          Positioned(
            bottom: 32,
            right: 32,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: FloatingActionButton.extended(
                onPressed: () => _showAddHolidayDialog(context, ref),
                label: const Text("Add Holiday"),
                icon: const Icon(Icons.add),
              ),
            ),
          ),

          // 3. Top Bar
          UnifiedTopBar(
            title: "Manage Holidays",
            onBack: () => Navigator.pop(context),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh,
                    color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {
                  ref.read(holidayProvider.notifier).refresh();
                  HapticFeedback.lightImpact();
                },
                tooltip: "Refresh Calendar",
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "No holidays found",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add one or sync with calendar",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayTile(
      BuildContext context, WidgetRef ref, HolidayItem item, bool isDark) {
    final isDeletable = item.type == HolidayType.user;

    final card = Card(
      elevation: 0,
      color: isDark ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDeletable
            ? BorderSide.none
            : BorderSide(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingIcon(context, item.type),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              DateFormat.yMMMMd().format(item.date),
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            if (item.type != HolidayType.user)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _getTypeColor(context, item.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getTypeLabel(item.type),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(context, item.type),
                  ),
                ),
              ),
          ],
        ),
        trailing: isDeletable
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(holidayProvider.notifier).removeHoliday(item);
                },
              )
            : null,
      ),
    );

    if (isDeletable) {
      return Dismissible(
        key: ValueKey("${item.date}_${item.name}"),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 12),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          ref.read(holidayProvider.notifier).removeHoliday(item);
          HapticFeedback.mediumImpact();
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildLeadingIcon(BuildContext context, HolidayType type) {
    IconData icon;
    Color color;

    switch (type) {
      case HolidayType.user:
        icon = Icons.event_note;
        color = Theme.of(context).primaryColor;
        break;
      case HolidayType.national:
        icon = Icons.flag_rounded;
        color = Colors.orange;
        break;
      case HolidayType.calendar:
        icon = Icons.calendar_month;
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _getTypeColor(BuildContext context, HolidayType type) {
    switch (type) {
      case HolidayType.user:
        return Theme.of(context).primaryColor;
      case HolidayType.national:
        return Colors.orange;
      case HolidayType.calendar:
        return Colors.blue;
    }
  }

  String _getTypeLabel(HolidayType type) {
    switch (type) {
      case HolidayType.user:
        return "Manual";
      case HolidayType.national:
        return "National";
      case HolidayType.calendar:
        return "Calendar";
    }
  }

  Future<void> _showAddHolidayDialog(
      BuildContext context, WidgetRef ref) async {
    final TextEditingController nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showMorphDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return GlassDialogContainer(
            title: "Add Holiday",
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    ref.read(holidayProvider.notifier).addHoliday(
                          selectedDate,
                          nameController.text.trim(),
                        );
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                  }
                },
                child: const Text("Add"),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "Event Name",
                    hintText: "e.g. Mass Bunk",
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    // Use Custom Glass Picker
                    await showMorphDialog(
                      context: context,
                      builder: (ctx) => _GlassDatePickerDialog(
                        initialDate: selectedDate,
                        onDateSelected: (picked) {
                          setState(() => selectedDate = picked);
                        },
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.yMMMMd().format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlassDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const _GlassDatePickerDialog(
      {required this.initialDate, required this.onDateSelected});

  @override
  State<_GlassDatePickerDialog> createState() => _GlassDatePickerDialogState();
}

class _GlassDatePickerDialogState extends State<_GlassDatePickerDialog> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    });
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Select date", // Simple title
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
        ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onDateSelected(_selectedDate);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("OK"),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        height: 480, // Increased height to prevent cutting off 6-week months
        child: Column(
          children: [
            // Selected Date Display
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('E, MMM d').format(_selectedDate),
                style: GoogleFonts.outfit(
                  fontSize: 28, // Slightly smaller to save space
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(DateFormat('MMMM yyyy').format(_displayedMonth),
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => Text(d,
                      style: const TextStyle(fontWeight: FontWeight.bold)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildCalendarGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final today = DateTime.now();

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: daysInMonth + firstDayWeekday - 1,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, index) {
        if (index < firstDayWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstDayWeekday - 1) + 1;
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);

        final isSelected = date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;

        return GestureDetector(
          onTap: () => _selectDate(date),
          child: MorphingWidget(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey("hol_${date}_$isSelected"),
              margin: const EdgeInsets.all(4), // Slightly more margin
              decoration: isSelected
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    )
                  : isToday
                      ? BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                          shape: BoxShape.circle,
                        )
                      : null,
              alignment: Alignment.center,
              child: Text(
                "$day",
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
