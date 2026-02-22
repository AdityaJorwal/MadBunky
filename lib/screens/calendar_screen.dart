import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../widgets/rounded_donut_chart.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../utils/globals.dart';
import '../utils/morph_dialog.dart';
import 'package:file_picker/file_picker.dart';
// import '../services/pdf_scheduler_service.dart'; // Removed
// import '../widgets/pdf_processing_dialog.dart'; // Removed
// import '../widgets/pdf_confirmation_dialog.dart'; // Removed
// import '../widgets/pdf_preview_dialog.dart'; // Removed
// import '../widgets/batch_selection_dialog.dart'; // Removed
// import '../widgets/scan_options_dialog.dart'; // Removed
import 'package:image_picker/image_picker.dart'; // Restored

import 'main_scaffold.dart';
import '../widgets/google_calendar_import_dialog.dart';

import '../widgets/spark_widget.dart';
import '../widgets/thunder_overlay.dart';

import '../widgets/morphing_widget.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(calendarViewProvider);
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: initialIndex);

    // Sync Global Immediately
    calendarTabPosition.value = initialIndex.toDouble();

    _tabController.animation?.addListener(() {
      // Sync Real-Time Position Global
      calendarTabPosition.value = _tabController.animation!.value;
    });

    _tabController.addListener(() {
      // Sync TabController -> Provider (e.g. on Swipe)
      // We only update if the index actually settled
      if (!_tabController.indexIsChanging) {
        final currentIndex = _tabController.index;
        // Check provider to avoid loops
        if (ref.read(calendarViewProvider) != currentIndex) {
          ref.read(calendarViewProvider.notifier).state = currentIndex;
          HapticFeedback.selectionClick();
        }
      }
    });

    // Only set up sharing intent on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // For sharing or opening urls/text coming from outside the app while the app is in the memory
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedFile(value.first.path);
        }
      }, onError: (err) {
        debugPrint("getIntentDataStream error: $err");
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedFile(value.first.path);
        }
      });
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // No longer needed for PDF, but can be reused for mbweektemplate via intent if needed
  void _handleSharedFile(String path) async {
    if (path.toLowerCase().endsWith('.mbweektemplate')) {
      final file = File(path);

      showMorphDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) =>
              const Center(child: CircularProgressIndicator.adaptive()));

      try {
        // We reuse the logic from importScheduleFromMBWeekTemplate but we read file directly here to pass to review
        final jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        final items = decoded.map((e) => ScheduleTemplate.fromJson(e)).toList();

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        if (items.isEmpty) {
          if (context.mounted) {
            MainScaffold.showGlassToast(context, "No schedule data found.",
                isError: true);
          }
          return;
        }
        _showImportReviewDialog(items);
      } catch (e) {
        if (!mounted) return;
        if (context.mounted) {
          Navigator.pop(context);
          MainScaffold.showGlassToast(context, "Error parsing file: $e",
              isError: true);
        }
      }
    }
  }

  void _showImportReviewDialog(List<ScheduleTemplate> items) {
    showMorphDialog(
        context: context,
        builder: (context) => GlassDialogContainer(
              title: "Found ${items.length} Classes",
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary)),
                ),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close review
                      // Open Week Selection
                      showMorphDialog(
                        context: context,
                        builder: (ctx) => _WeekSelectionDialog(
                          onWeekSelected: (weekStart) async {
                            final notifier =
                                ref.read(attendanceProvider.notifier);
                            await notifier.importScheduleForWeek(
                                items, weekStart);

                            if (context.mounted) {
                              MainScaffold.showGlassToast(context,
                                  "Schedule applied to selected week!");
                            }
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Select Week to Apply"))
              ],
              child: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return ListTile(
                        title: Text(
                          item.subjectName,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          "${_dayToString(item.dayOfWeek)} ${item.startTime.format(context)} - ${item.endTime.format(context)}",
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      );
                    }),
              ),
            ));
  }

  String _dayToString(int day) {
    switch (day) {
      case 1:
        return "Mon";
      case 2:
        return "Tue";
      case 3:
        return "Wed";
      case 4:
        return "Thu";
      case 5:
        return "Fri";
      case 6:
        return "Sat";
      case 7:
        return "Sun";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // SYNC: Listen to provider changes -> Animate TabController
    ref.listen(calendarViewProvider, (_, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    // ACTION: Listen to Menu Actions from MainScaffold
    ref.listen(calendarMenuActionProvider, (_, action) {
      if (action == null) return;
      Future.microtask(
          () => ref.read(calendarMenuActionProvider.notifier).state = null);

      switch (action) {
        case CalendarMenuAction.duplicate:
          _showDuplicateDialog(context);
          break;
        case CalendarMenuAction.import:
          _handleImportWeekSchedule();
          break;
        case CalendarMenuAction.restoreBackup:
          _handleImportWeekSchedule();
          break;
        case CalendarMenuAction.importPdf:
          _pickAndProcessPdf();
          break;
        case CalendarMenuAction.cameraScan:
          _processCamera();
          break;
        case CalendarMenuAction.export:
          _showExportOptionsDialog(context);
          break;
        case CalendarMenuAction.stats:
          // Stats handling (future implementation)
          break;
      }
    });

    // ACTION: Listen to Shared Files (PDF/Images)
    ref.listen(sharedFileQueueProvider, (_, path) {
      if (path != null) {
        // Clear state immediately to avoid re-triggering
        Future.microtask(
            () => ref.read(sharedFileQueueProvider.notifier).state = null);
        // Process the file
        Future.microtask(() => _processFileSimple(path));
      }
    });

    // FIX: Clear selection when date changes to prevent 'Ghost Selection'
    ref.listen(calendarSelectedDateProvider, (previous, next) {
      if (previous != next) {
        ref.read(calendarSelectionProvider.notifier).state = {};
      }
    });

    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final selectedIds = ref.watch(calendarSelectionProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isSelectionMode) {
          ref.read(calendarSelectionProvider.notifier).state = {};
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _DayView(
                  selectedDate: selectedDate,
                  onDateChanged: (date) {
                    HapticFeedback.mediumImpact();
                    ref.read(calendarSelectedDateProvider.notifier).state =
                        date;
                  },
                  isSelectionMode: isSelectionMode,
                  selectedIds: selectedIds,
                  onToggleSelection: (id) {
                    HapticFeedback.selectionClick();
                    final current = ref.read(calendarSelectionProvider);
                    if (current.contains(id)) {
                      ref.read(calendarSelectionProvider.notifier).state = {
                        ...current
                      }..remove(id);
                    } else {
                      ref.read(calendarSelectionProvider.notifier).state = {
                        ...current,
                        id
                      };
                    }
                  },
                ),
                _WeekView(
                  selectedDate: selectedDate,
                  onDaySelected: (date) {
                    HapticFeedback.mediumImpact();
                    ref.read(calendarSelectedDateProvider.notifier).state =
                        date;
                    // Switch to Day View -> update provider
                    ref.read(calendarViewProvider.notifier).state = 0;
                  },
                  onWeekChanged: (date) {
                    HapticFeedback.mediumImpact();
                    ref.read(calendarSelectedDateProvider.notifier).state =
                        date;
                  },
                ),
                _MonthView(
                  selectedDate: selectedDate,
                  onDaySelected: (date) {
                    HapticFeedback.mediumImpact();
                    ref.read(calendarSelectedDateProvider.notifier).state =
                        date;
                    // Switch to Day View -> update provider
                    ref.read(calendarViewProvider.notifier).state = 0;
                  },
                ),
              ],
            ),

            // 3-Dots Menu REMOVED (Handled in MainScaffold Header)
          ],
        ),
      ),
    );
  }

  // Helper for FAB add dialog

  // Duplicate Dialog Helper
  void _showDuplicateDialog(BuildContext context) {
    final selectedDate = ref.read(calendarSelectedDateProvider);
    _showBouncyDialog(
      context: context,
      child: _DuplicateScheduleFlow(initialSourceDate: selectedDate),
    );
  }

  void _showBouncyDialog(
      {required BuildContext context, required Widget child}) {
    showMorphDialog(
      context: context,
      builder: (ctx) => child,
    );
  }

  void _handleImportWeekSchedule() {
    // Show Choice Dialog
    showMorphDialog(
      context: context,
      builder: (ctx) => GlassDialogContainer(
        title: "Import Schedule",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text("Google Calendar"),
              subtitle: const Text("Fetch from your Google account"),
              onTap: () {
                Navigator.pop(ctx);
                _importFromGoogleCalendar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text("Backup File"),
              subtitle: const Text("Import from .mbweektemplate"),
              onTap: () {
                Navigator.pop(ctx);
                _importFromBackup();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _importFromGoogleCalendar() {
    showMorphDialog(
      context: context,
      builder: (ctx) => const GoogleCalendarImportDialog(),
    );
  }

  void _importFromBackup() async {
    final notifier = ref.read(attendanceProvider.notifier);
    final templates = await notifier.pickAndParseWeekTemplate();

    if (templates != null && templates.isNotEmpty) {
      if (!mounted) return;

      final isMultiWeekImport = templates.length > 1;

      _showBouncyDialog(
        context: context,
        child: _MultiWeekSelectionDialog(
          singleSelection: isMultiWeekImport,
          explanation: isMultiWeekImport
              ? "Select the START week to apply this ${templates.length}-week schedule."
              : "Select target weeks to apply schedule.",
          confirmText: "Import",
          onWeeksSelected: (selectedWeeks) async {
            await notifier.applyTemplateToWeeks(templates, selectedWeeks);
            if (mounted) {
              MainScaffold.showGlassToast(context,
                  "Schedule imported to ${selectedWeeks.length} weeks!");
            }
          },
        ),
      );
    }
  }

  // Removed unused imports
  // final _pdfSchedulerService = PdfSchedulerService(); // Removed

  Future<void> _pickAndProcessPdf() async {
    // 1. Pick File
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      await _processFileSimple(result.files.single.path!);
    }
  }

  Future<void> _processCamera() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    if (!mounted) return;
    await _processFileSimple(photo.path);
  }

  Future<void> _processFileSimple(String filePath) async {
    String? imagePath = filePath;

    // If PDF, convert first
    if (filePath.toLowerCase().endsWith('.pdf')) {
      MainScaffold.showGlassToast(context, "Processing PDF...");
      imagePath =
          await ref.read(pdfServiceProvider).convertPdfToImage(filePath);
    }

    if (imagePath == null) {
      if (mounted) {
        MainScaffold.showGlassToast(context, "Could not process file",
            isError: true);
      }
      return;
    }

    if (!mounted) return;

    // Show Name Dialog
    final TextEditingController nameController = TextEditingController();
    showMorphDialog(
      context: context,
      builder: (ctx) => GlassDialogContainer(
        title: "Save Schedule",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                MainScaffold.showGlassToast(context, "Please enter a name",
                    isError: true);
                return;
              }
              Navigator.pop(ctx);
              ref
                  .read(savedScheduleProvider.notifier)
                  .save(imagePath!, nameController.text.trim());
              MainScaffold.showGlassToast(context, "Schedule Saved!");
            },
            child: const Text("Save"),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath!),
                  height: 200, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Schedule Name",
                hintText: "e.g., Exam Schedule",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptionsDialog(BuildContext context) {
    showMorphDialog(
      context: context,
      builder: (context) => GlassDialogContainer(
        title: "Export Week Schedule",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose how you want to share or save your schedule.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ExportOptionButton(
                  icon: Icons.share,
                  label: "Share",
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    // Ask for weeks
                    _showBouncyDialog(
                        context: context,
                        child: _MultiWeekSelectionDialog(
                            explanation:
                                "Select weeks to export. Leave empty for Base Template.",
                            confirmText: "Share",
                            onWeeksSelected: (weeks) async {
                              final notifier =
                                  ref.read(attendanceProvider.notifier);
                              final file =
                                  await notifier.generateWeekScheduleFile(
                                      selectedWeeks: weeks);
                              if (file != null) {
                                await Share.shareXFiles([XFile(file.path)],
                                    text: 'My Week Schedule');
                              }
                            }));
                  },
                ),
                _ExportOptionButton(
                  icon: Icons.save_alt,
                  label: "Save File",
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    // Ask for weeks
                    _showBouncyDialog(
                        context: context,
                        child: _MultiWeekSelectionDialog(
                            explanation:
                                "Select weeks to export. Leave empty for Base Template.",
                            confirmText: "Save",
                            onWeeksSelected: (weeks) async {
                              final notifier =
                                  ref.read(attendanceProvider.notifier);
                              final path =
                                  await notifier.saveWeekScheduleToStorage(
                                      selectedWeeks: weeks);
                              if (path != null && context.mounted) {
                                MainScaffold.showGlassToast(
                                    context, "Saved to: $path");
                                // Also show standard snackbar for longer visibility if needed,
                                // or reliance on toast is fine.
                                // Mentioning "Downloads / MadBunky / Week templates" explicitly might be helpful
                                // but the path usually includes it.
                              } else if (context.mounted) {
                                MainScaffold.showGlassToast(
                                    context, "Failed to save file.");
                              }
                            }));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateScheduleFlow extends StatefulWidget {
  final DateTime initialSourceDate;
  const _DuplicateScheduleFlow({required this.initialSourceDate});

  @override
  State<_DuplicateScheduleFlow> createState() => _DuplicateScheduleFlowState();
}

class _DuplicateScheduleFlowState extends State<_DuplicateScheduleFlow> {
  int _step = 0; // 0: Source Select, 1: Week Select, 2: Apply
  late DateTime _sourceDate;

  @override
  void initState() {
    super.initState();
    _sourceDate = widget.initialSourceDate;
  }

  void _goToWeekSelect() {
    setState(() => _step = 1);
  }

  void _goToApply(DateTime source) {
    setState(() {
      _sourceDate = source;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (focused, unfocused) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...unfocused,
              if (focused != null) focused,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _DuplicateSourceSelectionDialog(
          key: const ValueKey("source_select"),
          onCurrentWeek: () => _goToApply(widget.initialSourceDate),
          onSelectWeek: _goToWeekSelect,
        );
      case 1:
        return _WeekSelectionDialog(
          key: const ValueKey("week_select"),
          onWeekSelected: _goToApply,
        );
      case 2:
        return _DuplicateWeekDialog(
          key: const ValueKey("apply_view"),
          sourceDate: _sourceDate,
        );
      default:
        return const SizedBox();
    }
  }
}

class _DayView extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final ValueChanged<String> onToggleSelection;

  const _DayView({
    required this.selectedDate,
    required this.onDateChanged,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelection,
  });

  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey<ThunderOverlayState> _thunderKey = GlobalKey();
  String? _lastDraggedId;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  // _isDragSelecting removed as we use _dragSelectIntent and local vars
  bool _dragSelectionEnabled = false;

  final Set<String> _dragProcessedIds =
      {}; // Track IDs modified in current gesture
  bool? _dragSelectIntent; // true = selecting, false = deselecting
  Offset? _dragStartOffset; // Track touch start for slop check

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _handleDragEnd() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastDraggedId = null;
    _dragSelectionEnabled = false;
    _dragProcessedIds.clear();
    _dragSelectIntent = null;
  }

  void _handleDragSelect(Offset globalPosition) {
    if (!widget.isSelectionMode && !_dragSelectionEnabled) return;

    // AUTO-SCROLL LOGIC (Smooth Timer-based)
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topThreshold = kToolbarHeight + 110; // Header area
    final double bottomThreshold = screenHeight - 150; // Above bottom nav

    if (globalPosition.dy < topThreshold) {
      _autoScrollTimer ??=
          Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_scrollController.hasClients) {
          final newOffset = _scrollController.offset - 10;
          if (newOffset < 0) {
            _scrollController.jumpTo(0);
          } else {
            _scrollController.jumpTo(newOffset);
          }
        }
      });
    } else if (globalPosition.dy > bottomThreshold) {
      _autoScrollTimer ??=
          Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final newOffset = _scrollController.offset + 10;
          if (newOffset > maxScroll) {
            _scrollController.jumpTo(maxScroll);
          } else {
            _scrollController.jumpTo(newOffset);
          }
        }
      });
    } else {
      // Clean stop if back in safe zone
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }

    // HIT TEST
    for (final entry in _itemKeys.entries) {
      final key = entry.value;
      final id = entry.key;

      if (key.currentContext != null) {
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(globalPosition);
        if (renderBox.paintBounds.contains(localPosition)) {
          if (_lastDraggedId != id) {
            _lastDraggedId = id;

            // FIX: Only allow drag select if INTENT is set (via Long Press)
            if (_dragSelectIntent == null) {
              return;
            }

            // Only modify if we haven't touched this item in this gesture yet
            // AND the item's state doesn't match our intent
            if (!_dragProcessedIds.contains(id)) {
              final isSelected = widget.selectedIds.contains(id);
              if (isSelected != _dragSelectIntent) {
                HapticFeedback.selectionClick();
                widget.onToggleSelection(id);
              }
              _dragProcessedIds.add(id);
            }
          }
          break;
        }
      }
    }
  }

  void _startDragSelection(String id) {
    HapticFeedback.mediumImpact();
    // Entering mode via Long Press
    // This item becomes the "anchor"
    // Intent is usually to SELECT this item (if not selected)
    // If already selected, maybe deselect? Assuming Select for entry.

    final isSelected = widget.selectedIds.contains(id);
    _dragSelectIntent = !isSelected; // Toggle this item's state

    // Toggle immediately
    widget.onToggleSelection(id);

    setState(() {
      _dragSelectionEnabled = true; // Enable drag tracking
      _lastDraggedId = id;
      _dragProcessedIds.clear();
      _dragProcessedIds.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(attendanceProvider); // Fix refresh bug
    final notifier = ref.read(attendanceProvider.notifier);
    final items = notifier.getDisplayItemsForDay(widget.selectedDate);

    final displayItems = items
        .map((e) {
          if (e is ClassSession) {
            return _DisplayItem(
                id: e.id,
                subjectName: e.subjectName,
                startTime: TimeOfDay.fromDateTime(e.startTime),
                endTime: TimeOfDay.fromDateTime(e.endTime),
                colorValue: e.colorValue,
                isConcrete: true,
                status: e.status,
                template: null,
                session: e,
                hasTime: e.hasTime,
                teacherName: e.teacherName,
                topic: e.topic,
                isEvent: e.isEvent);
          } else if (e is ScheduleTemplate) {
            return _DisplayItem(
                id: e.id,
                subjectName: e.subjectName,
                startTime: e.startTime,
                endTime: e.endTime,
                colorValue: e.colorValue,
                isConcrete: false,
                status: AttendanceStatus.pending,
                template: e,
                session: null,
                hasTime: e.hasTime,
                teacherName: e.teacherName,
                topic: e.topic,
                isEvent: false);
          }
          return null;
        })
        .whereType<_DisplayItem>()
        .toList()
      ..sort((a, b) {
        // 1. Pending at Top, Completed at Bottom
        final aPending = a.status == AttendanceStatus.pending;
        final bPending = b.status == AttendanceStatus.pending;
        if (aPending && !bPending) return -1;
        if (!aPending && bPending) return 1;

        // 2. No-Time at Top (within same status group)
        if (!a.hasTime && b.hasTime) return -1;
        if (a.hasTime && !b.hasTime) return 1;

        // 3. Chronological Time
        if (!a.hasTime && !b.hasTime) return 0; // Both no-time, equal priority

        if (a.startTime.hour != b.startTime.hour) {
          return a.startTime.hour.compareTo(b.startTime.hour);
        }
        return a.startTime.minute.compareTo(b.startTime.minute);
      });

    final isEmpty = displayItems.isEmpty;
    final showCalendar = ref.watch(settingsProvider).showCalendar;
    // Adjust top padding: Standard (260) vs Compact (100)
    final topPadding = MediaQuery.of(context).padding.top +
        (showCalendar ? 240 : 100); // Optimized spacing (was 300)

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        onPointerDown: (event) {
          _dragStartOffset = event.position;
        },
        onPointerMove: (event) {
          if (widget.isSelectionMode) {
            // Check for touch slop to prevent jittery taps from being treated as drags
            if (_dragStartOffset != null &&
                (event.position - _dragStartOffset!).distance < 10.0) {
              return;
            }
            _handleDragSelect(event.position);
          }
        },
        onPointerUp: (_) {
          _handleDragEnd();
          _dragStartOffset = null;
        },
        onPointerCancel: (_) {
          _handleDragEnd();
          _dragStartOffset = null;
        },
        child: Stack(
          children: [
            // Thunder Overlay at bottom
            Positioned.fill(
                child: ThunderOverlay(
                    key: _thunderKey, child: const SizedBox.shrink())),

            // Main Content List
            Positioned.fill(
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: EdgeInsets.only(
                    top: topPadding, bottom: 200, left: 16, right: 16),
                itemCount: isEmpty ? 1 : displayItems.length,
                itemBuilder: (context, index) {
                  if (isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Opacity(
                          opacity: 0.5,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_outlined,
                                  size: 48,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              const SizedBox(height: 16),
                              Text("No classes scheduled",
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final item = displayItems[index];
                  final isSelected = widget.selectedIds.contains(item.id);

                  if (!_itemKeys.containsKey(item.id)) {
                    _itemKeys[item.id] = GlobalKey();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayViewItem(
                      key: _itemKeys[item.id],
                      item: item,
                      isSelected: isSelected,
                      isSelectionMode: widget.isSelectionMode,
                      selectedDate: widget.selectedDate,
                      onLongPress: () => _startDragSelection(item.id),
                      onTap: () {
                        if (widget.selectedIds.isNotEmpty ||
                            widget.isSelectionMode) {
                          widget.onToggleSelection(item.id);
                        }
                      },
                      onProxyTrigger: () => _thunderKey.currentState?.trigger(),
                    ),
                  );
                },
              ),
            ),

            // Top Bar with Dialer
            if (showCalendar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: MediaQuery.of(context).padding.top + 160,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).padding.top +
                              95), // Increased from 70 to 95 to separate from Top Bar
                      // Date Pickers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _VerticalDialerDatePicker(
                          selectedDate: widget.selectedDate,
                          onDateChanged: widget.onDateChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Wrap constrained box again or rely on Dialog constraints?
        // GlassDialogContainer in children provides constraints.
        // AnimatedSwitcher needs layout builder to stack properly if sizes differ?
        // AnimatedSize handles size change.
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
    // onLongPress removed
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact(); // Should be distinct?
        onTap();
      },
      // Removed onLongPress here to let it bubble up to the card
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isActive ? Colors.white : color, size: 20),
      ),
    );
  }
}

