import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/optimized_glass.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_list_plus/animated_list_plus.dart';

import '../models/models.dart';

import '../utils/proxy_helper.dart';
import '../utils/mad_haptics.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/bouncing_widget.dart';
import '../widgets/horizontal_dial.dart';

import '../notifications/drag_selection_notification.dart';

import '../services/notification_service.dart';

// ... imports
import '../widgets/morphing_widget.dart';
import '../widgets/fab_actions.dart';
import 'main_scaffold.dart'; // Added for MainScaffold
import '../widgets/spark_widget.dart';
import '../utils/morph_dialog.dart';
// import '../utils/attendance_helper.dart'; // Removed

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// ... (rest of file)

// import '../services/pdf_scheduler_service.dart'; // Removed
// import '../widgets/pdf_processing_dialog.dart'; // Removed
// import '../widgets/pdf_confirmation_dialog.dart'; // Removed
// import '../widgets/scan_options_dialog.dart'; // Removed
// import '../widgets/batch_selection_dialog.dart'; // Removed
import '../widgets/subject_info_sheet.dart'; // Restored
import '../widgets/attendance_indicator.dart'; // Add this import

import '../widgets/folder_info_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  // Drag Select State
  final Map<String, GlobalKey> _itemKeys = {};
  String? _lastDraggedId;
  Timer? _autoScrollTimer;

  final Set<String> _dragProcessedIds =
      {}; // Track IDs modified in current gesture
  bool? _dragSelectIntent; // true = selecting, false = deselecting

  void _handleDragEnd(Offset? position) {
    if (_lastDraggedId == null && position != null) {
      // Handle stationary tap for selection if needed,
      // but usually tap is fast and might not trigger drag select logic if not moved enough?
      // Actually, Listener onPointerUp catches taps.
      // We should check if we are in selection mode.
      final selectedIds = ref.read(selectedSubjectsProvider);
      final selectedGroupIds = ref.read(selectedGroupsProvider);
      if (selectedIds.isNotEmpty || selectedGroupIds.isNotEmpty) {
        _handleDragSelect(position);
      }
    }
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastDraggedId = null;
    _dragSelectIntent = null;
    _dragProcessedIds.clear();
  }

  void _handleDragSelect(Offset globalPosition) {
    if (!mounted) return;

    // Only allow drag select if we are ALREADY in multi-select mode
    final currentSubjects =
        ref.read(selectedSubjectsProvider); // Read current state
    final currentGroups = ref.read(selectedGroupsProvider);

    if (currentSubjects.isEmpty && currentGroups.isEmpty) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      return;
    }

    // AUTO-SCROLL LOGIC (Smooth Timer-based)
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topThreshold = kToolbarHeight + 110; // Header area
    final double bottomThreshold = screenHeight - 150; // Above bottom nav

    if (globalPosition.dy < topThreshold) {
      _autoScrollTimer ??=
          Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo((_scrollController.offset - 10)
              .clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      });
    } else if (globalPosition.dy > bottomThreshold) {
      _autoScrollTimer ??=
          Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo((_scrollController.offset + 10)
              .clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      });
    } else {
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
            // If _dragSelectIntent is null, it means we are just scrolling/touching
            // without a preceding long press.
            if (_dragSelectIntent == null) {
              return;
            }

            // Only apply if not processed in this gesture
            if (!_dragProcessedIds.contains(id)) {
              final isGroup =
                  ref.read(attendanceProvider).groups.any((g) => g.id == id);

              // Check current state again to be sure (though intent should guide us)
              // Actually, we should just enforce the intent.
              // Matches "Paint Selection" behavior.

              if (_dragSelectIntent == true) {
                // Select
                HapticFeedback.selectionClick();
                if (isGroup) {
                  ref.read(selectedGroupsProvider.notifier).state = {
                    ...currentGroups,
                    id
                  };
                } else {
                  ref.read(selectedSubjectsProvider.notifier).state = {
                    ...currentSubjects,
                    id
                  };
                }
              } else {
                // Deselect
                HapticFeedback.selectionClick();
                if (isGroup) {
                  ref.read(selectedGroupsProvider.notifier).state = {
                    ...currentGroups
                  }..remove(id);
                } else {
                  ref.read(selectedSubjectsProvider.notifier).state = {
                    ...currentSubjects
                  }..remove(id);
                }
              }
              _dragProcessedIds.add(id);
            }
          }
          break;
        }
      }
    }
  }

  StreamSubscription? _intentDataStreamSubscription;
  // final _pdfSchedulerService = PdfSchedulerService(); // Removed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request Notification Permissions & Trigger Welcome if first time
    Future.microtask(() => NotificationService().requestPermissions());

    // Handle Shared Intent (PDFs)
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Auto-Sync Google Calendar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoSyncCalendar();
    });
  }

  Future<void> _checkAndAutoSyncCalendar() async {
    final settings = ref.read(settingsProvider);
    if (!settings.autoSyncGoogleCalendar) return;

    final service = ref.read(googleCalendarServiceProvider);

    var account = service.currentUser;
    account ??= await service.silentSignIn();

    if (account != null) {
      try {
        final now = DateTime.now();
        // Start of CURRENT week (Monday)
        final currentWeekStart =
            now.subtract(Duration(days: now.weekday - 1));
        final currentWeekStartDate = DateTime(
            currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
        // Start of NEXT week (next Monday)
        final nextWeekStart = currentWeekStartDate.add(const Duration(days: 7));

        // Fetch both current week and next week
        final currentSessions =
            await service.fetchEventsForWeek(currentWeekStartDate);
        final nextSessions =
            await service.fetchEventsForWeek(nextWeekStart);

        final allSessions = [...currentSessions, ...nextSessions];

        if (allSessions.isNotEmpty) {
          final notifier = ref.read(attendanceProvider.notifier);
          int addedCount = 0;
          for (var session in allSessions) {
            notifier.addClassSession(session);
            addedCount++;
          }
          if (mounted && addedCount > 0) {
            MainScaffold.showGlassToast(context,
                "Auto-synced $addedCount classes from Google Calendar");
          }
        }
      } catch (e) {
        debugPrint("Auto-sync failed: $e");
      }
    }
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    final sharedFile = files.firstWhere((file) {
      final lp = file.path.toLowerCase();
      return lp.endsWith('.pdf') ||
          lp.endsWith('.jpg') ||
          lp.endsWith('.jpeg') ||
          lp.endsWith('.png') ||
          lp.endsWith('.webp');
    }, orElse: () => SharedMediaFile(path: '', type: SharedMediaType.file));

    if (sharedFile.path.isNotEmpty) {
      String? imagePath = sharedFile.path;

      // If PDF, convert first
      if (sharedFile.path.toLowerCase().endsWith('.pdf')) {
        MainScaffold.showGlassToast(context, "Processing PDF...");
        imagePath = await ref
            .read(pdfServiceProvider)
            .convertPdfToImage(sharedFile.path);
      }

      if (imagePath == null) {
        if (mounted) {
          MainScaffold.showGlassToast(context, "Could not process file",
              isError: true);
        }
        return;
      }

      if (!mounted) return;

      // Show Confirmation Dialog
      showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
          title: "Set as Schedule Reference?",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(savedScheduleProvider.notifier)
                    .save(imagePath!, "Scanned Schedule");
                MainScaffold.showGlassToast(context, "Schedule Saved!");
              },
              child: const Text("Save"),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath!),
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 300,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                  "Do you want to use this image as your schedule reference?"),
            ],
          ),
        ),
      );
    }
  }

  // Removed _showConfirmation, _addClasses as they were part of parsing flow

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    _intentDataStreamSubscription?.cancel();
    // _pdfSchedulerService.dispose(); // Removed

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data to reflect any background changes (e.g. from notifications)
      ref.read(attendanceProvider.notifier).loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final selectedIds = ref.watch(selectedSubjectsProvider);
    final selectedGroupIds = ref.watch(selectedGroupsProvider);
    final isMultiSelect = selectedIds.isNotEmpty || selectedGroupIds.isNotEmpty;

    // Filter Logic
    final query = ref.watch(searchQueryProvider).toLowerCase();

    // Filter Groups
    final filteredGroups = attendanceState.groups.where((g) {
      if (query.isEmpty) return true;
      // Match group name OR any subject inside it
      final groupNameMatch = g.name.toLowerCase().contains(query);
      if (groupNameMatch) return true;

      final subjectsInGroup =
          attendanceState.subjects.where((s) => g.subjectIds.contains(s.id));
      return subjectsInGroup.any((s) => s.name.toLowerCase().contains(query));
    }).toList();

    // Filter Ungrouped Subjects
    final groupedSubjectIds =
        attendanceState.groups.expand((g) => g.subjectIds).toSet();

    final filteredUngrouped = attendanceState.subjects
        .where((s) => !groupedSubjectIds.contains(s.id))
        .where((s) {
      if (query.isEmpty) return true;
      return s.name.toLowerCase().contains(query);
    }).toList();

    return PopScope(
      canPop: !isMultiSelect,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isMultiSelect) {
          ref.read(selectedSubjectsProvider.notifier).state = {};
          ref.read(selectedGroupsProvider.notifier).state = {};
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Content
            NotificationListener<DragSelectionStartNotification>(
              onNotification: (notification) {
                // Centralized Selection Handler
                final currentSubjects = ref.read(selectedSubjectsProvider);
                final currentGroups = ref.read(selectedGroupsProvider);
                final isSelected = currentSubjects.contains(notification.id) ||
                    currentGroups.contains(notification.id);
                final isGroup = ref
                    .read(attendanceProvider)
                    .groups
                    .any((g) => g.id == notification.id);

                if (isMultiSelect) {
                  // Toggle Logic
                  HapticFeedback.selectionClick();
                  if (isSelected) {
                    // Deselect
                    if (isGroup) {
                      ref.read(selectedGroupsProvider.notifier).state = {
                        ...currentGroups
                      }..remove(notification.id);
                    } else {
                      ref.read(selectedSubjectsProvider.notifier).state = {
                        ...currentSubjects
                      }..remove(notification.id);
                    }
                    _dragSelectIntent = false; // Intention for drag is DESELECT
                  } else {
                    // Select
                    if (isGroup) {
                      ref.read(selectedGroupsProvider.notifier).state = {
                        ...currentGroups,
                        notification.id
                      };
                    } else {
                      ref.read(selectedSubjectsProvider.notifier).state = {
                        ...currentSubjects,
                        notification.id
                      };
                    }
                    _dragSelectIntent = true; // Intention for drag is SELECT
                  }
                } else {
                  // Initial Selection Logic (Enter Mode)
                  HapticFeedback.mediumImpact();
                  if (isGroup) {
                    ref.read(selectedGroupsProvider.notifier).state = {
                      notification.id
                    };
                  } else {
                    ref.read(selectedSubjectsProvider.notifier).state = {
                      notification.id
                    };
                  }
                  _dragSelectIntent = true; // Start as SELECT
                }

                _dragProcessedIds.clear();
                _dragProcessedIds.add(notification.id); // Mark as processed
                _lastDraggedId = notification.id;
                return true;
              },
              child: Listener(
                onPointerMove: (event) => _handleDragSelect(event.position),
                onPointerUp: (event) => _handleDragEnd(event.position),
                onPointerCancel: (_) => _handleDragEnd(null),
                child: LayoutBuilder(builder: (context, constraints) {
                  final allItems = [...filteredGroups, ...filteredUngrouped];

                  if (allItems.isEmpty) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 100,
                          bottom: 200 + bottomPadding,
                          left: 16,
                          right: 16),
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  "No subjects found",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                if (query.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      "Try a different search term",
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (constraints.maxWidth > 600) {
                    // Fix: Increase threshold for 3 columns to prevent narrow cards on landscape phones
                    final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;
                    // Dynamic aspect ratio: Target height ~220-250px
                    // Grid Layout for Variable Heights (Folders)
                    // Distribute items into rows
                    List<Widget> gridRows = [];
                    for (int i = 0; i < allItems.length; i += crossAxisCount) {
                      List<Widget> rowChildren = [];
                      for (int j = 0; j < crossAxisCount; j++) {
                        int index = i + j;
                        if (index < allItems.length) {
                          final item = allItems[index];
                          Widget child;
                          if (item is Group) {
                            child = _GroupCard(
                              key: _itemKeys.putIfAbsent(item.id, () => GlobalKey()),
                              group: item,
                              isMultiSelect: isMultiSelect,
                              searchQuery: query,
                              itemKeys: _itemKeys,
                            );
                          } else {
                            final subjectItem = item as Subject;
                            child = SubjectCard(
                              key: _itemKeys.putIfAbsent(subjectItem.id, () => GlobalKey()),
                              subject: subjectItem,
                              isMultiSelect: isMultiSelect,
                            );
                          }

                          final id = item is Group ? item.id : (item as Subject).id;
                          // Wrap in Reorder Switcher
                          final switcher = _ReorderAnimatedSwitcher(
                            event: ref.watch(lastReorderEventProvider),
                            child: KeyedSubtree(
                              key: ValueKey(id),
                              child: child,
                            ),
                          );

                          // Apply Animation
                          final animatedChild = AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: switcher,
                                ),
                              ),
                            ),
                          );

                          rowChildren.add(Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: j == 0 ? 0 : 8,
                                right: j == crossAxisCount - 1 ? 0 : 8,
                              ),
                              child: animatedChild,
                            ),
                          ));
                        } else {
                          rowChildren.add(Expanded(child: const SizedBox.shrink()));
                        }
                      }
                      gridRows.add(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rowChildren,
                      ));
                    }

                    return AnimationLimiter(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 100,
                            bottom: 200 + bottomPadding,
                            left: 16,
                            right: 16),
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        child: Column(
                          children: gridRows,
                        ),
                      ),
                    );
                  } else {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top +
                              100, // Header
                          bottom: 200 + bottomPadding,
                          left: 16,
                          right: 16),
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      child: Column(
                        children: [
                          ImplicitlyAnimatedList<Object>(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            insertDuration: const Duration(milliseconds: 600),
                            removeDuration: const Duration(milliseconds: 600),
                            items: allItems,
                            areItemsTheSame: (a, b) {
                              return (a as dynamic).id == (b as dynamic).id;
                            },
                            itemBuilder: (context, animation, item, index) {
                              final child = item is Group
                                  ? _GroupCard(
                                      key: _itemKeys.putIfAbsent(
                                          item.id, () => GlobalKey()),
                                      group: item,
                                      isMultiSelect: isMultiSelect,
                                      searchQuery: query,
                                      itemKeys: _itemKeys,
                                    )
                                  : SubjectCard(
                                      key: _itemKeys.putIfAbsent(
                                          (item as Subject).id,
                                          () => GlobalKey()),
                                      subject: item,
                                      isMultiSelect: isMultiSelect,
                                    );

                              final id = item is Group
                                  ? item.id
                                  : (item as Subject).id;
                              return MorphItemTransition(
                                animation: animation,
                                child: _ReorderAnimatedSwitcher(
                                  event: ref.watch(lastReorderEventProvider),
                                  child: KeyedSubtree(
                                    key: ValueKey(id),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            removeItemBuilder: (context, animation, item) {
                              return MorphItemTransition(
                                animation: animation,
                                child: item is Group
                                    ? _GroupCard(
                                        group: item,
                                        isMultiSelect: isMultiSelect,
                                        itemKeys: _itemKeys,
                                      )
                                    : SubjectCard(
                                        subject: item as Subject,
                                        isMultiSelect: isMultiSelect),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }
                }),
              ),
            ),

            // Removed Custom Frosted Top Bar with Integrated Search as per instruction
          ],
        ),
      ),
    );
  }
}

