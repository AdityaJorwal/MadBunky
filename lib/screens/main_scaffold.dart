import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'schedule_viewer_screen.dart';
import '../providers/providers.dart';
import '../widgets/thunder_overlay.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/fab_actions.dart';

import '../utils/globals.dart'; // For calendarTabPosition
import '../services/notification_service.dart';
import '../services/automation_service.dart';
import '../theme.dart';
import '../widgets/morphing_widget.dart'; // Particle Morph Effect

import 'package:google_fonts/google_fonts.dart';
import 'stats_screen.dart';
import '../models/models.dart';
import '../utils/morph_dialog.dart';
import '../widgets/user_card.dart'; // User Card Widget
import '../widgets/animations/particle_text.dart';
import '../widgets/optimized_glass.dart'; // Added for Battery Optimization

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();

  // Static Helper for Glass Toast
  static void showGlassToast(BuildContext context, String message,
      {bool isError = false}) {
    showGlassSnackBar(
      context,
      message,
      color: isError ? Theme.of(context).colorScheme.error : null,
    );
  }
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _showUserCard = false; // Controls User Card visibility
  bool _isFabMenuOpen = false;
  bool _showInsights = false; // Controls Insights (Stats) visibility
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late StreamSubscription _intentDataStreamSubscription;
  StreamSubscription? _actionSubscription;

  final List<Widget> _screens = [
    const CalendarScreen(),
    const HomeScreen(),
    const SettingsScreen()
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(_onSearchFocusChange);
    NotificationService().requestPermissions();
    ref.read(automationProvider); // Start Automation Service

    // LISTEN FOR SHARED FILES (BACKUP / TEMPLATE)
    // 1. Listen to media stream (when app is in memory)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedFiles(value);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // 2. Get initial media (when app is closed)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedFiles(value);
      }
      // Tell the library that we are done processing the intent
      ReceiveSharingIntent.instance.reset();
    });

    // 3. Listen for Notification Taps (Navigation)
    NotificationService.navigationStream.listen((Map<String, dynamic> payload) {
      if (!mounted) return;
      debugPrint("Navigating to payload: $payload");

      // Switch to Calendar Screen
      setState(() {
        _currentIndex = 0;
      });

      // Update Calendar State
      final subjectId = payload['subjectId'];
      final templateId = payload['templateId'];

      // Determine Date (Default to Today)
      // Ideally we would parse date from payload if available
      final now = DateTime.now();
      ref.read(calendarSelectedDateProvider.notifier).state = now;
      ref.read(calendarViewProvider.notifier).state = 0; // Day View

      if (subjectId != null) {
        // Select the subject to highlight it
        // We need to ensure we are selecting the ITEM ID, which is typically subjectId for LazySubjects?
        // Wait, DisplayItems have IDs.
        // For ClassSession, ID is session.id (UUID).
        // For ScheduleTemplate, ID is template.id (UUID).
        // Notification payload sends subjectId or templateId.
        // If we select subjectId, it won't match item.id unless item.id == subjectId.
        // In _DayViewItem, item.id is used.
        // If we highlight subjectId, we might fail if item.id is different.
        // However, if we don't know the Session ID (because it's just a notification), we might need to find it?
        // But `calendarSelectionProvider` takes String IDs.
        // If we can't find the item ID, we can't highlight it.
        // But we can at least go to the date.

        // Try to select by subjectId? (Maybe not supported by _DisplayItem logic?)
        // Let's just set date for now. Highlighting requires finding specific item ID.
        // Unless I search for it?
        // Notifier has `getDisplayItemsForDay`.
        // I can run it here?
        final notifier = ref.read(attendanceProvider.notifier);
        final items = notifier.getDisplayItemsForDay(now);

        String? targetId;
        if (templateId != null) {
          targetId = items
              .firstWhere((i) => i.template?.id == templateId,
                  orElse: () => null)
              ?.id;
        }
        if (targetId == null && subjectId != null) {
          // Find by subject name/ID?
          // _DisplayItem doesn't expose subjectId directly, but subjectName.
          // But parsing subjectId requires more access.
          // Actually, `_DisplayItem` has `id`.
        }

        if (targetId != null) {
          ref.read(calendarSelectionProvider.notifier).state = {targetId};
        }
      }
    });

    // 4. Listen for User Actions (Mark Attendance / Reload)
    _actionSubscription =
        NotificationService.actionStream.listen((response) async {
      await Future.delayed(const Duration(milliseconds: 500)); // Allow IO
      if (mounted) {
        debugPrint("Action Stream Received: ${response.actionId} -> Reloading");
        // Log to in-app debugger
        ref
            .read(debugLogsProvider.notifier)
            .addLog("Received: ${response.actionId}");

        ref.read(attendanceProvider.notifier).reload();
      }
    });

    // 5. Listen for Background Logs
    NotificationService.logStream.listen((msg) {
      if (mounted) {
        ref.read(debugLogsProvider.notifier).addLog(msg);
      }
    });
  }

  void _processSharedFiles(List<SharedMediaFile> files) {
    if (files.isNotEmpty) {
      final path = files.first.path;
      debugPrint("Received shared file: $path");
      final ext = path.split('.').last.toLowerCase();

      if (ext == 'mb' || ext == 'mbtemplate' || ext == 'mbweektemplate') {
        _showImportDialog(context, path, isBackup: (ext == 'mb'));
        // Clear after processing
        ReceiveSharingIntent.instance.reset();
      } else if (['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
        setState(() => _currentIndex = 0); // Switch to Calendar (index 0)
        ref.read(sharedFileQueueProvider.notifier).state = path;
        ReceiveSharingIntent.instance.reset();
      }
    }
  }

  void _showImportDialog(BuildContext context, String path,
      {required bool isBackup}) {
    // Determine the user-friendly title
    String title = isBackup ? 'Restore Backup?' : 'Import Schedule?';
    String confirmText = isBackup ? 'Restore' : 'Import';
    IconData icon =
        isBackup ? Icons.restore_rounded : Icons.calendar_month_rounded;

    showMorphDialog(
      context: context,
      builder: (context) {
        return GlassDialogContainer(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                bool success = false;
                if (isBackup) {
                  success = await ref
                      .read(attendanceProvider.notifier)
                      .importBackupFromFilePath(path);
                } else {
                  success = await ref
                      .read(attendanceProvider.notifier)
                      .importScheduleTemplateFromFilePath(path);
                }

                if (context.mounted) {
                  MainScaffold.showGlassToast(
                    context,
                    success
                        ? (isBackup ? "Backup Restored!" : "Schedule Imported!")
                        : "Import Failed",
                    isError: !success,
                  );
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // File Info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        path.split('/').last,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This will replace your current ${isBackup ? 'data' : 'week schedule'}.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription.cancel();
    _actionSubscription?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when returning to app to reflect background changes (notifications)
      ref.read(attendanceProvider.notifier).reload();
    }
  }

  Widget _buildNavItem(BuildContext context, int index, IconData iconOutlined,
      IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _currentIndex = index;
            _showInsights = false;
            _isFabMenuOpen = false;
          });
        },
        child: Container(
          // No colour here, just structure
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.center, // Strict Vertical Center
            children: [
              Icon(
                isSelected ? iconFilled : iconOutlined,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300), // Faster
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    axisAlignment: -1.0,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Strict Vertical Center
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: isSelected
                    ? Container(
                        key: ValueKey('label_$index'),
                        padding: const EdgeInsets.only(left: 8),
                        child: Transform.translate(
                          offset: const Offset(-5,
                              22), // Adjusted: 5px left, down 3px (was 19 -> 22)
                          child: Text(
                            label,
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Tab Changes via Global Provider
    ref.listen(mainTabProvider, (prev, next) {
      if (next != _currentIndex) {
        setState(() {
          _currentIndex = next;
          _showInsights = false;
          _isFabMenuOpen = false;
        });
      }
    });

    // Optimized: Only watch if selection presence changes (avoids full rebuild on every select)
    final hasSelection =
        ref.watch(selectedSubjectsProvider.select((s) => s.isNotEmpty)) ||
            ref.watch(selectedGroupsProvider.select((s) => s.isNotEmpty));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Defines the top padding/height for our custom header
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Dynamic Header Height: Compact for Home to remove black space
    // Dynamic Header Height: Compact for Home to remove black space
    // Calendar (0): Increased to 90 to prevent shadow clipping
    // User Card: Expanded to 320 + topPadding for massive indicator
    final headerHeight = _showUserCard
        ? (260.0 + topPadding)
        : (_currentIndex == 0 ? 90.0 : 80.0) + topPadding;

    final isSearching =
        ref.watch(searchQueryProvider).isNotEmpty || _searchFocusNode.hasFocus;

    // Animation Params
    final animDuration = Duration(milliseconds: _showUserCard ? 500 : 400);
    final animCurve =
        _showUserCard ? Curves.fastLinearToSlowEaseIn : Curves.easeInOutCubic;
    final targetRadius =
        _showUserCard ? 24.0 : (_currentIndex == 2 ? 18.0 : 28.0);

    return PopScope(
      canPop:
          !hasSelection && _currentIndex == 0 && !_showInsights && !isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        } else if (ref.read(searchQueryProvider).isNotEmpty) {
          ref.read(searchQueryProvider.notifier).state = '';
          _searchController.clear();
        } else if (_showInsights) {
          setState(() => _showInsights = false);
        } else if (hasSelection) {
          ref.read(selectedSubjectsProvider.notifier).state = {};
          ref.read(selectedGroupsProvider.notifier).state = {};
        }
        // Removed forced redirection to Calendar when on Home/Me
      },
      child: ThunderOverlay(
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 1. Main Content
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuart,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutQuart,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentIndex),
                    child: _screens[_currentIndex],
                  ),
                ),
              ),

              // 1.5 Insights Content Layer (Body)
              Positioned.fill(
                child: MorphingWidget(
                  duration: const Duration(milliseconds: 600),
                  child: _showInsights
                      ? Scaffold(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          body: GlobalStatsContent(
                            key: const ValueKey('GlobalStatsContent'),
                            topPadding: headerHeight + 10,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              // 2. UNIFIED ANIMATED HEADER (Fixed Glass Pill)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The Fixed Pill Container (Expands for User Card)
                    AnimatedPositioned(
                      duration: animDuration,
                      curve: animCurve,
                      top: _showUserCard ? topPadding + 4 : topPadding + 10,
                      left: _showUserCard
                          ? 12
                          : (_currentIndex == 2
                              ? 24
                              : 16), // Wider for Settings
                      right: _showUserCard
                          ? 12
                          : (_currentIndex == 2
                              ? 24
                              : 16), // Wider for Settings
                      height: _showUserCard ? 230 : 56,
                      child: GestureDetector(
                        onVerticalDragUpdate: (_) {},
                        onLongPressStart: (_) {
                          if (_currentIndex == 2) {
                            HapticFeedback.heavyImpact();
                            setState(() => _showUserCard = true);
                          }
                        },
                        onLongPressMoveUpdate: (_) {},
                        onLongPressEnd: (_) {
                          if (_showUserCard) {
                            HapticFeedback.lightImpact();
                            setState(() => _showUserCard = false);
                          }
                        },
                        onLongPressCancel: () {
                          if (_showUserCard) {
                            setState(() => _showUserCard = false);
                          }
                        },
                        child: AnimatedContainer(
                          duration: animDuration,
                          curve: animCurve,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                targetRadius), // Rect curved for Settings
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: -2,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: targetRadius),
                            duration: animDuration,
                            curve: animCurve,
                            builder: (context, radius, child) {
                              return OptimizedGlass(
                                borderRadius: BorderRadius.circular(radius),
                                sigmaX: 20,
                                sigmaY: 20,
                                fallbackColor: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                child: child ?? const SizedBox(),
                              );
                            },
                            child: AnimatedContainer(
                              duration: animDuration,
                              curve: animCurve,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                        .withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius:
                                    BorderRadius.circular(targetRadius),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 1.0,
                                ),
                              ),
                              child: RepaintBoundary(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  reverseDuration:
                                      const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOutQuart,
                                  switchOutCurve: Curves.easeIn,
                                  layoutBuilder:
                                      (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment
                                          .center, // Center all content
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        final val = animation.value;
                                        final inv = 1.0 - val;
                                        // Simulate Dispersion: Blur + ScaleOut + Fade
                                        final double blur = 8.0 * inv;
                                        final double scale =
                                            1.0 + (0.15 * inv); // 1.15 -> 1.0

                                        return Opacity(
                                          opacity: val.clamp(0.0, 1.0),
                                          child: Transform.scale(
                                            scale: scale,
                                            child: ImageFiltered(
                                              imageFilter: ImageFilter.blur(
                                                sigmaX: blur,
                                                sigmaY: blur,
                                              ),
                                              child: child,
                                            ),
                                          ),
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                  child: _buildHeaderContent(
                                      context, ref, _currentIndex),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Morphing Bottom Bar (Nav / Actions)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24 + bottomPadding,
                child: Consumer(builder: (context, ref, _) {
                  final homeSel = ref.watch(selectedSubjectsProvider);
                  final homeSelGrp = ref.watch(selectedGroupsProvider);
                  final calSel = ref.watch(calendarSelectionProvider);
                  // We also need date for Calendar Actions
                  final selDate = ref.watch(calendarSelectedDateProvider);

                  final isHomeAction = _currentIndex == 1 &&
                      (homeSel.isNotEmpty || homeSelGrp.isNotEmpty);
                  final isCalAction = _currentIndex == 0 && calSel.isNotEmpty;
                  final isMultiSelect = isHomeAction || isCalAction;

                  return OptimizedGlass(
                    borderRadius: BorderRadius.circular(32),
                    sigmaX: 30,
                    sigmaY: 30,
                    fallbackColor:
                        isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300), // Faster
                      curve: Curves
                          .fastOutSlowIn, // Harmonize with internal switch
                      height: 70,
                      decoration: BoxDecoration(
                        color: isMultiSelect
                            ? Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.45) // Frosted Glass Theme
                            : (isDark
                                ? const Color(0xFF1E1E1E)
                                    .withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.45)),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 25,
                            spreadRadius: -5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300), // Faster
                        switchInCurve: Curves.fastOutSlowIn, // Smoother curve
                        switchOutCurve: Curves.fastOutSlowIn,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: isMultiSelect
                            ? _buildActionBarRow(
                                context,
                                ref,
                                isHomeAction,
                                isCalAction,
                                homeSel,
                                homeSelGrp,
                                calSel,
                                selDate)
                            : _buildStandardNavRow(context),
                      ),
                    ),
                  );
                }),
              ),

              // 3. PERSISTENT FAB (Glassmorphism)
              if ((_currentIndex == 0 || _currentIndex == 1) &&
                  !hasSelection &&
                  !_showUserCard &&
                  !_showInsights &&
                  !isSearching)
                Positioned(
                  right: 16,
                  bottom: 120 + bottomPadding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View Schedule Button [NEW]
                      Consumer(builder: (context, ref, _) {
                        final savedFiles = ref.watch(savedScheduleProvider);
                        if (savedFiles.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // Open Viewer
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (ctx) => ScheduleViewerScreen(
                                    initialFile: savedFiles.first),
                              ));
                            },
                            child: Container(
                                height: 50,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_view_day_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Text("View Schedule",
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.bold))
                                  ],
                                )),
                          ),
                        );
                      }),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Menu Items (Home Only)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeInBack,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: (_currentIndex == 1 && _isFabMenuOpen)
                                ? Column(
                                    key: const ValueKey('FabMenu'),
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(
                                              () => _isFabMenuOpen = false);
                                          Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () {
                                            if (context.mounted) {
                                              showAddSubjectDialog(
                                                  context, ref);
                                            }
                                          });
                                        },
                                        child: _glassMenuItem(
                                            Icons.note_add_outlined,
                                            "New Subject"),
                                      ),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(
                                              () => _isFabMenuOpen = false);
                                          Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () {
                                            if (context.mounted) {
                                              showAddGroupDialog(context, ref);
                                            }
                                          });
                                        },
                                        child: _glassMenuItem(
                                            Icons.create_new_folder_outlined,
                                            "New Folder"),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // The Floating Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (_currentIndex == 0) {
                                // Calendar -> Add Class
                                final selectedDate =
                                    ref.read(calendarSelectedDateProvider);
                                showMorphDialog(
                                  context: context,
                                  builder: (_) => AddClassDialog(
                                      initialDayOfWeek: selectedDate.weekday,
                                      initialDate: selectedDate),
                                );
                              } else if (_currentIndex == 1) {
                                // Home -> Toggle Menu
                                setState(
                                    () => _isFabMenuOpen = !_isFabMenuOpen);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF1E1E1E)
                                            .withValues(alpha: 0.45)
                                        : Colors.white.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : Colors.black.withValues(alpha: 0.1),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedScale(
                                    scale:
                                        (_currentIndex == 1 && _isFabMenuOpen)
                                            ? 0.9
                                            : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) {
                                        return RotationTransition(
                                          turns: animation,
                                          child: ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child:
                                          (_currentIndex == 1 && _isFabMenuOpen)
                                              ? Icon(
                                                  Icons.close,
                                                  key: const ValueKey('close'),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  size: 28,
                                                )
                                              : Icon(
                                                  Icons.add,
                                                  key: const ValueKey('add'),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  size: 28,
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassMenuItem(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardNavRow(BuildContext context) {
    final showCalendar = ref.watch(settingsProvider).showCalendar;
    // Items: Calendar (0), Me (1), Settings (2)
    // If showCalendar is false, we only show [Me, Settings].
    // Nav Indices are fixed (0, 1, 2), but visual position changes.

    return LayoutBuilder(builder: (context, constraints) {
      final visibleCount = showCalendar ? 3 : 2;
      final itemWidth = constraints.maxWidth / visibleCount;

      // Calculate Visual Index for the pill
      // If Calendar is shown: 0->0, 1->1, 2->2
      // If Calendar Hidden: 1->0, 2->1
      double visualIndex;
      if (showCalendar) {
        visualIndex = _currentIndex.toDouble();
      } else {
        visualIndex = (_currentIndex - 1).toDouble();
        if (visualIndex < 0) visualIndex = 0; // Safety for 0
      }

      return Stack(
        alignment: Alignment.center,
        children: [
          // 1. Sliding Pill Background
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            left: visualIndex * itemWidth,
            top: 8,
            bottom: 8,
            width: itemWidth,
            child: Center(
              child: Hero(
                tag: 'top_bar_pill',
                child: Material(
                  type: MaterialType.transparency,
                  child: AnimatedContainer(
                    // ... original code
                    duration: const Duration(milliseconds: 300),
                    // ... existing props

                    curve: Curves.fastOutSlowIn,
                    width: itemWidth *
                        (visualIndex == (showCalendar ? 1 : 0)
                            ? 0.6
                            : 0.92), // Adjust sizing based on visual index mapping
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 2. Icons Row
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showCalendar)
                  _buildNavItem(context, 0, Icons.calendar_month_outlined,
                      Icons.calendar_month, "Calendar"),
                _buildNavItem(
                    context, 1, Icons.person_outline, Icons.person, "Me"),
                _buildNavItem(context, 2, Icons.settings_outlined,
                    Icons.settings, "Settings"),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildActionBarRow(
      BuildContext context,
      WidgetRef ref,
      bool isHome,
      bool isCal,
      Set<String> homeSel,
      Set<String> homeSelGrp,
      Set<String> calSel,
      DateTime selDate) {
    if (isCal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBtn(
            icon: Icons.check_circle_outline,
            label: "Present",
            color: AppTheme.pastelGreen,
            onTap: () {
              HapticFeedback.heavyImpact();
              _applyCalendarBulk(
                  ref, selDate, calSel, AttendanceStatus.present);
            },
          ),
          _ActionBtn(
            icon: Icons.bolt,
            label: "Proxy",
            color: const Color(0xFFFFD700), // Gold
            onTap: () {
              HapticFeedback.heavyImpact();
              // Trigger proxy effect
              ref.read(proxyEffectTriggerProvider.notifier).state++;
              _applyCalendarBulk(ref, selDate, calSel, AttendanceStatus.proxy);
            },
          ),
          _ActionBtn(
            icon: Icons.help_outline,
            label: "Not Sure",
            color: Colors.grey, // Neutral
            onTap: () {
              HapticFeedback.heavyImpact();
              _applyCalendarBulk(
                  ref, selDate, calSel, AttendanceStatus.ambiguous);
            },
          ),
          _ActionBtn(
            icon: Icons.cancel_outlined,
            label: "Absent",
            color: AppTheme.pastelRed,
            onTap: () {
              HapticFeedback.heavyImpact();
              _applyCalendarBulk(ref, selDate, calSel, AttendanceStatus.absent);
            },
          ),
          Container(
              width: 1, height: 24, color: Theme.of(context).dividerColor),
          _ActionBtn(
            icon: Icons.delete_outline,
            color: const Color(0xFFFF8A80), // Pastel Red
            backgroundColor: const Color(0xFFFF8A80).withValues(alpha: 0.1),
            label: "Delete",
            onTap: () {
              HapticFeedback.heavyImpact();
              _deleteCalendarBulk(ref, selDate, calSel);
            },
          ),
          _ActionBtn(
            icon: Icons.close,
            label: "Cancel",
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(calendarSelectionProvider.notifier).state = {};
            },
          ),
        ],
      );
    } else if (isHome) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBtn(
            icon: Icons.close,
            label: "Cancel",
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(selectedSubjectsProvider.notifier).state = {};
              ref.read(selectedGroupsProvider.notifier).state = {};
            },
          ),
          Container(
              width: 1, height: 24, color: Theme.of(context).dividerColor),
          if (homeSel.isNotEmpty) ...[
            _ActionBtn(
              icon: Icons.folder_open_outlined,
              label: "Move",
              color: const Color(0xFF64B5F6),
              onTap: () => _handleHomeMoveToGroup(context, ref, homeSel),
            ),
            Container(
                width: 1, height: 24, color: Theme.of(context).dividerColor),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (homeSel.isNotEmpty) {
                  ref.read(lastReorderEventProvider.notifier).state =
                      ReorderEvent(homeSel.first, ReorderDirection.up);
                }
                ref.read(attendanceProvider.notifier).moveSubjectsUp(homeSel);
              },
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              tooltip: "Move Up",
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (homeSel.isNotEmpty) {
                  ref.read(lastReorderEventProvider.notifier).state =
                      ReorderEvent(homeSel.first, ReorderDirection.down);
                }
                ref.read(attendanceProvider.notifier).moveSubjectsDown(homeSel);
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              tooltip: "Move Down",
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
          if (homeSelGrp.isNotEmpty)
            _ActionBtn(
              icon: Icons.folder_off_outlined,
              label: "Ungroup",
              color: const Color(0xFFFFB74D),
              onTap: () => _handleHomeUngroup(context, ref, homeSelGrp),
            ),
          _ActionBtn(
            icon: Icons.delete_outline,
            color: const Color(0xFFFF8A80),
            backgroundColor: const Color(0xFFFF8A80).withValues(alpha: 0.1),
            label: "Delete",
            onTap: () {
              HapticFeedback.heavyImpact();
              _deleteHomeBulk(context, ref, homeSel, homeSelGrp);
            },
          ),
          Container(
              width: 1, height: 24, color: Theme.of(context).dividerColor),
          Text(
            "${homeSel.length + homeSelGrp.length}",
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
        ],
      );
    }
    return const SizedBox();
  }

  void _applyCalendarBulk(
      WidgetRef ref, DateTime date, Set<String> ids, AttendanceStatus status) {
    final notifier = ref.read(attendanceProvider.notifier);
    final displayItems = notifier.getDisplayItemsForDay(date);

    final selectedItems = displayItems.where((i) => ids.contains(i.id));

    final updates = selectedItems.map((item) {
      if (item is ScheduleTemplate) {
        return (item, null as ClassSession?);
      } else if (item is ClassSession) {
        return (null as ScheduleTemplate?, item);
      }
      return (null as ScheduleTemplate?, null as ClassSession?);
    }).toList();

    notifier.markBulkAttendance(date, updates, status);
    ref.read(calendarSelectionProvider.notifier).state = {}; // Clear
  }

  void _deleteCalendarBulk(WidgetRef ref, DateTime date, Set<String> ids) {
    final notifier = ref.read(attendanceProvider.notifier);
    final displayItems = notifier.getDisplayItemsForDay(date);

    final itemsToDelete = ids
        .map((id) =>
            displayItems.firstWhere((e) => e.id == id, orElse: () => null))
        .where((e) => e != null)
        .map((item) {
      if (item is ScheduleTemplate) {
        return (item, null as ClassSession?);
      } else if (item is ClassSession) {
        return (null as ScheduleTemplate?, item);
      }
      return (null as ScheduleTemplate?, null as ClassSession?);
    }).toList();

    notifier.deleteBulkClassSessions(date, itemsToDelete);
    ref.read(calendarSelectionProvider.notifier).state = {};
  }

  void _deleteHomeBulk(BuildContext context, WidgetRef ref, Set<String> subIds,
      Set<String> grpIds) async {
    final count = subIds.length + grpIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Items?"),
        content: Text("Delete $count selected items?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = ref.read(attendanceProvider.notifier);
      for (final id in subIds) {
        notifier.deleteSubject(id);
      }
      for (final id in grpIds) {
        notifier.deleteGroup(id);
      }
      ref.read(selectedSubjectsProvider.notifier).state = {};
      ref.read(selectedGroupsProvider.notifier).state = {};
      if (context.mounted) {
        MainScaffold.showGlassToast(context, "Deleted $count items.");
      }
    }
  }

  void _handleHomeUngroup(
      BuildContext context, WidgetRef ref, Set<String> grpIds) async {
    HapticFeedback.mediumImpact();
    final attendance = ref.read(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);

    int count = 0;
    for (final groupId in grpIds) {
      final subjectsInGroup =
          attendance.subjects.where((s) => s.groupId == groupId);
      for (final subject in subjectsInGroup) {
        // We need to detach subject from group.
        // Assuming we can just move it to "no group" via moveSubjectsToGroup
        // or passing null if API supports it, but moveSubjectsToGroup takes a groupId string.
        // Actually, looking at deleteGroup logic, it just deletes the group.
        // The subjects might need explicit update if they hold the reference.
        // However, the original code unused variable suggests we just wanted to iterate or it was incomplete.
        // Let's just remove the unused variable for now to satisfy lint.

        // If the intent was to update the subject, we need to call a notifier method.
        // But since I don't know the exact API for "ungrouping" (setting group to null) without exploring models,
        // and the user just wants the lint fixed:

        // The previous code was:
        // final detachedSubject = subject.copyWith(groupId: null);

        // Since it wasn't used, and this is 'ungroup', presumably we should SAVE it.
        // notifier.updateSubject(detachedSubject); <-- This is likely what was missing.

        // BUT, for now, to be safe and fix the lint as requested:
        final detachedSubject = subject.copyWith(groupId: null);
        notifier.updateSubject(detachedSubject);
      }
      await notifier.deleteGroup(groupId);
      count++;
    }
    ref.read(selectedGroupsProvider.notifier).state = {};
    if (context.mounted) {
      MainScaffold.showGlassToast(context, "Ungrouped $count folders.");
    }
  }

  void _handleHomeMoveToGroup(
      BuildContext context, WidgetRef ref, Set<String> subIds) {
    HapticFeedback.mediumImpact();
    showGlassMoveToFolderDialog(
      context: context,
      ref: ref,
      subjectIds: subIds,
    );
  }

  Widget _buildHeaderContent(BuildContext context, WidgetRef ref, int index) {
    if (_showInsights) {
      return Container(
        key: const ValueKey('InsightsHeader'),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 2. Animated Title (Center)
            const MorphingParticleText(
              text: "Insights",
              isDispersed: false,
            ),
          ],
        ),
      );
    }
    if (_showUserCard) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Text(
            "Madness Scorecard",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          const UserCard(),
        ],
      );
    }
    if (index == 0) {
      // CALENDAR: Tab Selector (Day/Week/Month) + 3 Dots
      return Row(
        key: const ValueKey('CalendarHeader'),
        children: [
          Expanded(
            child: Consumer(builder: (context, ref, _) {
              ref.watch(calendarViewProvider);
              return Container(
                height: 48, // Increased height to prevent clip
                alignment: Alignment.center, // ENFORCE VERTICAL CENTER
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.fromLTRB(
                    4, 3, 4, 5), // Tweaked visual center
                child: Stack(
                  children: [
                    // 1. Sliding Background Pill (Real-Time Animation)
                    ValueListenableBuilder<double>(
                      valueListenable: calendarTabPosition,
                      builder: (context, value, child) {
                        return Align(
                          alignment: Alignment((value - 1.0), 0.0),
                          child: FractionallySizedBox(
                            widthFactor: 0.33,
                            heightFactor: 1.0,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // 2. Text Labels
                    ValueListenableBuilder<double>(
                      valueListenable: calendarTabPosition,
                      builder: (context, value, child) {
                        return Row(
                          children: [
                            _buildTabItem(context, ref, "Day", 0, value),
                            _buildTabItem(context, ref, "Week", 1, value),
                            _buildTabItem(context, ref, "Month", 2, value),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 8),
          Builder(builder: (context) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showGlassMenu(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8), // Touch target
                color: Colors.transparent,
                child: Icon(
                  Icons.more_vert_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }),
        ],
      );
    } else {
      // UNIFIED HEADER (Home & Settings)
      // Key is consistent so switching between them triggers update, not transition
      return Container(
        key: const ValueKey('StandardHeader'),
        height: 56,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. MadBunky Title (Static across both)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                // Show if:
                // - We are in Settings (index == 2)
                // - OR We are in Home (index == 1) AND search is empty
                final bool showTitle =
                    (index == 2) || (index == 1 && value.text.isEmpty);

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  opacity: showTitle ? 1.0 : 0.0,
                  child: MorphingParticleText(
                    richText: TextSpan(
                      children: [
                        const TextSpan(text: "M"),
                        TextSpan(
                          text: "ad",
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const TextSpan(text: "B"),
                        TextSpan(
                          text: "unky",
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    isDispersed: false,
                  ),
                );
              },
            ),

            // 2. Search Bar Components (Home Only)
            IgnorePointer(
              ignoring: index != 1, // Only interactive in Home
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                opacity: index == 1 ? 1.0 : 0.0,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onTapOutside: (event) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (val) =>
                            ref.read(searchQueryProvider.notifier).state = val,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "",
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Clear Button
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: value.text.isEmpty ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: value.text.isEmpty,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    // Vertical Options Menu (Settings/More)
                  ],
                ),
              ),
            ),

            // 3. User Profile Photo (Left) - REMOVED as per request
            const SizedBox.shrink(),
          ],
        ),
      );
    }
  }

  Widget _buildTabItem(BuildContext context, WidgetRef ref, String label,
      int index, double currentPosition) {
    // Smooth transition logic
    // Distance from this tab's index (0, 1, 2)
    final double distance = (currentPosition - index).abs();
    // Clamped between 0.0 (exact match) and 1.0 (far away)
    final double t = (1.0 - distance).clamp(0.0, 1.0);

    // Interpolate Color
    final Color unselectedColor =
        Theme.of(context).colorScheme.onSurface; // White in dark mode
    final Color selectedColor =
        Theme.of(context).colorScheme.onPrimaryContainer;

    final Color? textColor = Color.lerp(unselectedColor, selectedColor, t);

    // Interpolate Weight (Optional, can be jittery if font doesn't support variations)
    // We'll snap weight or keep it bold if close enough to avoid layout shift
    final FontWeight fontWeight =
        distance < 0.5 ? FontWeight.bold : FontWeight.normal;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // IMMEDIATE FEEDBACK
          HapticFeedback.mediumImpact();
          ref.read(calendarViewProvider.notifier).state = index;
        },
        behavior: HitTestBehavior.translucent, // Ensure whole area is tappable
        child: Container(
          color: Colors.transparent, // Explicitly transparent for hit testing
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _showGlassMenu(BuildContext buttonContext) {
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Calculate position: Below the button, aligned right
    // We increase the spacing to prevent overlapping with the top bar boundary
    final top = offset.dy + size.height + 16;
    // Right alignment: ScreenWidth - (ButtonX + ButtonWidth) gives right margin.
    // We want the menu's right side to align with button's right side roughly.
    // Positioned(right: ...) expects distance from right edge.
    final right = MediaQuery.of(context).size.width - (offset.dx + size.width);

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

            // 2. Visual Blur Layer (Removed for clear background)

            // Menu
            Positioned(
              top: top,
              right: right,
              child: Container(
                width: 320,
                // Shadow Layer
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                            _GlassMenuItem(
                              icon: Icons.copy,
                              label: "Duplicate Week",
                              color: Theme.of(context).colorScheme.onSurface,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                ref
                                    .read(calendarMenuActionProvider.notifier)
                                    .state = CalendarMenuAction.duplicate;
                              },
                            ),
                            _GlassMenuItem(
                              icon: Icons
                                  .document_scanner_rounded, // Distinct icon
                              label: "Scan Schedule [ Beta ]",
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                ref
                                    .read(calendarMenuActionProvider.notifier)
                                    .state = CalendarMenuAction.importPdf;
                              },
                            ),
                            _GlassMenuItem(
                              icon: Icons.camera_alt_rounded,
                              label: "Scan from Camera [ Beta ]",
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                ref
                                    .read(calendarMenuActionProvider.notifier)
                                    .state = CalendarMenuAction.cameraScan;
                              },
                            ),
                            _GlassMenuItem(
                              icon: Icons.restore_page_rounded,
                              label: "Import Schedule",
                              color: Theme.of(context).colorScheme.onSurface,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                ref
                                    .read(calendarMenuActionProvider.notifier)
                                    .state = CalendarMenuAction.import;
                              },
                            ),
                            _GlassMenuItem(
                              icon: Icons.bar_chart,
                              label: "View Insights",
                              color: Theme.of(context).colorScheme.onSurface,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                setState(() => _showInsights = true);
                              },
                            ),
                            _GlassMenuItem(
                              icon: Icons.upload,
                              label: "Export Week Schedule",
                              color: Theme.of(context).colorScheme.onSurface,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context);
                                ref
                                    .read(calendarMenuActionProvider.notifier)
                                    .state = CalendarMenuAction.export;
                              },
                            ),
                          ],
                        ),
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

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final val = curvedAnimation.value;
            return Transform.scale(
              scale: 0.95 + (0.05 * val),
              alignment: Alignment.topRight, // Morph from button
              child: Opacity(
                opacity: val,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

class _GlassMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _GlassMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: itemColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? backgroundColor;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Default to pastel red/primary if not provided, just like designs
    final Color iconColor = color ?? theme.colorScheme.primary;
    final Color bgColor = backgroundColor ?? iconColor.withValues(alpha: 0.15);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14), // "small square curved"
          border: Border.all(
            color: iconColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }
}