class _WeekView extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onWeekChanged;

  const _WeekView({
    required this.selectedDate,
    required this.onDaySelected,
    required this.onWeekChanged,
  });

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  // Overscroll State
  double _overscroll = 0.0;
  bool _triggered = false;
  static const double _triggerThreshold = 150.0;

  // Haptic State
  double _lastHapticOffset = 0.0;
  static const double _hapticStep = 10.0; // Tick every 10px

  // Debounce State
  bool _isNavigating = false;

  void _handleScrollNotification(ScrollNotification notification) {
    if (_isNavigating) return; // Ignore if already navigating

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.extentBefore == 0 &&
          notification.scrollDelta! < 0) {
        // Pulling Down (Previous Week)
        setState(() {
          _overscroll -= notification.scrollDelta!;
        });
      } else if (notification.metrics.extentAfter == 0 &&
          notification.scrollDelta! > 0) {
        // Pulling Up (Next Week)
        setState(() {
          _overscroll -= notification.scrollDelta!;
        });
      }

      // Haptic "Ticks" (Volume Knob Feel) - STOP if triggered
      if (!_triggered &&
          (_overscroll - _lastHapticOffset).abs() > _hapticStep) {
        double progress =
            (_overscroll.abs() / _triggerThreshold).clamp(0.0, 1.0);

        if (progress < 0.4) {
          HapticFeedback.selectionClick();
        } else if (progress < 0.7) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
        }

        _lastHapticOffset = _overscroll;
      }

      // Haptic Feedback Trigger (Threshold)
      if (!_triggered && _overscroll.abs() > _triggerThreshold) {
        HapticFeedback.heavyImpact();
        setState(() => _triggered = true);
      } else if (_triggered && _overscroll.abs() < _triggerThreshold) {
        setState(() => _triggered = false);
      }
    } else if (notification is ScrollEndNotification) {
      // Drag release handled by Listener.onPointerUp for immediate effect
      // Fallback here just in case, but rely on Listener.
      // CLEANUP: Reset overscroll if not triggered
      if (!_triggered && _overscroll != 0) {
        setState(() {
          _overscroll = 0.0;
          _lastHapticOffset = 0.0;
        });
      }
    } else if (notification is OverscrollNotification) {
      // Direct Overscroll Handling
      setState(() {
        _overscroll -= notification.overscroll;
      });

      // Haptic Ticks with increasing intensity
      if (!_triggered &&
          (_overscroll - _lastHapticOffset).abs() > _hapticStep) {
        double progress =
            (_overscroll.abs() / _triggerThreshold).clamp(0.0, 1.0);

        if (progress < 0.4) {
          HapticFeedback.selectionClick();
        } else if (progress < 0.7) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
        }

        _lastHapticOffset = _overscroll;
      }

      if (!_triggered && _overscroll.abs() > _triggerThreshold) {
        HapticFeedback.heavyImpact();
        setState(() => _triggered = true);
      }
    }
  }

  void _triggerNavigation(bool isNext) async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
      _triggered = false; // Reset trigger immediately
      _overscroll = 0.0; // Reset visual overscroll
    });

    HapticFeedback.mediumImpact();

    if (isNext) {
      widget.onWeekChanged(widget.selectedDate.add(const Duration(days: 7)));
    } else {
      widget
          .onWeekChanged(widget.selectedDate.subtract(const Duration(days: 7)));
    }

    // Debounce to prevent double triggers
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Correct Week Calculation using selectedDate
    final startOfWeek = widget.selectedDate
        .subtract(Duration(days: widget.selectedDate.weekday - 1));

    return Stack(
      children: [
        Listener(
          onPointerUp: (_) {
            if (_triggered && !_isNavigating) {
              // Trigger Navigation
              // If overscroll > 0 (Pull Down) -> Previous Week
              // If overscroll < 0 (Pull Up) -> Next Week
              // Wait, logic in original was:
              // overscroll > 0 -> subtract days (Previous)
              // overscroll < 0 -> add days (Next)
              // Let's verify standard behavior:
              // Pulling down usually reveals top item -> go to previous
              // Pulling up usually reveals bottom -> go to next

              _triggerNavigation(_overscroll < 0);
            } else {
              // Reset if released without trigger
              setState(() {
                _overscroll = 0.0;
                _triggered = false;
              });
            }
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleScrollNotification(notification);
              return false;
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // Determine direction based on week comparison?
                // We just rely on standard transition for now or custom slide
                // Since this builds ON TOP of the listview,
                // we want the new week to slide in from Top if Previous, Bottom if Next.
                // But AnimatedSwitcher doesn't know direction easily without custom key tracking.
                // Simple Fade + Scale is safer and cleaner as requested "smoother transition".
                // Vertical Slide:
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2), // Slight slide up
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: ListView.builder(
                key: ValueKey(startOfWeek), // Critical for AnimatedSwitcher
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 90,
                    bottom: 200, // Bottom padding
                    left: 16,
                    right: 16),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final notifier = ref.read(attendanceProvider.notifier);
                  final date = startOfWeek.add(Duration(days: index));

                  // Correct Data Retrieval using Provider (Syncs with Day View)
                  final rawItems = notifier.getDisplayItemsForDay(date);

                  // Filter and Map to a common interface for display
                  final dayItems = rawItems
                      .where((e) {
                        if (e is ClassSession) return !e.isCancelled;
                        return true;
                      })
                      .map((e) {
                        // Create a lightweight object for display properties
                        if (e is ClassSession) {
                          return _DisplayItem(
                            id: e.id,
                            subjectName: e.subjectName,
                            startTime: TimeOfDay.fromDateTime(e.startTime),
                            endTime: TimeOfDay.fromDateTime(e.endTime),
                            colorValue: e.colorValue,
                            isConcrete: true,
                            status: e.status,
                            template: null,
                            session: e,
                            hasTime: e.hasTime,
                            teacherName: e.teacherName,
                            topic: e.topic, // Added
                          );
                        } else if (e is ScheduleTemplate) {
                          return _DisplayItem(
                            id: e.id,
                            subjectName: e.subjectName,
                            startTime: e.startTime,
                            endTime: e.endTime,
                            colorValue: e.colorValue,
                            isConcrete: false,
                            status: AttendanceStatus.pending,
                            template: e,
                            session: null,
                            hasTime: e.hasTime,
                            teacherName: e.teacherName,
                            topic: e.topic, // Added
                          );
                        }
                        return null;
                      })
                      .whereType<_DisplayItem>()
                      .toList();

                  // Sort items by time
                  dayItems.sort((a, b) {
                    final aMin = a.startTime.hour * 60 + a.startTime.minute;
                    final bMin = b.startTime.hour * 60 + b.startTime.minute;
                    return aMin.compareTo(bMin);
                  });

                  final now = DateTime.now();
                  final isToday = date.day == now.day &&
                      date.month == now.month &&
                      date.year == now.year;
                  final isSelected = date.day == widget.selectedDate.day &&
                      date.month == widget.selectedDate.month &&
                      date.year == widget.selectedDate.year;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isToday
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isToday
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2)
                            : isSelected
                                ? BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.5),
                                    width: 1)
                                : BorderSide.none),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onDaySelected(date);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('d MMM').format(date),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                if (dayItems.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${dayItems.length} Classes",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (dayItems.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              // Improved Week View Item Display
                              ...dayItems.take(4).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Color(item.colorValue),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.hasTime
                                            ? "${item.startTime.format(context)} "
                                            : "",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.subjectName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }), // Removed extra parenthesis here
                              if (dayItems.length > 4)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "+ ${dayItems.length - 4} more",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                            ],
                            if (dayItems.isEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                "No classes",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // TOP INDICATOR (Previous Week)
        if (_overscroll > 20)
          Positioned(
            top: 100 + (_overscroll * 0.4).clamp(0, 60),
            left: 0,
            right: 0,
            child: Opacity(
              opacity: (_overscroll / _triggerThreshold).clamp(0.0, 1.0),
              child: MorphingWidget(
                duration: const Duration(milliseconds: 200),
                child: _triggered
                    ? Text(
                        "Previous Week",
                        key: const ValueKey("prev_text"),
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            shadows: [
                              Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ]),
                      )
                    : Container(
                        key: const ValueKey("prev_dot"),
                        width: 12 + (_overscroll * 0.1).clamp(0, 20),
                        height: 12 + (_overscroll * 0.1).clamp(0, 20),
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ]),
                      ),
              ),
            ),
          ),

        // BOTTOM INDICATOR (Next Week)
        if (_overscroll < -20)
          Positioned(
            // 110px Bottom Offset for symmetry
            bottom: 110 + (_overscroll.abs() * 0.4).clamp(0, 60),
            left: 0,
            right: 0,
            child: Opacity(
              opacity: (_overscroll.abs() / _triggerThreshold).clamp(0.0, 1.0),
              child: MorphingWidget(
                duration: const Duration(milliseconds: 200),
                child: _triggered
                    ? Text(
                        "Next Week",
                        key: const ValueKey("next_text"),
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            shadows: [
                              Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ]),
                      )
                    : Container(
                        key: const ValueKey("next_dot"),
                        width: 12 + (_overscroll.abs() * 0.1).clamp(0, 20),
                        height: 12 + (_overscroll.abs() * 0.1).clamp(0, 20),
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ]),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthView extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthView({required this.selectedDate, required this.onDaySelected});

  @override
  ConsumerState<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<_MonthView> {
  late DateTime _displayedMonth;
  late DateTime _selectedDayInMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _selectedDayInMonth = widget.selectedDate;
  }

  @override
  void didUpdateWidget(_MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _selectedDayInMonth = widget.selectedDate;
      _displayedMonth =
          DateTime(widget.selectedDate.year, widget.selectedDate.month);
    }
  }

  void _changeMonth(int offset) {
    HapticFeedback.lightImpact();
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final today = DateTime.now();

    // Stats Calculation
    final notifier = ref.read(attendanceProvider.notifier);
    final items = notifier.getDisplayItemsForDay(_selectedDayInMonth);

    int present = 0;
    int absent = 0;
    int pending = 0;

    for (var item in items) {
      if (item is ClassSession) {
        if (item.status == AttendanceStatus.present ||
            item.status == AttendanceStatus.proxy) {
          present++;
        } else if (item.status == AttendanceStatus.absent) {
          absent++;
        } else {
          pending++; // Ambiguous or other
        }
      } else {
        pending++; // Template = Pending
      }
    }

    final total = present + absent + pending;

    // Common Grid Widget
    Widget buildCalendarGrid() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final selectedDate = await showMorphDialog<DateTime>(
                    context: context,
                    builder: (ctx) => _MonthYearPickerDialog(
                      initialDate: _displayedMonth,
                    ),
                  );
                  if (selectedDate != null) {
                    setState(() {
                      _displayedMonth = selectedDate;
                    });
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('MMMM yyyy').format(_displayedMonth),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Day Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Text(d,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7),
            itemCount: daysInMonth + firstDayWeekday - 1,
            itemBuilder: (context, index) {
              if (index < firstDayWeekday - 1) return const SizedBox.shrink();
              final day = index - (firstDayWeekday - 1) + 1;
              final date =
                  DateTime(_displayedMonth.year, _displayedMonth.month, day);

              final isSelected = date.year == _selectedDayInMonth.year &&
                  date.month == _selectedDayInMonth.month &&
                  date.day == _selectedDayInMonth.day;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDayInMonth = date;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: MorphingWidget(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey("day_${date.day}_$isSelected"),
                    margin: const EdgeInsets.all(4),
                    decoration: isSelected
                        ? BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : isToday
                            ? BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.2),
                              ),
                    alignment: Alignment.center,
                    child: Text(
                      "$day",
                      style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Use Split View only if screen is Wide AND in Landscape orientation
      if (constraints.maxWidth > 600 &&
          constraints.maxWidth > constraints.maxHeight) {
        // --- Landscape / Large Screen: Split View ---
        return Padding(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 90,
              bottom: 200,
              left: 24,
              right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Calendar Grid (Flex 4)
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: buildCalendarGrid(),
                ),
              ),
              const SizedBox(width: 24),
              // Vertical Divider
              Container(width: 1, color: Theme.of(context).dividerColor),
              const SizedBox(width: 24),
              // Right: Summary (Flex 3)
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: _DaySummarySection(
                      date: _selectedDayInMonth,
                      total: total,
                      present: present,
                      absent: absent,
                      pending: pending,
                      onGoToDate: () =>
                          widget.onDaySelected(_selectedDayInMonth),
                      isNeon: ref.watch(settingsProvider).isNeon,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // --- Portrait / Small Screen: Stacked View ---
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 90,
                bottom: 200,
                left: 16,
                right: 16),
            child: Column(
              children: [
                buildCalendarGrid(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _DaySummarySection(
                  date: _selectedDayInMonth,
                  total: total,
                  present: present,
                  absent: absent,
                  pending: pending,
                  onGoToDate: () => widget.onDaySelected(_selectedDayInMonth),
                  isNeon: ref.watch(settingsProvider).isNeon,
                ),
              ],
            ),
          ),
        );
      }
    });
  }
}