void _showGroupInsightsDialog(
    BuildContext context,
    Group group,
    List<Subject> subjects,
    int totalPresent,
    int totalAbsent,
    int totalClasses) {
  showMorphDialog(
    context: context,
    builder: (context) => FolderInfoSheet(
      group: group,
      subjects: subjects,
    ),
  );
}

class _GroupCard extends ConsumerWidget {
  final Group group;
  final bool isMultiSelect;
  final String searchQuery; // Add parameter
  final Map<String, GlobalKey> itemKeys;

  const _GroupCard(
      {required this.group,
      this.isMultiSelect = false,
      this.searchQuery = '', // Default empty
      required this.itemKeys,
      super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceState = ref.watch(attendanceProvider);
    final allGroupSubjects = attendanceState.subjects
        .where((s) => group.subjectIds.contains(s.id))
        .toList();

    // Filter displayed subjects based on search query
    final subjects = allGroupSubjects.where((s) {
      if (searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    // Determine Expansion: Explicitly expanded OR matches search query
    final isExpanded =
        group.isExpanded || (searchQuery.isNotEmpty && subjects.isNotEmpty);

    // Calculate aggregate stats
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalAmbiguous = 0;
    int totalProxy = 0;
    for (final s in subjects) {
      totalPresent += s.present;
      totalAbsent += s.absent;
      totalAmbiguous += s.ambiguous;
      totalProxy += s.proxy;
    }
    final totalClasses =
        totalPresent + totalAbsent + totalAmbiguous + totalProxy;
    final double overallPercentage = totalClasses == 0
        ? 0.0
        : ((totalPresent + totalProxy) / totalClasses) * 100;

    final isSelected = ref.watch(selectedGroupsProvider).contains(group.id);

    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : (group.colorValue != null
            ? Color(group.colorValue!)
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.05));

    final effectiveBorderColor =
        group.colorValue != null ? Color(group.colorValue!) : borderColor;

    // Unified Container for the entire folder (Header + Body)
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.transparent, // Background handled by children
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isExpanded
                ? effectiveBorderColor.withValues(
                    alpha: group.colorValue != null ? 1.0 : 1.0)
                : (isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (group.colorValue != null
                        ? Color(group.colorValue!)
                        : Colors
                            .transparent)), // Animate from transparent/colored
            width: isExpanded || isSelected || group.colorValue != null ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected && !isExpanded)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24), // Clip content to outline
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (Replaces Card)
              Material(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                child: InkWell(
                  onTap: () {
                    if (isMultiSelect) {
                      final isSelected =
                          ref.read(selectedGroupsProvider).contains(group.id);
                      if (isSelected) {
                        ref.read(selectedGroupsProvider.notifier).state = {
                          ...ref.read(selectedGroupsProvider)
                        }..remove(group.id);
                      } else {
                        ref.read(selectedGroupsProvider.notifier).state = {
                          ...ref.read(selectedGroupsProvider),
                          group.id
                        };
                      }
                    } else {
                      ref
                          .read(attendanceProvider.notifier)
                          .toggleGroupExpansion(group.id);
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    final current = ref.read(selectedGroupsProvider);
                    if (current.isEmpty) {
                      ref.read(selectedGroupsProvider.notifier).state = {
                        group.id
                      };
                    }
                    DragSelectionStartNotification(group.id).dispatch(context);
                  },
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 16, right: 8),
                        title: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  BouncingWidget(
                                    scaleFactor: 0.9,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                      ),
                                      child: Text(
                                        group.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: isMultiSelect
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.bar_chart, size: 20),
                                    tooltip: "Insights",
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _showGroupInsightsDialog(
                                          context,
                                          group,
                                          subjects,
                                          totalPresent,
                                          totalAbsent,
                                          totalClasses);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    tooltip: "Edit Folder",
                                    onPressed: () => _showEditGroupDialog(
                                        context, ref, group),
                                  ),
                                  IconButton(
                                    icon: AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: const Icon(Icons.expand_more),
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(attendanceProvider.notifier)
                                          .toggleGroupExpansion(group.id);
                                    },
                                  ),
                                ],
                              ),
                      ),
                      // Summary Statistics Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${overallPercentage.toStringAsFixed(1)}%",
                                    style: TextStyle(
                                        color: overallPercentage >= 75
                                            ? AppTheme.pastelGreen
                                            : AppTheme.pastelRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                Container(
                                    width: 1,
                                    height: 12,
                                    color: Colors.grey[800]),
                                const SizedBox(width: 12),
                                Icon(Icons.format_list_bulleted,
                                    size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text("$totalClasses",
                                    style: TextStyle(
                                        color: Colors.grey[300], fontSize: 13)),
                                const SizedBox(width: 12),
                                const Icon(Icons.check,
                                    size: 14, color: AppTheme.pastelGreen),
                                const SizedBox(width: 4),
                                Text("$totalPresent",
                                    style: const TextStyle(
                                        color: AppTheme.pastelGreen,
                                        fontSize: 13)),
                                const SizedBox(width: 12),
                                const Icon(Icons.bolt,
                                    size: 14, color: Color(0xFFFFD700)),
                                const SizedBox(width: 4),
                                Text(
                                    ((totalPresent +
                                                totalAbsent +
                                                totalAmbiguous) -
                                            (totalPresent +
                                                totalAbsent +
                                                totalAmbiguous -
                                                (attendanceState.subjects
                                                    .where((s) => group
                                                        .subjectIds
                                                        .contains(s.id))
                                                    .fold(
                                                        0,
                                                        (p, c) =>
                                                            p + c.proxy))))
                                        .toString(),
                                    style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 13)),
                                const SizedBox(width: 12),
                                const Icon(Icons.help_outline,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text("$totalAmbiguous",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                                const SizedBox(width: 12),
                                const Icon(Icons.close,
                                    size: 14, color: AppTheme.pastelRed),
                                const SizedBox(width: 4),
                                Text("$totalAbsent",
                                    style: const TextStyle(
                                        color: AppTheme.pastelRed,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Content (Body)
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Container(
                        width: double.infinity, // Force full width
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainer
                              .withValues(alpha: 0.3),
                          // No border/radius here, handled by Wrapper clip
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 375),
                            childAnimationBuilder: (widget) => ScaleAnimation(
                              scale: 0.5,
                              child: FadeInAnimation(
                                child: widget,
                              ),
                            ),
                            children: subjects.map((s) {
                              final child = SubjectCard(
                                  key: itemKeys.putIfAbsent(
                                      s.id, () => GlobalKey()),
                                  subject: s,
                                  isMultiSelect: isMultiSelect);
                              return _ReorderAnimatedSwitcher(
                                event: ref.watch(lastReorderEventProvider),
                                child: KeyedSubtree(
                                  key: ValueKey(s.id),
                                  child: child,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Top Level Helpers ---

void _showEditSubjectDialog(
    BuildContext context, WidgetRef ref, Subject subject) {
  final nameController = TextEditingController(text: subject.name);
  final targetController =
      TextEditingController(text: subject.targetPercentage.toString());
  final attendedController =
      TextEditingController(text: subject.present.toString());
  final missedController =
      TextEditingController(text: subject.absent.toString());
  final proxyController = TextEditingController(text: subject.proxy.toString());
  final notSureController =
      TextEditingController(text: subject.ambiguous.toString());
  // Teacher/Topic fields hidden as per user request to simplify UI
  int? selectedColor = subject.colorValue;
  bool showOutline = subject.showOutline; // Local state

  showMorphDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return GlassDialogContainer(
        title: "Edit Subject",
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
                final newSubject = subject.copyWith(
                  name: nameController.text,
                  targetPercentage:
                      (int.tryParse(targetController.text) ?? 75).abs(),
                  present: (int.tryParse(attendedController.text) ?? 0).abs(),
                  absent: (int.tryParse(missedController.text) ?? 0).abs(),
                  proxy: (int.tryParse(proxyController.text) ?? 0).abs(),
                  ambiguous: (int.tryParse(notSureController.text) ?? 0).abs(),
                  colorValue: selectedColor,
                  showOutline: showOutline, // Save local state
                  // teacherName/topic hidden
                );
                ref.read(attendanceProvider.notifier).updateSubject(
                    newSubject.copyWith(clearColor: selectedColor == null),
                    registerUndo: true);
                Navigator.pop(ctx);
              }
            },
            child: Text('Save',
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
            // Teacher/Topic fields hidden
            buildDarkTextField(context, targetController, 'Target %',
                isNumber: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildDarkTextField(
                      context, attendedController, 'Present',
                      isNumber: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildDarkTextField(context, missedController, 'Absent',
                      isNumber: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildDarkTextField(context, proxyController, 'Proxy ⚡',
                      isNumber: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildDarkTextField(
                      context, notSureController, 'Not Sure ?',
                      isNumber: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ColorSelector(
              selectedColor: selectedColor,
              onColorChanged: (c) => setState(() => selectedColor = c),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Show Color Outline",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              value: showOutline,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                setState(() {
                  showOutline = val;
                });
              },
            ),
          ],
        ),
      );
    }),
  );
}

void _showConvertNotSureDialog(
    BuildContext context, WidgetRef ref, Subject subject) {
  int selectedCount = 1;
  int maxCount = subject.ambiguous;
  final proxySparkKey = GlobalKey<SparkWidgetState>();

  showMorphDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return GlassDialogContainer(
        title: 'Resolve "Not Sure"',
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(attendanceProvider.notifier)
                      .removeAmbiguous(subject.id, selectedCount);
                  Navigator.pop(ctx);
                },
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error, size: 20),
                label: Text("Delete",
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey)),
              )
            ],
          )
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Convert to specific status",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Horizontal Dial
            HorizontalDial(
              min: 1,
              max: maxCount,
              initialValue: selectedCount,
              onChanged: (val) {
                setState(() => selectedCount = val);
              },
              itemWidth: 20.0,
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Present
                _buildConvertButton(context,
                    icon: Icons.check,
                    color: AppTheme.pastelGreen,
                    label: "Present", onTap: () {
                  ref.read(attendanceProvider.notifier).convertAmbiguous(
                      subject.id, selectedCount, AttendanceStatus.present);
                  Navigator.pop(ctx);
                }),
                // Proxy
                SparkWidget(
                  key: proxySparkKey,
                  sparkColor: const Color(0xFFFFD700),
                  onEdgeHit: () {
                    triggerProxyEffect(context, ref);
                  },
                  child: _buildConvertButton(
                    context,
                    icon: Icons.bolt,
                    color: const Color(0xFFFFD700),
                    label: "Proxy",
                    onInteractionStart: () {
                      proxySparkKey.currentState?.fire();
                    },
                    onTap: () {
                      ref.read(attendanceProvider.notifier).convertAmbiguous(
                          subject.id, selectedCount, AttendanceStatus.proxy);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                // Absent
                _buildConvertButton(context,
                    icon: Icons.close,
                    color: AppTheme.pastelRed,
                    label: "Absent", onTap: () {
                  ref.read(attendanceProvider.notifier).convertAmbiguous(
                      subject.id, selectedCount, AttendanceStatus.absent);
                  Navigator.pop(ctx);
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }),
  );
}

Widget _buildConvertButton(BuildContext context,
    {required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onInteractionStart,
    bool isGlowing = false}) {
  return _ConvertButton(
    icon: icon,
    color: color,
    label: label,
    onTap: onTap,
    onInteractionStart: onInteractionStart,
    isGlowing: isGlowing,
  );
}

class _ConvertButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onInteractionStart;
  final bool isGlowing;

  const _ConvertButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.onInteractionStart,
    this.isGlowing = false,
  });

  @override
  State<_ConvertButton> createState() => _ConvertButtonState();
}

