import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'optimized_glass.dart';
import '../utils/morph_dialog.dart';
import '../screens/main_scaffold.dart';
import '../widgets/glass_color_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// SHARED WIDGETS
// -----------------------------------------------------------------------------

Widget buildDarkTextField(
  BuildContext context,
  TextEditingController controller,
  String label, {
  bool isNumber = false,
  String? hint,
}) {
  return TextField(
    controller: controller,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    cursorOpacityAnimates: true,
    cursorRadius: const Radius.circular(10), // Match Search Box
    cursorWidth: 2.5,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      labelStyle: TextStyle(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
    ),
  );
}

class ColorSelector extends StatelessWidget {
  final int? selectedColor;
  final ValueChanged<int?> onColorChanged;

  const ColorSelector(
      {super.key, required this.selectedColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    // 5 Major Colors
    final majorColors = [
      0xFFE57373, // Red
      0xFF81C784, // Green
      0xFF64B5F6, // Blue
      0xFFFFD54F, // Amber
      0xFFBA68C8, // Purple
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 1. Recently Used / Current Color
          if (selectedColor != null) ...[
            GestureDetector(
              onTap: () => onColorChanged(null), // Tap to deselect
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(selectedColor!),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4)
                  ],
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              color: Colors.white24,
            ),
            const SizedBox(width: 12),
          ],

          // 2. Major Colors
          ...majorColors.map((c) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  if (selectedColor == c) {
                    onColorChanged(null); // Deselect if already selected
                  } else {
                    onColorChanged(c);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: selectedColor == c
                        ? Border.all(color: Colors.white, width: 2)
                        : Border.all(color: Colors.white10, width: 1),
                  ),
                  child: selectedColor == c
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            );
          }),

          // 3. Divider
          Container(
            width: 1,
            height: 24,
            color: Colors.white24,
          ),
          const SizedBox(width: 12),

          // 4. Color Picker
          GestureDetector(
            onTap: () {
              // Show Custom Glass Dialog
              showMorphDialog(
                context: context,
                builder: (ctx) => GlassColorPickerDialog(
                  initialColor: selectedColor != null
                      ? Color(selectedColor!)
                      : Colors.white,
                  onColorChanged: (color) {
                    if (color == Colors.transparent) {
                      onColorChanged(null);
                    } else {
                      onColorChanged(color.toARGB32());
                    }
                  },
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const SweepGradient(colors: [
                  Colors.red,
                  Colors.green,
                  Colors.blue,
                  Colors.red
                ]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.colorize, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD SUBJECT DIALOG
// -----------------------------------------------------------------------------

void showAddSubjectDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  final targetController = TextEditingController(text: '75');
  final presentController = TextEditingController();
  final proxyController = TextEditingController();
  final notSureController = TextEditingController();
  final absentController = TextEditingController();

  // Default to a random color instead of null (Outline)
  final random = Random();
  final defaultColors = [
    0xFFE57373, // Red
    0xFF81C784, // Green
    0xFF64B5F6, // Blue
    0xFFFFD54F, // Amber
    0xFFBA68C8, // Purple
  ];
  int? selectedColor = defaultColors[random.nextInt(defaultColors.length)];

  showMorphDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return GlassDialogContainer(
        title: "Add Subject",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(attendanceProvider.notifier).addSubject(
                      Subject(
                        name: nameController.text,
                        targetPercentage:
                            int.tryParse(targetController.text) ?? 75,
                        present: int.tryParse(presentController.text) ?? 0,
                        absent: int.tryParse(absentController.text) ?? 0,
                        proxy: int.tryParse(proxyController.text) ?? 0,
                        ambiguous: int.tryParse(notSureController.text) ?? 0,
                        colorValue: selectedColor,
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: Text('Add',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildDarkTextField(context, nameController, 'Subject Name'),
            const SizedBox(height: 12),
            buildDarkTextField(context, targetController, 'Target %',
                isNumber: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildDarkTextField(
                      context, presentController, 'Present',
                      isNumber: true, hint: '0'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildDarkTextField(context, absentController, 'Absent',
                      isNumber: true, hint: '0'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildDarkTextField(context, proxyController, 'Proxy ⚡',
                      isNumber: true, hint: '0'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildDarkTextField(
                      context, notSureController, 'Not Sure ?',
                      isNumber: true, hint: '0'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ColorSelector(
              selectedColor: selectedColor,
              onColorChanged: (c) => setState(() => selectedColor = c),
            ),
          ],
        ),
      );
    }),
  );
}

// -----------------------------------------------------------------------------
// ADD GROUP DIALOG
// -----------------------------------------------------------------------------

void showAddGroupDialog(BuildContext context, WidgetRef ref,
    {Function(Group)? onCreated}) {
  final nameController = TextEditingController();
  int? selectedColor;

  showMorphDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return GlassDialogContainer(
        title: "New Folder",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newGroup = Group(
                  name: nameController.text,
                  subjectIds: [],
                  colorValue: selectedColor,
                );
                ref.read(attendanceProvider.notifier).addGroup(newGroup);
                Navigator.pop(ctx);
                if (onCreated != null) onCreated(newGroup);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildDarkTextField(context, nameController, 'Folder Name'),
            const SizedBox(height: 12),
            ColorSelector(
              selectedColor: selectedColor,
              onColorChanged: (c) => setState(() => selectedColor = c),
            ),
          ],
        ),
      );
    }),
  );
}

// -----------------------------------------------------------------------------
// ADD CLASS DIALOG (From CalendarScreen)
// -----------------------------------------------------------------------------

class AddClassDialog extends ConsumerStatefulWidget {
  final int initialDayOfWeek;
  final DateTime? initialDate; // Added for one-off classes
  const AddClassDialog({
    super.key,
    required this.initialDayOfWeek,
    this.initialDate,
  });

  @override
  ConsumerState<AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends ConsumerState<AddClassDialog> {
  late int _dayOfWeek;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  Color _selectedColor = AppTheme.pastelRed;
  bool _initColor = true;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _teacherController =
      TextEditingController(); // Added
  final TextEditingController _topicController =
      TextEditingController(); // Added
  bool _hasTime = true;
  bool _repeatWeekly = false; // Default: One-off class

  // Custom Repeat Logic
  late DateTime _startDate;
  DateTime? _endDate;
  final Set<int> _selectedWeekIndices =
      {}; // 0 = first week, 1 = second week, etc.

  final _formKey = GlobalKey<FormState>();

  // Recommendations
  List<ClassSession> _recommendations = [];
  final Set<String> _selectedRecommendationIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initColor) {
      _selectedColor = Theme.of(context).colorScheme.primary;
      _initColor = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _dayOfWeek = widget.initialDayOfWeek;
    _fetchRecommendations();

    // Load Preference
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _hasTime = prefs.getBool('addClass_hasTime') ?? true;
        });
      }
    });

    final schedule = ref.read(attendanceProvider).schedule;
    final dayItems = schedule
        .where((s) => s.dayOfWeek == widget.initialDayOfWeek && s.hasTime)
        .toList();

    if (dayItems.isNotEmpty) {
      dayItems.sort((a, b) {
        final aMin = a.endTime.hour * 60 + a.endTime.minute;
        final bMin = b.endTime.hour * 60 + b.endTime.minute;
        return bMin.compareTo(aMin);
      });
      final lastClass = dayItems.first;
      _startTime = lastClass.endTime;
    } else {
      final now = TimeOfDay.now();
      int minute = now.minute;
      int hour = now.hour;
      if (minute < 30) {
        minute = 30;
      } else {
        minute = 0;
        hour = (hour + 1) % 24;
      }
      _startTime = TimeOfDay(hour: hour, minute: minute);
    }
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = startMin + 60;
    _endTime = TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);

    // Initialize Dates
    final now = DateTime.now();
    _startDate = widget.initialDate ?? now;
    // Align start date to the correct day of week if needed
    if (_startDate.weekday != _dayOfWeek) {
      // Find next occurrence or same day
      int daysToAdd = (_dayOfWeek - _startDate.weekday + 7) % 7;
      _startDate = _startDate.add(Duration(days: daysToAdd));
    }
    // Default End Date: 4 weeks from start
    _endDate = _startDate.add(const Duration(days: 28));

    // Select all weeks by default
    _selectedWeekIndices.addAll([0, 1, 2, 3, 4]);
  }

  void _fetchRecommendations() {
    final history = ref.read(attendanceProvider).sessions;
    final subjects = ref.read(attendanceProvider).subjects; // Active subjects
    final activeSubjectNames = subjects.map((s) => s.name).toSet();

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30)); // 30-day lookback
    final lastWeekCutoff =
        now.subtract(const Duration(days: 7)); // Last week priority

    // Filter relevant sessions
    final relevantSessions = history.where((s) {
      bool dayMatch = s.startTime.weekday == _dayOfWeek;
      bool recent = s.startTime.isAfter(cutoff);
      bool exists =
          activeSubjectNames.contains(s.subjectName); // Filter deleted
      return dayMatch && recent && exists;
    }).toList();

    // Group by unique key (Subject + Time)
    final Map<String, List<ClassSession>> groups = {};
    for (var s in relevantSessions) {
      final key = "${s.subjectName}_${s.startTime.hour}:${s.startTime.minute}";
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(s);
    }

    // Convert to list and sort
    final sortedRecommendations = groups.values.map((list) {
      // Use the most recent session as the representative
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      return list.first;
    }).toList();

    sortedRecommendations.sort((a, b) {
      // Priority 1: Was it in the last week?
      final aRecent = a.startTime.isAfter(lastWeekCutoff);
      final bRecent = b.startTime.isAfter(lastWeekCutoff);
      if (aRecent != bRecent) {
        return aRecent ? -1 : 1;
      }

      // Priority 2: Frequency (Count in group)
      final keyA = "${a.subjectName}_${a.startTime.hour}:${a.startTime.minute}";
      final keyB = "${b.subjectName}_${b.startTime.hour}:${b.startTime.minute}";
      final countA = groups[keyA]?.length ?? 0;
      final countB = groups[keyB]?.length ?? 0;
      return countB.compareTo(countA);
    });

    setState(() {
      _recommendations = sortedRecommendations;
    });
  }

  void _toggleRecommendation(ClassSession session) {
    HapticFeedback.selectionClick();
    setState(() {
      final id = session.id;
      if (_selectedRecommendationIds.contains(id)) {
        _selectedRecommendationIds.remove(id);
      } else {
        _selectedRecommendationIds.add(id);
      }

      // Logic to populate fields
      if (_selectedRecommendationIds.length == 1) {
        final singleId = _selectedRecommendationIds.first;
        final singleSession = _recommendations
            .firstWhere((r) => r.id == singleId, orElse: () => session);

        _subjectController.text = singleSession.subjectName;
        _teacherController.text = ""; // Don't copy specific details
        _topicController.text = ""; // Don't copy specific details
        _startTime = TimeOfDay.fromDateTime(singleSession.startTime);
        _endTime = TimeOfDay.fromDateTime(singleSession.endTime);
        _selectedColor = Color(singleSession.colorValue);
        _hasTime = singleSession.hasTime;
      } else if (_selectedRecommendationIds.length > 1) {
        // Multiple Selected: Clear visible fields or show summary in build
        // We do NOT clear controller text here to avoid jarring jumps if they deselect back to 1
        // The build method will handle the "Multiple Selected" masking.
      }
    });
  }

  void _setDuration(Duration duration) {
    if (!_hasTime) return;
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final totalMinutes = startMinutes + duration.inMinutes;
    setState(() {
      _endTime = TimeOfDay(
        hour: (totalMinutes ~/ 60) % 24,
        minute: totalMinutes % 60,
      );
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final subjects = state.subjects;
    final subjectNames = subjects.map((e) => e.name).toList();

    return GlassDialogContainer(
      title: "Add Class",
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subject Autocomplete
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return subjectNames.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      _subjectController.text = selection;
                      final existing = subjects.firstWhere(
                          (s) => s.name == selection,
                          orElse: () => Subject(name: '', colorValue: null));
                      if (existing.colorValue != null) {
                        setState(
                            () => _selectedColor = Color(existing.colorValue!));
                      }
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      if (_subjectController.text !=
                          textEditingController.text) {
                        textEditingController.text = _subjectController.text;
                      }
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        readOnly: _selectedRecommendationIds.length >
                            1, // Read only if multiple
                        cursorOpacityAnimates: true,
                        cursorRadius: const Radius.circular(10),
                        cursorWidth: 2.5,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: "Subject Name",
                          hintText: _selectedRecommendationIds.length > 1
                              ? "Multiple Selected"
                              : null,
                          prefixIcon: Icon(Icons.class_,
                              color: Theme.of(context).colorScheme.primary),
                          labelStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                        ),
                        validator: (val) {
                          if (_selectedRecommendationIds.length > 1) {
                            return null; // Skip validation
                          }
                          return val == null || val.isEmpty ? "Required" : null;
                        },
                        onChanged: (val) => _subjectController.text = val,
                        textInputAction: TextInputAction.next,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          // Width is often unbounded in optionsViewBuilder, so we limit it
                          child: Container(
                            width: MediaQuery.of(context).size.width -
                                64, // Approx width of dialog content
                            margin: const EdgeInsets.only(top: 8),
                            child: OptimizedGlass(
                              borderRadius: BorderRadius.circular(16),
                              sigmaX: 20,
                              sigmaY: 20,
                              fallbackColor:
                                  Theme.of(context).colorScheme.surface,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withValues(
                                          alpha:
                                              0.8), // Increased opacity for better fallback visibility if needed, or stick to glass style
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.2)),
                                ),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                      height: 1,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.1),
                                    ),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final String option =
                                          options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
                  if (_recommendations.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _recommendations.map((session) {
                          final isSelected =
                              _selectedRecommendationIds.contains(session.id);
                          final classColor = Color(session.colorValue);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(session.subjectName),
                              selected: isSelected,
                              checkmarkColor: Colors.white,
                              onSelected: (_) => _toggleRecommendation(session),
                              backgroundColor:
                                  classColor.withValues(alpha: 0.2),
                              selectedColor: classColor,
                              // Ensure label is legible on colored backgrounds
                              labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Color & Day (Moved up)
                  Row(
                    children: [
                      Text("Color: ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final Color? newColor = await showGlassPickerDialog(
                            context,
                            _selectedColor,
                          );
                          if (newColor != null) {
                            setState(() => _selectedColor = newColor);
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Spacer(),
                      // Glass Day Picker
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final selected =
                              await _showGlassDayPicker(context, _dayOfWeek);
                          if (selected != null) {
                            setState(() {
                              _dayOfWeek = selected;
                              _fetchRecommendations();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.3))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                [
                                  "Mon",
                                  "Tue",
                                  "Wed",
                                  "Thu",
                                  "Fri",
                                  "Sat",
                                  "Sun"
                                ][_dayOfWeek - 1],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Repeat Toggle
                  SwitchListTile.adaptive(
                    title: Text("Repeat Weekly",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: Text(
                        _repeatWeekly
                            ? "Custom Schedule (Select Weeks)"
                            : "One-time class for this date only",
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    value: _repeatWeekly,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _repeatWeekly = val);
                    },
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Custom Week Selector UI
                  if (_repeatWeekly) ...[
                    // Date Range Picker
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.date_range,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "From: ${DateFormat('MMM d, yyyy').format(_startDate)}",
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                ),
                                Text(
                                  "To: ${_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'End of Semester'}",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("Select Weeks",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 8),
                    _buildWeekSelector(context),
                    const SizedBox(height: 16),
                  ],

                  // Time
                  SwitchListTile.adaptive(
                    title: Text("Set Time",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                    value: _hasTime,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _hasTime = val);
                      // Persist Preference
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setBool('addClass_hasTime', val);
                      });
                    },
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_hasTime) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                                child: _buildTimePicker(
                                    context,
                                    "Start",
                                    _startTime,
                                    (t) => setState(() => _startTime = t))),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildTimePicker(
                                    context,
                                    "End",
                                    _endTime,
                                    (t) => setState(() => _endTime = t))),
                          ]),
                          const SizedBox(height: 8),
                          // Duration Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                    label: const Text("45m"),
                                    onPressed: () => _setDuration(
                                        const Duration(minutes: 45))),
                                const SizedBox(width: 8),
                                ActionChip(
                                    label: const Text("1h"),
                                    onPressed: () => _setDuration(
                                        const Duration(minutes: 60))),
                                const SizedBox(width: 8),
                                ActionChip(
                                    label: const Text("1.5h"),
                                    onPressed: () => _setDuration(
                                        const Duration(minutes: 90))),
                              ],
                            ),
                          )
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Teacher
                  if (_selectedRecommendationIds.length > 1)
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    "Using original teacher & timings for selected classes.",
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 13))),
                          ],
                        ))
                  else ...[
                    TextFormField(
                      controller: _teacherController,
                      cursorOpacityAnimates: true,
                      cursorRadius: const Radius.circular(10),
                      cursorWidth: 2.5,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: "Teacher Name",
                        prefixIcon: Icon(Icons.person,
                            color: Theme.of(context).colorScheme.primary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _topicController,
                      cursorOpacityAnimates: true,
                      cursorRadius: const Radius.circular(10),
                      cursorWidth: 2.5,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: "Topic",
                        prefixIcon: Icon(Icons.topic,
                            color: Theme.of(context).colorScheme.primary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (_selectedRecommendationIds.length > 1) {
                        // Batch Add Mode
                        HapticFeedback.mediumImpact();

                        // Determine target date
                        DateTime date = widget.initialDate ?? DateTime.now();
                        if (widget.initialDate == null ||
                            widget.initialDate!.weekday != _dayOfWeek) {
                          while (date.weekday != _dayOfWeek) {
                            date = date.add(const Duration(days: 1));
                          }
                        }

                        // Process all selected
                        int count = 0;
                        for (var id in _selectedRecommendationIds) {
                          final session = _recommendations.firstWhere(
                              (r) => r.id == id,
                              orElse: () => ClassSession(
                                  subjectName: '',
                                  startTime: DateTime.now(),
                                  endTime: DateTime.now(),
                                  colorValue: 0));
                          if (session.subjectName.isEmpty) continue;

                          // Construct correct DateTime for target date
                          final startDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              session.startTime.hour,
                              session.startTime.minute);

                          // Calculate duration to get end time
                          final duration =
                              session.endTime.difference(session.startTime);
                          final endDateTime = startDateTime.add(duration);

                          final newSession = ClassSession(
                            subjectName: session.subjectName,
                            startTime: startDateTime, // Use converted time
                            endTime: endDateTime, // Use converted time
                            colorValue: session.colorValue,
                            hasTime: session.hasTime,
                            teacherName: session.teacherName,
                            topic: session.topic,
                            status: AttendanceStatus.pending,
                            isConcrete: true,
                          );

                          ref
                              .read(attendanceProvider.notifier)
                              .addOneOffClass(newSession);
                          count++;
                        }

                        Navigator.pop(context);
                        if (context.mounted) {
                          MainScaffold.showGlassToast(
                              context, "$count Classes Added");
                        }
                        return;
                      }

                      // Standard Form Validation
                      if (_formKey.currentState!.validate()) {
                        HapticFeedback.mediumImpact();

                        if (_repeatWeekly) {
                          // NEW LOGIC: Concrete Weekly Series
                          final sessionsToAdd = <ClassSession>[];

                          // Loop through weeks
                          // Calculate total weeks
                          DateTime cursor = _startDate;
                          int weekIndex = 0;

                          // Ensure correct weekday alignment first?
                          // _startDate is already aligned in initState or picker logic?
                          // Let's ensure cursor starts on the correct weekday >= _startDate
                          while (cursor.weekday != _dayOfWeek) {
                            cursor = cursor.add(const Duration(days: 1));
                          }

                          while (_endDate == null ||
                              cursor.isBefore(
                                  _endDate!.add(const Duration(days: 1)))) {
                            if (_selectedWeekIndices.contains(weekIndex)) {
                              // Create Session
                              final startDateTime = DateTime(
                                cursor.year,
                                cursor.month,
                                cursor.day,
                                _startTime.hour,
                                _startTime.minute,
                              );

                              final endDateTime = DateTime(
                                cursor.year,
                                cursor.month,
                                cursor.day,
                                _endTime.hour,
                                _endTime.minute,
                              );

                              sessionsToAdd.add(ClassSession(
                                subjectName: _subjectController.text.trim(),
                                startTime: startDateTime,
                                endTime: endDateTime,
                                colorValue: _selectedColor.toARGB32(),
                                hasTime: _hasTime,
                                teacherName: _teacherController.text.isNotEmpty
                                    ? _teacherController.text.trim()
                                    : null,
                                topic: _topicController.text.isNotEmpty
                                    ? _topicController.text.trim()
                                    : null,
                                status: AttendanceStatus.pending,
                                isConcrete: true,
                              ));
                            }

                            // Move to next week
                            cursor = cursor.add(const Duration(days: 7));
                            weekIndex++;

                            // Safety break (e.g. 52 weeks max)
                            if (weekIndex > 52) break;
                          }

                          if (sessionsToAdd.isNotEmpty) {
                            ref
                                .read(attendanceProvider.notifier)
                                .importSessions(sessionsToAdd);
                            if (context.mounted) {
                              MainScaffold.showGlassToast(context,
                                  "${sessionsToAdd.length} Weekly Classes Added");
                            }
                          }
                        } else {
                          // One-time Session (Unchanged logic, just simplified/kept)
                          DateTime date = widget.initialDate ?? DateTime.now();
                          if (widget.initialDate == null ||
                              widget.initialDate!.weekday != _dayOfWeek) {
                            while (date.weekday != _dayOfWeek) {
                              date = date.add(const Duration(days: 1));
                            }
                          }

                          final startDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _startTime.hour,
                            _startTime.minute,
                          );

                          final endDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _endTime.hour,
                            _endTime.minute,
                          );

                          final session = ClassSession(
                            subjectName: _subjectController.text.trim(),
                            startTime: startDateTime,
                            endTime: endDateTime,
                            colorValue: _selectedColor.toARGB32(),
                            hasTime: _hasTime,
                            teacherName: _teacherController.text.isNotEmpty
                                ? _teacherController.text.trim()
                                : null,
                            topic: _topicController.text.isNotEmpty
                                ? _topicController.text.trim()
                                : null,
                            status: AttendanceStatus.pending,
                            isConcrete: true,
                          );

                          ref
                              .read(attendanceProvider.notifier)
                              .addOneOffClass(session);
                          if (context.mounted) {
                            MainScaffold.showGlassToast(context, "Class Added");
                          }
                        }

                        Navigator.pop(context);
                      }
                    },
                    child: Text(_selectedRecommendationIds.length > 1
                        ? "Add ${_selectedRecommendationIds.length} Classes"
                        : "Add Class"),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: DateTimeRange(
            start: _startDate,
            end: _endDate ?? _startDate.add(const Duration(days: 28))),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: Theme.of(context).colorScheme.primary,
                surface: const Color(0xFF1E1E1E),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        });

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        // Reset week selection logic?
        // Or just keep it? Let's refresh selection to ALL if range drastically changes?
        // Or keep selected indices valid.

        // Let's re-align start date to weekday
        if (_startDate.weekday != _dayOfWeek) {
          int daysToAdd = (_dayOfWeek - _startDate.weekday + 7) % 7;
          _startDate = _startDate.add(Duration(days: daysToAdd));
        }
        // If aligned start > end, that's weird but possible with short range.
      });
    }
  }

  Widget _buildWeekSelector(BuildContext context) {
    if (_endDate == null) return const SizedBox.shrink();

    // Calculate how many weeks
    int weekCount = 0;
    DateTime cursor = _startDate;
    // Ensure alignment
    while (cursor.weekday != _dayOfWeek) {
      cursor = cursor.add(const Duration(days: 1));
    }

    final weeks = <Map<String, dynamic>>[];
    while (cursor.isBefore(_endDate!.add(const Duration(days: 1)))) {
      weeks.add({
        'index': weekCount,
        'date': cursor,
        'label': DateFormat('MMM d').format(cursor),
      });
      cursor = cursor.add(const Duration(days: 7));
      weekCount++;
      if (weekCount > 52) break; // Safety
    }

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(
          onPressed: () => setState(() {
            for (var w in weeks) {
              _selectedWeekIndices.add(w['index']);
            }
          }),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text("All"),
        ),
        TextButton(
          onPressed: () => setState(() {
            _selectedWeekIndices.clear();
          }),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text("None"),
        ),
      ]),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: weeks.map((w) {
            final idx = w['index'] as int;
            final label = w['label'] as String;
            final isSelected = _selectedWeekIndices.contains(idx);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedWeekIndices.add(idx);
                    } else {
                      _selectedWeekIndices.remove(idx);
                    }
                  });
                },
                checkmarkColor: Colors.white,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay time,
      Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            // Glass Time Picker
            final t = await showGeneralDialog<TimeOfDay>(
              context: context,
              barrierDismissible: true,
              barrierLabel: "Time Picker",
              barrierColor:
                  Colors.transparent, // Handled by GlassDialogContainer
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, anim, secondaryAnim) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    timePickerTheme: TimePickerThemeData(
                      backgroundColor: Colors.transparent,
                      dialHandColor: Theme.of(context).colorScheme.primary,
                      dialBackgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      hourMinuteColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      hourMinuteTextColor:
                          Theme.of(context).colorScheme.onSurface,
                      dayPeriodTextColor:
                          Theme.of(context).colorScheme.onSurface,
                      dayPeriodColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      entryModeIconColor:
                          Theme.of(context).colorScheme.onSurface,
                      helpTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  child: GlassDialogContainer(
                    title: null, // Removed redundant title
                    padding: EdgeInsets.zero, // Minimal padding
                    child: DialogTheme(
                      data: const DialogThemeData(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(24))),
                      ),
                      child: TimePickerDialog(
                        initialTime: time,
                      ),
                    ),
                  ),
                );
              },
              transitionBuilder: (context, anim, secondaryAnim, child) {
                return FadeTransition(
                  opacity:
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                        CurvedAnimation(
                            parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
            );

            if (t != null) onChanged(t);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(time.format(context),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<int?> _showGlassDayPicker(BuildContext context, int currentDay) {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Select Day",
      barrierColor: Colors.transparent, // Handled by GlassDialogContainer
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return GlassDialogContainer(
          title: "Select Day",
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(7, (index) {
                  final dayIndex = index + 1;
                  final isSelected = dayIndex == currentDay;
                  final dayName =
                      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index];
                  return InkWell(
                    onTap: () => Navigator.pop(context, dayIndex),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: Text(
                        dayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedAnim =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return Transform.scale(
          scale: 0.8 + (0.2 * curvedAnim.value),
          child: FadeTransition(
            opacity: curvedAnim,
            child: child,
          ),
        );
      },
    );
  }
}

// Simplified: No need for parentContext anymore
void showGlassMoveToFolderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Set<String> subjectIds,
}) {
  showMorphDialog(
    context: context,
    builder: (_) => GlassMoveToFolderDialog(
      subjectIds: subjectIds,
    ),
  );
}

class GlassMoveToFolderDialog extends ConsumerWidget {
  final Set<String> subjectIds;

  const GlassMoveToFolderDialog({
    super.key,
    required this.subjectIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(attendanceProvider).groups;

    return GlassDialogContainer(
      title: "Move to Folder",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "No folders created yet",
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ...groups.map((g) => ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          g.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        leading: Icon(
                          Icons.folder,
                          size: 28,
                          color: g.colorValue != null
                              ? Color(g.colorValue!)
                              : Colors.amber,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          // Move to this group
                          if (subjectIds.length == 1) {
                            ref
                                .read(attendanceProvider.notifier)
                                .moveSubjectToGroup(subjectIds.first, g.id);
                          } else {
                            ref
                                .read(attendanceProvider.notifier)
                                .moveSubjectsToGroup(subjectIds, g.id);
                          }
                          // Clear selection if multi-select
                          ref.read(selectedSubjectsProvider.notifier).state =
                              {};
                          ref.read(selectedGroupsProvider.notifier).state = {};
                          Navigator.pop(context);
                          MainScaffold.showGlassToast(
                              context, "Moved to ${g.name}");
                        },
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Row(
            children: [
              // New Folder Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Open Add Group Dialog ON TOP of this one
                    // This ensures context remains valid.
                    showAddGroupDialog(context, ref, onCreated: (newGroup) {
                      // Logic after group created
                      if (subjectIds.length == 1) {
                        ref
                            .read(attendanceProvider.notifier)
                            .moveSubjectToGroup(subjectIds.first, newGroup.id);
                      } else {
                        ref
                            .read(attendanceProvider.notifier)
                            .moveSubjectsToGroup(subjectIds, newGroup.id);
                      }
                      ref.read(selectedSubjectsProvider.notifier).state = {};
                      ref.read(selectedGroupsProvider.notifier).state = {};

                      // Now close the Move Dialog
                      Navigator.pop(context);
                      MainScaffold.showGlassToast(
                          context, "Moved to ${newGroup.name}");
                    });
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text("New Folder"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              // Ungroup Button (Always visible)
              // Logic Check: Should we only enable it if the items ARE in a group?
              // Standard behavior: Always available, safe to run even if not in group.
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (subjectIds.length == 1) {
                      ref
                          .read(attendanceProvider.notifier)
                          .moveSubjectToGroup(subjectIds.first, null);
                    } else {
                      ref
                          .read(attendanceProvider.notifier)
                          .moveSubjectsToGroup(subjectIds, null);
                    }
                    ref.read(selectedSubjectsProvider.notifier).state = {};
                    ref.read(selectedGroupsProvider.notifier).state = {};

                    Navigator.pop(context);
                    MainScaffold.showGlassToast(context, "Items ungrouped");
                  },
                  icon: const Icon(Icons.grid_off_rounded),
                  label: const Text("Ungroup"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<Color?> showGlassPickerDialog(
    BuildContext context, Color initialColor) async {
  Color? result = await showMorphDialog<Color>(
    context: context,
    builder: (ctx) => GlassColorPickerDialog(
      initialColor: initialColor,
      onColorChanged: (c) {}, // Handled by pop
    ),
  );
  if (result == Colors.transparent) return null;
  return result ?? initialColor;
}