class _DaySummarySection extends StatelessWidget {
  final DateTime date;
  final int total;
  final int present;
  final int absent;
  final int pending;
  final VoidCallback onGoToDate;
  final bool isNeon;

  const _DaySummarySection(
      {required this.date,
      required this.total,
      required this.present,
      required this.absent,
      required this.pending,
      required this.onGoToDate,
      required this.isNeon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE, MMM d').format(date),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            Text(total == 0 ? "No classes" : "$total classes",
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
          ElevatedButton(
            onPressed: onGoToDate,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text("View Day"),
          )
        ]),
        if (total > 0) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: RoundedDonutChart(
                    items: [
                      if (present > 0)
                        DonutItem(
                            value: present.toDouble(),
                            color: AppTheme.pastelGreen),
                      if (absent > 0)
                        DonutItem(
                            value: absent.toDouble(),
                            color: AppTheme.pastelRed),
                      if (pending > 0)
                        DonutItem(
                            value: pending.toDouble(),
                            color: colorScheme.surfaceContainerHighest),
                    ],
                    innerRadius: 30,
                    thickness: 25,
                    spacing: 0.2, // Visual gap between rounded segments
                    isNeon: isNeon,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      _LegendItem(
                          label: "Present",
                          count: present,
                          color: AppTheme.pastelGreen),
                      const SizedBox(height: 8),
                      _LegendItem(
                          label: "Absent",
                          count: absent,
                          color: AppTheme.pastelRed),
                      const SizedBox(height: 8),
                      _LegendItem(
                          label: "Pending",
                          count: pending,
                          color: colorScheme.surfaceContainerHighest),
                    ]))
              ],
            ),
          )
        ] else ...[
          const SizedBox(height: 40),
          Icon(Icons.event_note,
              size: 48, color: colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Text("Enjoy your free time!",
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
        ]
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _LegendItem(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text("$label: $count",
          style: const TextStyle(fontWeight: FontWeight.w500)),
    ]);
  }
}