class _ConvertButtonState extends State<_ConvertButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _glowAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isGlowing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    widget.onInteractionStart?.call();
    HapticFeedback.heavyImpact();
    // Burst animation
    await _controller.forward(from: 0.0);
    // Reverse to fade out slightly if needed, or just proceed
    // await _controller.reverse();
    // widget.onTap(); // Handled by parent SparkWidget if wrapped or let it be
    // Actually for convert button, we can wrap the usage in _showConvertNotSureDialog with SparkWidget
    widget.onTap();
  }

  @override
  void didUpdateWidget(covariant _ConvertButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BouncingWidget(
      onTap: _handleTap,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color, width: 2),
                  boxShadow: widget.isGlowing
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.6),
                            blurRadius: 15,
                            spreadRadius: _glowAnimation.value,
                          )
                        ]
                      : [],
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(widget.label,
              style: TextStyle(
                  color: widget.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

void _showMoveRequest(BuildContext context, WidgetRef ref, Subject subject) {
  showGlassMoveToFolderDialog(
    context: context,
    ref: ref,
    subjectIds: {subject.id},
  );
}

void _showEditGroupDialog(BuildContext context, WidgetRef ref, Group group) {
  final nameController = TextEditingController(text: group.name);
  int? selectedColor = group.colorValue;

  showMorphDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      return GlassDialogContainer(
        title: "Edit Folder",
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
                ref.read(attendanceProvider.notifier).updateGroup(
                      group.copyWith(
                        name: nameController.text,
                        colorValue: selectedColor,
                        clearColor: selectedColor == null,
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: Text('Save',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildDarkTextField(context, nameController, 'Folder Name'),
            const SizedBox(height: 20),
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

void _showSubjectInfo(BuildContext context, Subject subject) {
  showMorphDialog(
    context: context,
    builder: (context) {
      return SubjectInfoSheet(subjectId: subject.id);
    },
  );
}


class _GlassOptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassOptionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSubjectOptions(BuildContext context, WidgetRef ref, Subject subject,
    BuildContext buttonContext) {
  final renderBox = buttonContext.findRenderObject() as RenderBox;
  final offset = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  // Calculate position: Below the button, aligned right
  // We want the menu's top right to be near the button's bottom right.
  final top = offset.dy + size.height - 12;

  // Right alignment logic:
  // Positioned(right: ...) expects distance from screen right edge.
  final screenWidth = MediaQuery.of(context).size.width;
  final right = screenWidth - (offset.dx + size.width);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Dismiss",
    barrierColor: Colors.transparent, // Transparent for popup feel
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          // 1. Global Dismiss Layer (Catches taps on transparent zones)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Menu
          Positioned(
            top: top,
            right: right,
            child: Container(
              width: 220,
              // Shadow Container
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: OptimizedGlass(
                borderRadius: BorderRadius.circular(24),
                sigmaX: 20,
                sigmaY: 20,
                fallbackColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassOptionItem(
                          icon: Icons.history,
                          label: "Info",
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            Navigator.pop(context);
                            _showSubjectInfo(context, subject);
                          },
                        ),
                        _GlassOptionItem(
                          icon: Icons.edit,
                          label: "Edit",
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            Navigator.pop(context);
                            _showEditSubjectDialog(context, ref, subject);
                          },
                        ),
                        _GlassOptionItem(
                          icon: Icons.drive_file_move,
                          label: "Move to Folder",
                          color: Theme.of(context).colorScheme.onSurface,
                          onTap: () {
                            Navigator.pop(context);
                            _showMoveRequest(context, ref, subject);
                          },
                        ),
                        Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                          height: 16,
                        ),
                        _GlassOptionItem(
                          icon: Icons.delete,
                          label: "Delete",
                          color: AppTheme.pastelRed,
                          onTap: () {
                            Navigator.pop(context);
                            ref
                                .read(attendanceProvider.notifier)
                                .deleteSubject(subject.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

class SubjectCard extends ConsumerStatefulWidget {
  final Subject subject;
  final bool isMultiSelect;
  const SubjectCard(
      {required this.subject, this.isMultiSelect = false, super.key});

  @override
  ConsumerState<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<SubjectCard> {
  final GlobalKey<SparkWidgetState> _proxySparkKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    void updateSafe(AttendanceStatus status) {
      ref
          .read(attendanceProvider.notifier)
          .logManualAttendance(widget.subject.id, status);
    }

    void handleLongPress() {
      DragSelectionStartNotification(widget.subject.id).dispatch(context);
    }

    // Use calculateStatus from models.dart
    final status = calculateStatus(widget.subject);
    final theme = Theme.of(context);
    // Optimized: Only watch for this specific subject's selection state
    final isSelected = ref.watch(
        selectedSubjectsProvider.select((s) => s.contains(widget.subject.id)));

    final selectedCardColor = widget.subject.colorValue != null
        ? Color(widget.subject.colorValue!)
        : null;

    final cardColor = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerLow;

    final borderColor = isSelected
        ? theme.colorScheme.primary
        : (widget.subject.showOutline && selectedCardColor != null
            ? selectedCardColor
            : theme.colorScheme.outline.withValues(alpha: 0.05));

    return BouncingWidget(
      onLongPress: handleLongPress,
      onTap: () {
        if (widget.isMultiSelect) {
          final isSelected =
              ref.read(selectedSubjectsProvider).contains(widget.subject.id);
          if (isSelected) {
            ref.read(selectedSubjectsProvider.notifier).state = {
              ...ref.read(selectedSubjectsProvider)
            }..remove(widget.subject.id);
          } else {
            ref.read(selectedSubjectsProvider.notifier).state = {
              ...ref.read(selectedSubjectsProvider),
              widget.subject.id
            };
          }
        }
      },
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: borderColor,
                width: isSelected ||
                        (selectedCardColor != null &&
                            widget.subject.showOutline)
                    ? 2
                    : 1),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Name & Menu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subject.name,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Teacher/Topic display hidden as per request
                          ],
                        ),
                      ),
                      // Action Buttons (Undo/Redo) & Menu
                      if (!widget.isMultiSelect)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Undo Button
                            BouncingWidget(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(attendanceProvider.notifier)
                                    .undoSubjectChange(widget.subject.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.undo_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Redo Button
                            BouncingWidget(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(attendanceProvider.notifier)
                                    .redoSubjectChange(widget.subject.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.redo_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Menu Button
                            Builder(
                              builder: (iconContext) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    _showSubjectOptions(context, ref,
                                        widget.subject, iconContext);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.more_horiz,
                                        size: 20,
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stats Row
                  Row(
                    children: [
                      CircularAttendanceIndicator(
                        percentage: widget.subject.currentPercentage.toDouble(),
                        target: widget.subject.targetPercentage.toDouble(),
                        color: status.color,
                        size: 64,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SubjectStatPill(
                                    label: "Attended",
                                    value: widget.subject.proxy > 0
                                        ? "${widget.subject.present} + ${widget.subject.proxy} ⚡"
                                        : "${widget.subject.present}",
                                    color: AppTheme.pastelGreen),
                                _SubjectStatPill(
                                    label: "Missed",
                                    value: "${widget.subject.absent}",
                                    color: AppTheme.pastelRed),
                                _SubjectStatPill(
                                    label: "Total",
                                    value: "${widget.subject.total}",
                                    color: theme.colorScheme.primary),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (ref.watch(settingsProvider).enableSmartBunking)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: status.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.statusText,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: status.color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                                "Target: ${widget.subject.targetPercentage}%",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Ambiguous Warning
                  if (widget.subject.ambiguous > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: () => _showConvertNotSureDialog(
                            context, ref, widget.subject),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD700).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Color(0xFFD4A017)),
                              const SizedBox(width: 8),
                              Text(
                                  "Resolve ${widget.subject.ambiguous} unmarked classes",
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: const Color(0xFFD4A017),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Actions
                  AbsorbPointer(
                    absorbing: widget.isMultiSelect,
                    child: Row(
                      children: [
                        // Present (Big)
                        Expanded(
                          flex: 2,
                          child: _SubjectActionButton(
                            icon: Icons.check_rounded,
                            label: "Present",
                            color: AppTheme.pastelGreen,
                            onPressed: () {
                              MadHaptics.tick();
                              updateSafe(AttendanceStatus.present);
                            },
                            onLongPress: handleLongPress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Proxy (Small)
                        SparkWidget(
                          key: _proxySparkKey,
                          sparkColor: const Color(0xFFFFD700),
                          child: SizedBox(
                            width: 50,
                            child: _SubjectActionButton(
                              icon: Icons.bolt,
                              label: "", // Icon only
                              color: const Color(0xFFFFD700),
                              onPressed: () {
                                _proxySparkKey.currentState?.fire();
                                updateSafe(AttendanceStatus.proxy);
                              },
                              onLongPress: handleLongPress,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Not Sure (Small)
                        SizedBox(
                          width: 50,
                          child: _SubjectActionButton(
                            icon: Icons.help_outline_rounded,
                            label: "",
                            color: Colors.grey,
                            onPressed: () {
                              MadHaptics.tick();
                              updateSafe(AttendanceStatus.ambiguous);
                            },
                            onLongPress: handleLongPress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Absent (Big)
                        Expanded(
                          flex: 2,
                          child: _SubjectActionButton(
                            icon: Icons.close_rounded,
                            label: "Absent",
                            color: AppTheme.pastelRed,
                            onPressed: () {
                              MadHaptics.tick();
                              updateSafe(AttendanceStatus.absent);
                            },
                            onLongPress: handleLongPress,
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
}

class _SubjectStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SubjectStatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ],
    );
  }
}

class _SubjectActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const _SubjectActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onPressed,
      required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              // const SizedBox(width: 8), // Minimalist
              // Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Animation Components ---

class _ReorderAnimatedSwitcher extends StatelessWidget {
  final Widget child;
  final ReorderEvent? event;

  const _ReorderAnimatedSwitcher({required this.child, required this.event});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final key =
            child.key is ValueKey ? (child.key as ValueKey).value : null;
        final isMoving = event != null && key != null && event!.id == key;

        // 1. Moving Item Animation (Slide)
        if (isMoving) {
          final isEnter = child.key == this.child.key;

          // Calculate Offset
          // Move UP: Enter from Bottom (0, 1), Exit to Top (0, -1)
          // Move DOWN: Enter from Top (0, -1), Exit to Bottom (0, 1)
          Offset begin;
          if (event!.direction == ReorderDirection.up) {
            begin = isEnter ? const Offset(0, 1) : const Offset(0, -1);
          } else {
            begin = isEnter ? const Offset(0, -1) : const Offset(0, 1);
          }

          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child:
                child, // Removed FadeTransition for moving item to prevent disappearing
          );
        }

        // 2. Displaced Item Animation (Fade + Scale Subtle)
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: child, // Keyed by item ID by parent
    );
  }
}
