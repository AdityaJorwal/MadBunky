import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mad_bunky/models/models.dart';
import '../services/log_service.dart';
import '../utils/morph_dialog.dart';

class PdfConfirmationDialog extends StatefulWidget {
  final List<ClassSession> extractedSessions;
  final DateTime initialDate; // Usually today or selected week start
  final String? instituteName;
  final String? dateRange;
  final String? standardInfo;
  final bool showSaveOption;
  final Function(List<ClassSession>, DateTime, bool) onConfirm;

  const PdfConfirmationDialog({
    super.key,
    required this.extractedSessions,
    required this.initialDate,
    this.instituteName,
    this.dateRange,
    this.standardInfo,
    this.showSaveOption = false,
    required this.onConfirm,
  });

  @override
  State<PdfConfirmationDialog> createState() => _PdfConfirmationDialogState();
}

class _PdfConfirmationDialogState extends State<PdfConfirmationDialog> {
  late DateTime _selectedDate;
  late List<ClassSession> _sessions;
  final Set<String> _allBatches = {};
  Set<String> _selectedBatches = {};
  final Set<String> _excludedSessionIds = {};
  bool _saveToSchedule = false;

  final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');
  final DateFormat _timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _sessions = widget.extractedSessions;

    // 1. Collect Batches
    for (var s in _sessions) {
      if (s.batch != null && s.batch!.isNotEmpty) {
        _allBatches.add(s.batch!);
      }
    }
    _selectedBatches = Set.from(_allBatches);
  }

  // Helper to detect if sessions have real dates
  bool get _hasRealDates {
    if (_sessions.isEmpty) return false;
    return _sessions.any((s) => s.startTime.year > 2020);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: "Select Start Date for this Schedule",
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prepare Data
    final batchFilteredSessions = _sessions.where((s) {
      if (s.batch != null && !_selectedBatches.contains(s.batch)) {
        return false;
      }
      return true; // We show them, but maybe unchecked if excluded
    }).toList();

    // Calculate dates for display list
    List<ClassSession> uiSessions = batchFilteredSessions;
    if (batchFilteredSessions.isNotEmpty &&
        widget.dateRange == null &&
        !_hasRealDates) {
      batchFilteredSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      final anchor = batchFilteredSessions.first.startTime;
      final targetStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final anchorStart = DateTime(anchor.year, anchor.month, anchor.day);
      final diff = targetStart.difference(anchorStart).inDays;
      if (diff != 0) {
        uiSessions = batchFilteredSessions.map((s) {
          return s.copyWith(
            startTime: s.startTime.add(Duration(days: diff)),
            endTime: s.endTime.add(Duration(days: diff)),
          );
        }).toList();
      }
    }

    // Sort
    uiSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final selectedCount =
        uiSessions.where((s) => !_excludedSessionIds.contains(s.id)).length;

    // REDESIGN: Standard Dialog with constraints
    return Dialog(
      backgroundColor: Colors.transparent, // We do our own glass
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Important for Dialog to wrap content
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Column(
                      children: [
                        Text(
                          "Import Schedule",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$selectedCount classes selected",
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // --- SCROLLABLE CONTENT ---
                  // Use Flexible so it takes available space but allows scrolling
                  Flexible(
                    child: ListView(
                      shrinkWrap:
                          true, // Allow it to be smaller than max height
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      children: [
                        // 1. Info / Date Range
                        if (widget.dateRange != null) ...[
                          Text(
                            widget.standardInfo ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(widget.dateRange!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                        ],

                        // 2. Date Picker (if needed)
                        if (widget.dateRange == null && !_hasRealDates)
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Start Date:"),
                                  Text(
                                    _dateFormat.format(_selectedDate),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (widget.dateRange == null && _hasRealDates)
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Row(children: [
                                Icon(Icons.check,
                                    size: 16, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text("Dates detected automatically.",
                                        style: TextStyle(
                                            color: Colors.green, fontSize: 12)))
                              ])),

                        const SizedBox(height: 16),
                        // 3. Batches
                        if (_allBatches.isNotEmpty) ...[
                          const Text("Filter Batches:",
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: _allBatches.map((batch) {
                              final isSelected =
                                  _selectedBatches.contains(batch);
                              return FilterChip(
                                label: Text(batch),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedBatches.add(batch);
                                    } else {
                                      _selectedBatches.remove(batch);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 4. Classes List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Classes",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                TextButton(
                                    onPressed: () => setState(
                                        () => _excludedSessionIds.clear()),
                                    child: const Text("All",
                                        style: TextStyle(fontSize: 12))),
                                TextButton(
                                    onPressed: () {
                                      // Exclude all currently visible
                                      setState(() {
                                        for (var s in uiSessions) {
                                          _excludedSessionIds.add(s.id);
                                        }
                                      });
                                    },
                                    child: const Text("None",
                                        style: TextStyle(fontSize: 12))),
                              ],
                            )
                          ],
                        ),

                        // The Actual List Items
                        ...uniqueDaySessions(uiSessions, context),

                        if (widget.showSaveOption)
                          CheckboxListTile(
                            value: _saveToSchedule,
                            onChanged: (v) =>
                                setState(() => _saveToSchedule = v ?? false),
                            title: const Text("Set as Home Schedule"),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),
                  // --- FOOTER ACTIONS ---
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              try {
                                final finalSessions = uiSessions
                                    .where((s) =>
                                        !_excludedSessionIds.contains(s.id))
                                    .toList();
                                widget.onConfirm(finalSessions, _selectedDate,
                                    _saveToSchedule);
                                Navigator.pop(context);
                              } catch (e, stack) {
                                debugPrint("Import Error: $e\n$stack");
                                LogService().error("Import Error: $e", stack);
                                showMorphSnackBar(
                                  context,
                                  message: "Error: $e",
                                  isError: true,
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text("Confirm Import"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build list items with headers
  List<Widget> uniqueDaySessions(
      List<ClassSession> sessions, BuildContext context) {
    if (sessions.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.all(16), child: Text("No classes found."))
      ];
    }

    List<Widget> widgets = [];
    DateTime? lastDate;

    for (var session in sessions) {
      bool isNewDay = lastDate == null ||
          lastDate.day != session.startTime.day ||
          lastDate.month != session.startTime.month;

      if (isNewDay) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            _dateFormat.format(session.startTime),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ));
        lastDate = session.startTime;
      }

      final isSelected = !_excludedSessionIds.contains(session.id);

      widgets.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Color(session.colorValue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Color(session.colorValue).withValues(alpha: 0.3)),
        ),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _excludedSessionIds.remove(session.id);
                } else {
                  _excludedSessionIds.add(session.id);
                }
              });
            },
          ),
          title: Text(session.subjectName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              "${_timeFormat.format(session.startTime)} - ${_timeFormat.format(session.endTime)}"),
          trailing: _buildBadge(session),
        ),
      ));
    }
    return widgets;
  }

  Widget? _buildBadge(ClassSession session) {
    if (session.subjectName.toLowerCase().contains("exam") ||
        session.subjectName.toLowerCase().contains("test")) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(4)),
        child: const Text("EXAM",
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );
    }
    return null;
  }
}