class _DisplayItem {
  final String id;
  final String subjectName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int colorValue;
  final bool isConcrete; // True if Session, False if Template
  final AttendanceStatus status;
  final ScheduleTemplate? template;
  final ClassSession? session;

  final bool hasTime;

  _DisplayItem({
    required this.id,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.colorValue,
    required this.isConcrete,
    required this.status,
    required this.template,
    required this.session,
    this.hasTime = true,
    this.teacherName,
    this.topic,
    this.isEvent = false,
  });

  final String? teacherName;
  final String? topic;
  final bool isEvent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DisplayItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subjectName == other.subjectName &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          colorValue == other.colorValue &&
          isConcrete == other.isConcrete &&
          status == other.status &&
          hasTime == other.hasTime &&
          teacherName == other.teacherName &&
          topic == other.topic &&
          isEvent == other.isEvent;

  @override
  int get hashCode =>
      id.hashCode ^
      subjectName.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      colorValue.hashCode ^
      isConcrete.hashCode ^
      status.hashCode ^
      hasTime.hashCode ^
      teacherName.hashCode ^
      topic.hashCode ^
      isEvent.hashCode;
}

class _DuplicateWeekDialog extends ConsumerStatefulWidget {
  final DateTime sourceDate;
  const _DuplicateWeekDialog({super.key, required this.sourceDate});

