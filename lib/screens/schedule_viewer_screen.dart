import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/morph_dialog.dart';
import '../screens/main_scaffold.dart';
import 'package:path/path.dart' as path;

enum DrawingTool { marker, highlighter, eraser, brush, fountainPen }

enum EraserMode { stroke, area }

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  final double pressure;
  DrawingPoint(
      {required this.offset, required this.paint, this.pressure = 0.5});
}

class ScheduleViewerScreen extends ConsumerStatefulWidget {
  final File? initialFile;
  const ScheduleViewerScreen({super.key, this.initialFile});

  @override
  ConsumerState<ScheduleViewerScreen> createState() =>
      _ScheduleViewerScreenState();
}

class _ScheduleViewerScreenState extends ConsumerState<ScheduleViewerScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final GlobalKey _repoKey = GlobalKey();

  late File _currentFile;

  // Annotation State
  bool _isAnnotating = false;
  List<DrawingPoint?> _points = [];

  // Tool Config
  DrawingTool _currentTool = DrawingTool.marker;
  DrawingTool? _previousTool; // For S-Pen eraser toggle
  Color _selectedColor = Colors.red;

  // Granular Sizes per tool
  double _markerSize = 4.0;
  double _brushSize = 8.0;
  double _fountainPenSize = 6.0;
  double _highlighterSize = 20.0;
  double _eraserSize = 30.0;
  double _highlighterOpacity = 0.5;

  // Eraser Config
  final EraserMode _eraserMode = EraserMode.area;

  // Toolbar State
  bool _isToolbarMinimized = false;

  // History for Undo
  final List<List<DrawingPoint?>> _undoStack = [];

  // Input Handling
  DateTime? _lastStylusUsageTime;
  int? _activePointerId;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    // We expect initialFile to be passed now from the grid
    if (widget.initialFile != null) {
      _currentFile = widget.initialFile!;
    } else {
      // Fallback for safety
      _currentFile = File('');
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAnnotating() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAnnotating = !_isAnnotating;
      // Reset transform when starting annotation
      if (_isAnnotating) {
        _transformController.value = Matrix4.identity();
      }
    });
  }

  void _selectTool(DrawingTool tool) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentTool = tool;
      if (tool == DrawingTool.marker) {
        _selectedColor = Colors.red;
      } else if (tool == DrawingTool.brush) {
        _selectedColor = Colors.orange;
      } else if (tool == DrawingTool.fountainPen) {
        _selectedColor = Colors.blueGrey;
      } else if (tool == DrawingTool.highlighter) {
        _selectedColor = Colors.yellow.withValues(alpha: _highlighterOpacity);
      } else {
        _selectedColor = Colors.transparent;
      }
    });
  }

  void _changeColor(Color color) {
    setState(() {
      _selectedColor = _currentTool == DrawingTool.highlighter
          ? color.withValues(alpha: _highlighterOpacity)
          : color;
    });
  }

  void _updateHighlighterOpacity(double val) {
    setState(() {
      _highlighterOpacity = val;
      if (_currentTool == DrawingTool.highlighter) {
        _selectedColor = _selectedColor.withValues(alpha: val);
      }
    });
  }

  double get _currentStrokeWidth {
    switch (_currentTool) {
      case DrawingTool.marker:
        return _markerSize;
      case DrawingTool.highlighter:
        return _highlighterSize;
      case DrawingTool.eraser:
        return _eraserSize;
      case DrawingTool.brush:
        return _brushSize;
      case DrawingTool.fountainPen:
        return _fountainPenSize;
    }
  }

  void _updateStrokeWidth(double val) {
    setState(() {
      switch (_currentTool) {
        case DrawingTool.marker:
          _markerSize = val;
          break;
        case DrawingTool.highlighter:
          _highlighterSize = val;
          break;
        case DrawingTool.eraser:
          _eraserSize = val;
          break;
        case DrawingTool.brush:
          _brushSize = val;
          break;
        case DrawingTool.fountainPen:
          _fountainPenSize = val;
          break;
      }
    });
  }

  // --- Zoom Helpers ---
  void _onDoubleTap(TapDownDetails details) {
    if (_isAnnotating) return;

    Matrix4 endMatrix;
    if (_transformController.value.getMaxScaleOnAxis() > 1.2) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      endMatrix = Matrix4.identity()
        ..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0)
        ..multiply(Matrix4.diagonal3Values(2.5, 2.5, 1.0));
    }

    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: endMatrix,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.forward(from: 0);
    _animation!.addListener(() {
      _transformController.value = _animation!.value;
    });
  }

  // --- Stroke Eraser Logic ---
  void _eraseStrokesAt(Offset pos) {
    final double effectiveRadius = _eraserSize;

    List<DrawingPoint?> newPoints = List.from(_points);
    bool changed = false;

    // We identify strokes first.
    // List of (startIndex, endIndex)
    List<({int start, int end})> ranges = [];
    int start = 0;
    for (int i = 0; i < newPoints.length; i++) {
      if (newPoints[i] == null) {
        if (i > start) {
          ranges.add((start: start, end: i));
        }
        start = i + 1;
      }
    }
    // Handle trailing stroke if no final null
    if (start < newPoints.length) {
      ranges.add((start: start, end: newPoints.length));
    }

    Set<int> rangeIndicesToRemove = {};

    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      bool hit = false;
      for (int j = range.start; j < range.end; j++) {
        if ((newPoints[j]!.offset - pos).distance <= effectiveRadius) {
          hit = true;
          break;
        }
      }
      if (hit) {
        rangeIndicesToRemove.add(i);
      }
    }

    if (rangeIndicesToRemove.isNotEmpty) {
      // Rebuild list excluding removed ranges
      List<DrawingPoint?> reconstructed = [];
      for (int i = 0; i < ranges.length; i++) {
        if (!rangeIndicesToRemove.contains(i)) {
          final range = ranges[i];
          for (int j = range.start; j < range.end; j++) {
            reconstructed.add(newPoints[j]);
          }
          reconstructed.add(null); // Delimiter
        } else {
          changed = true;
        }
      }

      if (changed) {
        setState(() {
          _points = reconstructed;
        });
      }
    }
  }

  // --- Saving ---
  Future<void> _saveChanges() async {
    if (_points.isEmpty) {
      setState(() => _isAnnotating = false);
      return;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (!_currentFile.existsSync()) {
        throw Exception("File does not exist: ${_currentFile.path}");
      }
      final bytes = await _currentFile.readAsBytes();
      final bgImage = await decodeImageFromList(bytes);

      canvas.drawImage(bgImage, Offset.zero, Paint());

      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < _points.length - 1; i++) {
        final p1 = _points[i];
        final p2 = _points[i + 1];

        if (p1 != null && p2 != null) {
          paint.color = p1.paint.color;
          paint.strokeWidth = p1.paint.strokeWidth;
          paint.blendMode = p1.paint.blendMode;
          canvas.drawLine(p1.offset, p2.offset, paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(bgImage.width, bgImage.height);
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        final buffer = pngBytes.buffer.asUint8List();
        await _currentFile.writeAsBytes(buffer);
        ref.read(savedScheduleProvider.notifier).notifyChanged();

        if (mounted) {
          MainScaffold.showGlassToast(context, "Changes Saved");
          setState(() {
            _isAnnotating = false;
            _points.clear();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          });
        }
      }
    } catch (e) {
      debugPrint("Error saving annotation: $e");
    }
  }

  void _deleteSchedule(File file) {
    showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
            title: "Delete Schedule?",
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface))),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(savedScheduleProvider.notifier).delete(file);
                    Navigator.pop(
                        context); // Go back since file refers to currently viewed file
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete")),
            ],
            child: Text(
                "This will permanently remove '${path.basenameWithoutExtension(file.path)}'.")));
  }

  void _renameSchedule(File file) {
    final TextEditingController nameController =
        TextEditingController(text: path.basenameWithoutExtension(file.path));
    showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
            title: "Rename Schedule",
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      final newName = nameController.text.trim();
                      final dir = file.parent;
                      final safeName =
                          newName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
                      final newPath = '${dir.path}/$safeName.jpg';

                      await ref
                          .read(savedScheduleProvider.notifier)
                          .rename(file, newName);
                      setState(() {
                        _currentFile = File(newPath);
                      });
                    }
                  },
                  child: const Text("Rename")),
            ],
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "New Name"),
              autofocus: true,
            )));
  }

  Future<void> _shareSchedule(File file) async {
    try {
      // If NOT annotating, share the file directly
      if (!_isAnnotating) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My Schedule',
        );
        return;
      }

      // If annotating, capture the repoKey (which includes drawings)
      RenderRepaintBoundary? boundary =
          _repoKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile =
          await File('${tempDir.path}/schedule_$timestamp.png').create();
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'My Schedule',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_currentFile.existsSync()) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text("Schedule not found")),
      );
    }

    return PopScope(
      canPop: !_isAnnotating,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isAnnotating) {
          setState(() {
            _isAnnotating = false;
            _points.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Single Image Viewer instead of PageView
            GestureDetector(
              onDoubleTapDown: _onDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformController,
                panEnabled: !_isAnnotating,
                scaleEnabled: !_isAnnotating,
                minScale: 1.0,
                maxScale: 5.0,
                child: RepaintBoundary(
                  key: _repoKey,
                  child: Stack(
                    children: [
                      Center(
                        child: Image.file(
                          _currentFile,
                          fit: BoxFit.contain,
                          key: ValueKey(_currentFile.path),
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.white54),
                                SizedBox(height: 16),
                                Text("Could not load image", style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isAnnotating)
                        Positioned.fill(
                          child: Listener(
                            onPointerDown: (event) {
                              // ... [Stylus Logic Copied] ...
                              bool isStylus =
                                  event.kind == ui.PointerDeviceKind.stylus ||
                                      event.kind ==
                                          ui.PointerDeviceKind.invertedStylus;
                              if (isStylus) {
                                _lastStylusUsageTime = DateTime.now();
                              } else if (event.kind ==
                                  ui.PointerDeviceKind.touch) {
                                if (_lastStylusUsageTime != null &&
                                    DateTime.now()
                                            .difference(_lastStylusUsageTime!) <
                                        const Duration(seconds: 2)) {
                                  return;
                                }
                              }

                              if (!_isToolbarMinimized) {
                                setState(() {
                                  _isToolbarMinimized = true;
                                });
                              }

                              if (_currentTool == DrawingTool.eraser &&
                                  _eraserMode == EraserMode.stroke) {
                                _undoStack.add(List.from(_points));
                                _eraseStrokesAt(event.localPosition);
                                return;
                              }

                              // Toggle Eraser on Stylus Button
                              if (event.buttons == 2) {
                                if (_currentTool != DrawingTool.eraser) {
                                  setState(() {
                                    _previousTool = _currentTool;
                                    _currentTool = DrawingTool.eraser;
                                  });
                                } else if (_previousTool != null) {
                                  setState(() {
                                    _currentTool = _previousTool!;
                                    _previousTool = null;
                                  });
                                }
                                return;
                              }

                              setState(() {
                                _activePointerId = event.pointer;
                                if (!(_currentTool == DrawingTool.eraser &&
                                    _eraserMode == EraserMode.stroke)) {
                                  _undoStack.add(List.from(_points));

                                  double pressure = 0.5;
                                  if (event.kind ==
                                      ui.PointerDeviceKind.stylus) {
                                    pressure = event.pressure;
                                  }

                                  double activeStrokeWidth =
                                      _currentStrokeWidth;
                                  if (_currentTool == DrawingTool.brush) {
                                    activeStrokeWidth =
                                        _currentStrokeWidth * (0.5 + pressure);
                                  } else if (_currentTool ==
                                      DrawingTool.fountainPen) {
                                    activeStrokeWidth =
                                        _currentStrokeWidth * pressure * 1.5;
                                  }

                                  _points.add(DrawingPoint(
                                      offset: event.localPosition,
                                      pressure: pressure,
                                      paint: Paint()
                                        ..color = _selectedColor
                                        ..strokeWidth = activeStrokeWidth
                                        ..strokeCap = StrokeCap.round
                                        ..strokeJoin = StrokeJoin.round
                                        ..blendMode =
                                            _currentTool == DrawingTool.eraser
                                                ? BlendMode.clear
                                                : BlendMode.srcOver));
                                }
                              });
                            },
                            onPointerMove: (event) {
                              if (event.pointer != _activePointerId &&
                                  !(_currentTool == DrawingTool.eraser &&
                                      _eraserMode == EraserMode.stroke)) {
                                if (_currentTool != DrawingTool.eraser &&
                                    event.pointer != _activePointerId) {
                                  return;
                                }
                              }

                              if (_currentTool == DrawingTool.eraser &&
                                  _eraserMode == EraserMode.stroke) {
                                _eraseStrokesAt(event.localPosition);
                                return;
                              }

                              if (event.pointer == _activePointerId) {
                                setState(() {
                                  double pressure = 0.5;
                                  if (event.kind ==
                                      ui.PointerDeviceKind.stylus) {
                                    pressure = event.pressureMin != 0
                                        ? (event.pressure - event.pressureMin) /
                                            (event.pressureMax -
                                                event.pressureMin)
                                        : event.pressure;
                                    pressure = pressure.clamp(0.1, 1.0);
                                  }

                                  double activeStrokeWidth =
                                      _currentStrokeWidth;
                                  if (_currentTool == DrawingTool.brush) {
                                    activeStrokeWidth =
                                        _currentStrokeWidth * (0.5 + pressure);
                                  } else if (_currentTool ==
                                      DrawingTool.fountainPen) {
                                    activeStrokeWidth =
                                        _currentStrokeWidth * pressure * 1.5;
                                  }

                                  _points.add(DrawingPoint(
                                      offset: event.localPosition,
                                      pressure: pressure,
                                      paint: Paint()
                                        ..color = _selectedColor
                                        ..strokeWidth = activeStrokeWidth
                                        ..strokeCap = StrokeCap.round
                                        ..strokeJoin = StrokeJoin.round
                                        ..blendMode =
                                            _currentTool == DrawingTool.eraser
                                                ? BlendMode.clear
                                                : BlendMode.srcOver));
                                });
                              }
                            },
                            onPointerUp: (event) {
                              // ...
                              if (event.pointer == _activePointerId) {
                                setState(() {
                                  _points.add(null);
                                  _activePointerId = null;
                                });
                              }
                            },
                            onPointerCancel: (event) {
                              if (event.pointer == _activePointerId) {
                                setState(() {
                                  _points.add(null);
                                  _activePointerId = null;
                                });
                              }
                            },
                            child: CustomPaint(
                              painter: SchedulePainter(_points),
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ),
                      if (!_isAnnotating && _points.isNotEmpty)
                        Positioned.fill(
                            child: CustomPaint(
                          painter: SchedulePainter(_points),
                        )),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Custom Header (Glass)
            if (!_isAnnotating)
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          // Title Pill
                          GestureDetector(
                            onTap: () => _renameSchedule(_currentFile),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter:
                                    ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  color: Colors.white.withValues(alpha: 0.1),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        path.basenameWithoutExtension(
                                            _currentFile.path),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.edit,
                                          size: 14, color: Colors.white54)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(children: [
                            _GlassButton(
                              icon: Icons.share_outlined,
                              onTap: () => _shareSchedule(_currentFile),
                            ),
                            const SizedBox(width: 8),
                            _GlassButton(
                              icon: Icons.edit_outlined,
                              onTap: _toggleAnnotating,
                            ),
                            const SizedBox(width: 8),
                            _GlassButton(
                              icon: Icons.delete_outline,
                              color: Colors.redAccent,
                              onTap: () => _deleteSchedule(_currentFile),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  )),

            // 3. Toolbar Overlay (Bottom)
            if (_isAnnotating)
              if (_isToolbarMinimized)
                // ... [Same Minimized Logic]
                Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32, right: 32),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _isToolbarMinimized = false),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Icon(Icons.mode_edit_outline_outlined,
                              color: Colors.white),
                        ),
                      ),
                    ))
              else
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                                filter:
                                    ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Tools
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _ToolButton(
                                                    icon: Icons.brush,
                                                    isActive: _currentTool ==
                                                        DrawingTool.marker,
                                                    onTap: () => _selectTool(
                                                        DrawingTool.marker)),
                                                const SizedBox(width: 12),
                                                _ToolButton(
                                                    icon: Icons.highlight,
                                                    isActive: _currentTool ==
                                                        DrawingTool.highlighter,
                                                    onTap: () => _selectTool(
                                                        DrawingTool
                                                            .highlighter)),
                                                const SizedBox(width: 12),
                                                _ToolButton(
                                                    icon: Icons
                                                        .cleaning_services_rounded, // Eraser
                                                    isActive: _currentTool ==
                                                        DrawingTool.eraser,
                                                    onTap: () => _selectTool(
                                                        DrawingTool.eraser)),
                                                const SizedBox(width: 12),
                                                _ToolButton(
                                                    icon: Icons.brush,
                                                    isActive: _currentTool ==
                                                        DrawingTool.brush,
                                                    onTap: () => _selectTool(
                                                        DrawingTool.brush)),
                                                const SizedBox(width: 12),
                                                _ToolButton(
                                                    icon: Icons
                                                        .create, // Fountain Pen
                                                    isActive: _currentTool ==
                                                        DrawingTool.fountainPen,
                                                    onTap: () => _selectTool(
                                                        DrawingTool
                                                            .fountainPen)),
                                                const Spacer(),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .check, // Save Button
                                                      color:
                                                          Colors.greenAccent),
                                                  onPressed: () =>
                                                      _saveChanges(),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.undo,
                                                      color: Colors.white),
                                                  onPressed:
                                                      _undoStack.isNotEmpty
                                                          ? () {
                                                              setState(() {
                                                                _points = _undoStack
                                                                    .removeLast();
                                                              });
                                                            }
                                                          : null,
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: Colors.white70),
                                                  onPressed: () => setState(
                                                      () =>
                                                          _isToolbarMinimized =
                                                              true),
                                                ),
                                              ]),

                                          const SizedBox(height: 16),

                                          // Config Row (Size + Mode)
                                          Row(children: [
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 4.0),
                                                    child: Text(
                                                        "Size: ${_currentStrokeWidth.round()}",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 12)),
                                                  ),
                                                  SliderTheme(
                                                    data: SliderThemeData(
                                                        activeTrackColor:
                                                            Colors.white,
                                                        thumbColor:
                                                            Colors.white,
                                                        trackHeight: 2,
                                                        thumbShape:
                                                            const RoundSliderThumbShape(
                                                                enabledThumbRadius:
                                                                    6)),
                                                    child: Slider(
                                                      value:
                                                          _currentStrokeWidth,
                                                      min: 1.0,
                                                      max: 50.0,
                                                      onChanged:
                                                          _updateStrokeWidth,
                                                    ),
                                                  ),
                                                ])),
                                            const SizedBox(width: 16),
                                            // Opacity Slider for Highlighter
                                            if (_currentTool ==
                                                DrawingTool.highlighter)
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 4.0),
                                                      child: Text(
                                                          "Opacity: ${(_highlighterOpacity * 100).round()}%",
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12)),
                                                    ),
                                                    SliderTheme(
                                                      data: SliderThemeData(
                                                          activeTrackColor:
                                                              Colors.yellow,
                                                          thumbColor:
                                                              Colors.yellow,
                                                          trackHeight: 2,
                                                          thumbShape:
                                                              const RoundSliderThumbShape(
                                                                  enabledThumbRadius:
                                                                      6)),
                                                      child: Slider(
                                                        value:
                                                            _highlighterOpacity,
                                                        min: 0.1,
                                                        max: 1.0,
                                                        onChanged:
                                                            _updateHighlighterOpacity,
                                                      ),
                                                    ),
                                                  ])),
                                          ]),

                                          const SizedBox(height: 8),

                                          // Color Palette
                                          if (_currentTool !=
                                              DrawingTool.eraser)
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  Colors.red,
                                                  Colors.pink,
                                                  Colors.purple,
                                                  Colors.deepPurple,
                                                  Colors.indigo,
                                                  Colors.blue,
                                                  Colors.lightBlue,
                                                  Colors.cyan,
                                                  Colors.teal,
                                                  Colors.green,
                                                  Colors.lightGreen,
                                                  Colors.lime,
                                                  Colors.yellow,
                                                  Colors.amber,
                                                  Colors.orange,
                                                  Colors.deepOrange,
                                                  Colors.brown,
                                                  Colors.grey,
                                                  Colors.blueGrey,
                                                  Colors.black,
                                                  Colors.white,
                                                ].map((c) {
                                                  bool isSelected = _selectedColor
                                                              .toARGB32() ==
                                                          c.toARGB32() ||
                                                      (_currentTool ==
                                                              DrawingTool
                                                                  .highlighter &&
                                                          _selectedColor
                                                                  .withValues(
                                                                      alpha: 1)
                                                                  .toARGB32() ==
                                                              c.toARGB32());
                                                  return GestureDetector(
                                                    onTap: () =>
                                                        _changeColor(c),
                                                    child: Container(
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4),
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: c,
                                                        shape: BoxShape.circle,
                                                        border: isSelected
                                                            ? Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2)
                                                            : null,
                                                        boxShadow: [
                                                          if (isSelected)
                                                            BoxShadow(
                                                                color: c
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5),
                                                                blurRadius: 8,
                                                                spreadRadius: 2)
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                        ]))))))
          ],
        ),
      ),
    );
  }
}

// --- Components ---

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _GlassButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: (color ?? Colors.white).withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton(
      {required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white10,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white70),
      ),
    );
  }
}

class SchedulePainter extends CustomPainter {
  final List<DrawingPoint?> points;
  SchedulePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
            points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