  @override
  ConsumerState<_DuplicateWeekDialog> createState() =>
      _DuplicateWeekDialogState();
}

class _DuplicateWeekDialogState extends ConsumerState<_DuplicateWeekDialog> {
  DateTime _displayedMonth = DateTime.now();
  final Set<DateTime> _selectedWeekStarts = {};

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    });
  }

  void _toggleWeek(DateTime date) {
    // Find Monday of this week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final cleanMonday = DateTime(monday.year, monday.month, monday.day);

    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedWeekStarts.contains(cleanMonday)) {
        _selectedWeekStarts.remove(cleanMonday);
      } else {
        _selectedWeekStarts.add(cleanMonday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Duplicate Week",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
        ElevatedButton(
          onPressed: _selectedWeekStarts.isEmpty
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  final notifier = ref.read(attendanceProvider.notifier);
                  // Use existing logic for each selected week
                  final sourceDate = widget.sourceDate;

                  for (final startOfWeek in _selectedWeekStarts) {
                    await notifier.duplicateWeekSchedule(
                        sourceDate, startOfWeek);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    MainScaffold.showGlassToast(context,
                        "Copied to ${_selectedWeekStarts.length} weeks!");
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Apply"),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Text(
              "Select weeks to copy current schedule to:",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 2), // REDUCED Spacing
            // DAYS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => Text(d,
                      style: const TextStyle(fontWeight: FontWeight.bold)))
                  .toList(),
            ),
            const SizedBox(height: 2), // REDUCED Spacing
            // CALENDAR GRID
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

    return GridView.builder(
      itemCount: daysInMonth + firstDayWeekday - 1,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, index) {
        if (index < firstDayWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstDayWeekday - 1) + 1;
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);

        final monday = date.subtract(Duration(days: date.weekday - 1));
        final cleanMonday = DateTime(monday.year, monday.month, monday.day);
        final isSelected = _selectedWeekStarts.contains(cleanMonday);

        return GestureDetector(
          onTap: () => _toggleWeek(date),
          child: MorphingWidget(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey("dup_${date}_$isSelected"),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text("$day",
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
          ),
        );
      },
    );
  }
}

class _WeekSelectionDialog extends StatefulWidget {
  final Function(DateTime) onWeekSelected;
  const _WeekSelectionDialog({super.key, required this.onWeekSelected});

  @override
  State<_WeekSelectionDialog> createState() => _WeekSelectionDialogState();
}

class _WeekSelectionDialogState extends State<_WeekSelectionDialog> {
  DateTime _displayedMonth = DateTime.now();
  DateTime? _selectedWeekStart;

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    });
  }

  void _toggleWeek(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final cleanMonday = DateTime(monday.year, monday.month, monday.day);

    HapticFeedback.selectionClick();
    setState(() {
      _selectedWeekStart = cleanMonday;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Select Target Week",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
        ElevatedButton(
          onPressed: _selectedWeekStart == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onWeekSelected(_selectedWeekStart!);
                  // Navigator.pop(context); // REMOVED POP for Flow
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Copy"),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Text(
              "Select the week to apply this schedule:",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 2), // REDUCED Spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => Text(d,
                      style: const TextStyle(fontWeight: FontWeight.bold)))
                  .toList(),
            ),
            const SizedBox(height: 2), // REDUCED Spacing
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

    return GridView.builder(
      itemCount: daysInMonth + firstDayWeekday - 1,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, index) {
        if (index < firstDayWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstDayWeekday - 1) + 1;
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);

        final monday = date.subtract(Duration(days: date.weekday - 1));
        final cleanMonday = DateTime(monday.year, monday.month, monday.day);
        final isSelected = cleanMonday == _selectedWeekStart;

        return GestureDetector(
          onTap: () => _toggleWeek(date),
          child: MorphingWidget(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey("sel_${date}_$isSelected"),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)
                    : null,
                borderRadius: BorderRadius.circular(4),
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                "$day",
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DuplicateSourceSelectionDialog extends StatelessWidget {
  final VoidCallback onCurrentWeek;
  final VoidCallback onSelectWeek;

  const _DuplicateSourceSelectionDialog({
    super.key,
    required this.onCurrentWeek,
    required this.onSelectWeek,
  });

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Duplicate Schedule",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Which schedule do you want to copy?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          _OptionButton(
            icon: Icons.today,
            label: "Current Week",
            subtitle: "Copy this week's classes",
            color: Theme.of(context).colorScheme.primary,
            onTap: onCurrentWeek,
          ),
          const SizedBox(height: 12),
          _OptionButton(
            icon: Icons.date_range,
            label: "Choose a Week",
            subtitle: "Select a different source week",
            color: Theme.of(context).colorScheme.tertiary,
            onTap: onSelectWeek,
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _MultiWeekSelectionDialog extends StatefulWidget {
  final Function(List<DateTime>) onWeeksSelected;
  final bool singleSelection;
  final String explanation;
  final String confirmText;

  const _MultiWeekSelectionDialog({
    required this.onWeeksSelected,
    this.singleSelection = false,
    this.explanation = "Select target weeks to apply schedule",
    this.confirmText = "Apply",
  });

  @override
  State<_MultiWeekSelectionDialog> createState() =>
      _MultiWeekSelectionDialogState();
}

class _MultiWeekSelectionDialogState extends State<_MultiWeekSelectionDialog> {
  DateTime _displayedMonth = DateTime.now();
  final Set<DateTime> _selectedWeekStarts = {};

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    });
  }

  void _toggleWeek(DateTime date) {
    // Determine Monday
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final cleanMonday = DateTime(monday.year, monday.month, monday.day);

    setState(() {
      if (widget.singleSelection) {
        if (_selectedWeekStarts.contains(cleanMonday)) {
          _selectedWeekStarts.remove(cleanMonday);
        } else {
          _selectedWeekStarts.clear();
          _selectedWeekStarts.add(cleanMonday);
        }
      } else {
        if (_selectedWeekStarts.contains(cleanMonday)) {
          _selectedWeekStarts.remove(cleanMonday);
        } else {
          _selectedWeekStarts.add(cleanMonday);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Select Weeks",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedWeekStarts.isEmpty
              ? null
              : () {
                  widget.onWeeksSelected(_selectedWeekStarts.toList());
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text("${widget.confirmText} (${_selectedWeekStarts.length})"),
        ),
      ],
      child: SizedBox(
        width: 350,
        height: 400,
        child: Column(
          children: [
            Text(
              widget.explanation,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Month Navigator Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _changeMonth(-1);
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth),
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _changeMonth(1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 2), // REDUCED Spacing
            // Days header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["M", "T", "W", "T", "F", "S", "S"]
                  .map((d) => Text(d,
                      style: const TextStyle(fontWeight: FontWeight.bold)))
                  .toList(),
            ),
            const SizedBox(height: 2), // REDUCED Spacing
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

    return GridView.builder(
      itemCount: daysInMonth + firstDayWeekday - 1,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, index) {
        if (index < firstDayWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstDayWeekday - 1) + 1;
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);

        final monday = date.subtract(Duration(days: date.weekday - 1));
        final cleanMonday = DateTime(monday.year, monday.month, monday.day);
        final isSelected = _selectedWeekStarts.contains(cleanMonday);

        return GestureDetector(
          onTap: () => _toggleWeek(date),
          child: MorphingWidget(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey("multi_${date}_$isSelected"),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)
                    : null,
                borderRadius: BorderRadius.circular(4),
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              child: Center(
                child: Text(
                  "${date.day}",
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VerticalDialerDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const _VerticalDialerDatePicker({
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<_VerticalDialerDatePicker> createState() =>
      _VerticalDialerDatePickerState();
}

class _VerticalDialerDatePickerState extends State<_VerticalDialerDatePicker> {
  // Optimistic local state to prevent "stuck" UI on rapid taps
  late DateTime _localDate;
  // Tiny throttle to prevent physical double-bounce or render overload
  bool _isThrottled = false;

  @override
  void initState() {
    super.initState();
    _localDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(_VerticalDialerDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local state when parent eventually rebuilds
    if (widget.selectedDate != oldWidget.selectedDate) {
      _localDate = widget.selectedDate;
    }
  }

  void _changeDate(int days) async {
    if (_isThrottled) return;
    _isThrottled = true;

    // 1. Optimistic Update: Update local state immediately
    setState(() {
      _localDate = _localDate.add(Duration(days: days));
    });

    // 2. Notify Parent: Trigger the actual state change
    // Even if parent is slow, our local state is already correct for the next tap
    widget.onDateChanged(_localDate);

    // 3. Tiny Throttle release (50ms) - just enough to let the engine breathe
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) {
      _isThrottled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2) // Much more transparent
                : colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center, // Centered cluster
            children: [
              // Left Arrow
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _changeDate(-1);
                },
                child: Container(
                  width: 80, // Explicit width for touch target
                  height: 80, // Explicit height for touch target
                  alignment: Alignment.center, // Guarantee centering
                  color: Colors.transparent,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _changeDate(-1);
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0), // Compact visual
                        child: Icon(
                          Icons.chevron_left,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8), // Explicit breathing room

              // Date Display
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final date = await showMorphDialog<DateTime>(
                      context: context,
                      builder: (context) => GlassDialogContainer(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context)
                                .colorScheme
                                .copyWith(surface: Colors.transparent),
                          ),
                          child: CalendarDatePicker(
                            initialDate: _localDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2030),
                            onDateChanged: (val) => Navigator.pop(context, val),
                          ),
                        ),
                      ),
                    );
                    if (date != null) {
                      setState(() => _localDate = date);
                      widget.onDateChanged(date);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiquidText(
                        "${_localDate.day}",
                        style: GoogleFonts.outfit(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LiquidText(
                        DateFormat('EEEE').format(_localDate),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8), // Explicit breathing room

              // Right Arrow
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _changeDate(1);
                },
                child: Container(
                  width: 80, // Explicit width for touch target
                  height: 80, // Explicit height for touch target
                  alignment: Alignment.center, // Guarantee centering
                  color: Colors.transparent,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _changeDate(1);
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0), // Compact visual
                        child: Icon(
                          Icons.chevron_right,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Liquid/Water Reshape Animation
// Replaces the "Dust/Particle" effect.

class _DayViewItem extends ConsumerWidget {
  final _DisplayItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final DateTime selectedDate;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onProxyTrigger;

  const _DayViewItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.selectedDate,
    required this.onTap,
    this.onLongPress,
    this.onProxyTrigger,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(attendanceProvider.notifier);
    final settings = ref.watch(settingsProvider);

    // Smart Bunking Logic
    AttendanceHealth? health;
    if (settings.enableSmartBunking && !item.isEvent) {
      final subjects = ref.watch(attendanceProvider).subjects;
      final subjectId = item.session?.subjectId ?? item.template?.subjectId;

      Subject? subject;
      if (subjectId != null) {
        try {
          subject = subjects.firstWhere((s) => s.id == subjectId);
        } catch (_) {}
      } else {
        // Fallback name match
        try {
          subject = subjects.firstWhere((s) => s.name == item.subjectName);
        } catch (_) {}
      }

      if (subject != null) {
        health = calculateStatus(subject);
      }
    }

    // EVENT CARD RENDERING
    if (item.isEvent) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.5),
              width: isSelected ? 2 : 1.5,
            ),
            image: const DecorationImage(
              image: AssetImage(
                  'assets/images/confetti_bg.png'), // Placeholder for dynamic or asset
              fit: BoxFit.cover,
              opacity: 0.1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.celebration,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subjectName, // Event Name
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                    if (item.subjectName.toLowerCase().contains("exam"))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "BEST OF LUCK with ${item.subjectName} ❤️😉❤️",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    if (item.hasTime) ...[
                      const SizedBox(height: 4),
                      Text(
                        "${item.startTime.format(context)} - ${item.endTime.format(context)}",
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500),
                      ),
                    ]
                  ],
                ),
              ),
              if (item.session != null &&
                  !isSelectionMode) // Hide delete in multiselect
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context)
                          .colorScheme
                          .onTertiaryContainer
                          .withValues(alpha: 0.6)),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await notifier.deleteClassSession(
                        selectedDate, item.template, item.session!);
                    if (context.mounted) {
                      MainScaffold.showGlassToast(context, "Event Removed");
                    }
                  },
                )
            ],
          ),
        ),
      );
    }

    // Glassmorphic Card
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensure touches anywhere are caught
        onTap: () {
          // Always toggle if in selection mode or if specifically tapped
          onTap();
        },
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            // Changed to Column to hold buttons
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Time Column
                  if (item.hasTime)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.startTime.format(context),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.endTime.format(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  else
                    const Icon(Icons.schedule, color: Colors.grey),

                  const SizedBox(width: 16),

                  // Divider
                  Container(width: 1, height: 40, color: Colors.white24),
                  const SizedBox(width: 16),

                  // Subject Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subjectName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (health != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              health.statusText.contains("Can miss")
                                  ? "Can Miss"
                                  : health.statusText.contains("Must attend")
                                      ? "Must Attend"
                                      : "On Track",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: health.color,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        if (item.topic != null || item.teacherName != null)
                          Row(
                            children: [
                              if (item.topic != null) ...[
                                Icon(
                                  Icons.topic,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.topic!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (item.topic != null &&
                                  item.teacherName != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    "by",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              if (item.teacherName != null) ...[
                                if (item.topic == null)
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                if (item.topic == null)
                                  const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.teacherName!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Status Pill
                  if (item.isConcrete && !isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            _getStatusColor(item.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _getStatusColor(item.status), width: 1),
                      ),
                      child: Text(
                        item.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(item.status),
                        ),
                      ),
                    ),
                ],
              ),

              // Buttons Row
              const SizedBox(height: 12),
              if (!isSelectionMode)
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check,
                        color: AppTheme.pastelGreen,
                        isActive: item.status == AttendanceStatus.present,
                        onTap: () {
                          notifier.markAttendance(selectedDate, item.template,
                              item.session, AttendanceStatus.present);
                          MainScaffold.showGlassToast(
                              context, "Marked Present");
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SparkWidget(
                        onTap: () {
                          notifier.markAttendance(selectedDate, item.template,
                              item.session, AttendanceStatus.proxy);
                          MainScaffold.showGlassToast(
                              context, "Marked Proxy ⚡");
                        },
                        onEdgeHit: onProxyTrigger,
                        sparkColor: const Color(0xFFFFD700),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.status == AttendanceStatus.proxy
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFFFD700)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bolt,
                            color: item.status == AttendanceStatus.proxy
                                ? Colors.white
                                : const Color(0xFFFFD700),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.help_outline,
                        color: Colors.grey,
                        isActive: item.status == AttendanceStatus.ambiguous,
                        onTap: () {
                          notifier.markAttendance(selectedDate, item.template,
                              item.session, AttendanceStatus.ambiguous);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.close,
                        color: AppTheme.pastelRed,
                        isActive: item.status == AttendanceStatus.absent,
                        onTap: () {
                          notifier.markAttendance(selectedDate, item.template,
                              item.session, AttendanceStatus.absent);
                          MainScaffold.showGlassToast(context, "Marked Absent",
                              isError: true);
                        },
                      ),
                    ),
                    // Delete Button
                    if (item.session != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.5)),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            await notifier.deleteClassSession(
                                selectedDate, item.template, item.session!);
                            if (context.mounted) {
                              // Fix: Clear selection to avoid stuck ID
                              ref
                                  .read(calendarSelectionProvider.notifier)
                                  .state = {};
                              MainScaffold.showGlassToast(
                                  context, "Class Removed");
                            }
                          },
                        ),
                      )
                    ]
                  ],
                ),
              // Using default layout builder or simplified stack to ensure proper hit testing
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.proxy:
        return Colors.amber;
      case AttendanceStatus.pending:
        return Colors.orange;
      case AttendanceStatus.ambiguous:
        return Colors.grey;
    }
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _MonthYearPickerDialog({required this.initialDate});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
  }

  void _changeYear(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedYear += offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];

    return GlassDialogContainer(
      title: "Select Month",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Year Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeYear(-1),
              ),
              Text(
                "$_selectedYear",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeYear(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Months Grid
          SizedBox(
            height: 320, // Increased height to fit all 4 rows
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final isSelected = widget.initialDate.month == (index + 1) &&
                    widget.initialDate.year == _selectedYear;

                return InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                        context, DateTime(_selectedYear, index + 1, 1));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      months[index],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
