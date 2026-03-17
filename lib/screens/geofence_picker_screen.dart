import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Coordinate class
import 'package:geolocator/geolocator.dart'; // For initial position
import 'package:google_fonts/google_fonts.dart'; // Ensure font consistency
import 'dart:ui'; // For ImageFilter
import '../utils/morph_dialog.dart';

class GeofencePickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final double initialRadius;
  final String? initialName;

  const GeofencePickerScreen({
    super.key,
    this.initialLocation,
    this.initialRadius = 200.0,
    this.initialName,
  });

  @override
  State<GeofencePickerScreen> createState() => _GeofencePickerScreenState();
}

enum MapLayerType { normal, satellite }

class _GeofencePickerScreenState extends State<GeofencePickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  LatLng _center = const LatLng(28.6139, 77.2090); // Default New Delhi
  double _radius = 200.0;
  bool _isLoading = true;
  MapLayerType _currentLayer = MapLayerType.normal;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
    _nameController.text = widget.initialName ?? ""; // Set initial name
    if (widget.initialLocation != null) {
      _center = widget.initialLocation!;
      _isLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  // Release controller
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    // Retry logic: Attempt 3 times
    Position? position;
    for (int i = 0; i < 3; i++) {
      try {
        // Check service status first
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, // Try high accuracy first
            timeLimit: Duration(seconds: 5), // Short timeout per try
          ),
        );
        break;
      } catch (e) {
        debugPrint("GPS Attempt $i failed: $e");
      }
    }

    // Fallback to Last Known if current fails
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (position != null) {
          _center = LatLng(position.latitude, position.longitude);
        }
        _isLoading = false;
      });
      if (position != null) {
        _mapController.move(_center, 17.0);
      } else {
        // Show error toast if we couldn't get ANY location
        // (Assuming MainScaffold.showGlassToast is available or use SnackBar)
        showMorphSnackBar(
          context,
          message: "Could not fetch location. Please move map manually.",
        );
      }
    }
  }

  Future<bool> _checkDistanceWarning() async {
    try {
      final currentPos = await Geolocator.getCurrentPosition();
      final dist = const Distance().as(LengthUnit.Meter,
          LatLng(currentPos.latitude, currentPos.longitude), _center);

      // If distance > 50km (50,000 meters)
      if (dist > 50000) {
        if (!mounted) return true;
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Location Warning"),
                content: Text(
                    "The selected location is ${(dist / 1000).toStringAsFixed(1)}km away from where you are now.\n\nAre you sure this is the correct Campus Location?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Check Map"),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Yes, Save It"),
                  ),
                ],
              ),
            ) ??
            false;
      }
    } catch (e) {
      // If we can't check distance (e.g. GPS off), just proceed
      return true;
    }
    return true;
  }

  void _toggleLayer() {
    setState(() {
      _currentLayer = _currentLayer == MapLayerType.normal
          ? MapLayerType.satellite
          : MapLayerType.normal;
    });
  }

  // Returns the correct tile URL based on theme and selection
  String _getTileUrl() {
    if (_currentLayer == MapLayerType.satellite) {
      // Google Maps Hybrid (Satellite + Labels)
      return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
    } else {
      // Google Maps Roadmap (Best for landmarks)
      return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Custom Dark Mode Matrix (Invert Colors)
    // This turns the Light Google Map into a cool High-Contrast Dark Map
    const invertMatrix = <double>[
      -1.0,
      0.0,
      0.0,
      0.0,
      255.0,
      0.0,
      -1.0,
      0.0,
      0.0,
      255.0,
      0.0,
      0.0,
      -1.0,
      0.0,
      255.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Set Campus Geofence",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            // Map Layer (Shifted up to center in visible area)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 320, // Approximate height of the bottom sheet
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 17.0,
                  minZoom:
                      4.0, // Prevent zooming out to world view which might be buggy
                  maxZoom: 19.0, // Prevent zooming past tile availability
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture) {
                      setState(() {
                        _center = pos.center;
                      });
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  // MAP LAYER with THEME FILTER
                  if (_currentLayer == MapLayerType.normal && isDarkMode)
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.grey,
                        BlendMode.saturation, // 1. Desaturate (Greyscale)
                      ),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(
                            invertMatrix), // 2. Invert (Dark Mode)
                        child: TileLayer(
                          urlTemplate: _getTileUrl(),
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.madbunky.app',
                          maxZoom: 20,
                        ),
                      ),
                    )
                  else
                    TileLayer(
                      urlTemplate: _getTileUrl(),
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.madbunky.app',
                      maxZoom: 20,
                    ),

                  // Smooth Animated Radius Visualizer
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _radius), // Implicitly animate
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedRadius, child) {
                      return CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _center,
                            color: _currentLayer == MapLayerType.satellite
                                ? Colors.white.withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                            borderStrokeWidth: 2,
                            borderColor: _currentLayer == MapLayerType.satellite
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                            useRadiusInMeter: true,
                            radius: animatedRadius, // Smooth value
                          ),
                        ],
                      );
                    },
                  ),
                  // Center Marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.school,
                            color: Theme.of(context).colorScheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Layer Toggle Button & Recenter Button Stack
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControlButton(
                  icon: _currentLayer == MapLayerType.normal
                      ? Icons.layers
                      : Icons.map,
                  onTap: _toggleLayer,
                  tooltip: "Switch Layer",
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.my_location,
                  onTap: _getCurrentLocation,
                  tooltip: "Locate Me",
                ),
              ],
            ),
          ),

          // Bottom Sheet Control
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.black : Colors.white)
                        .withValues(alpha: 0.8),
                    border: Border(
                      top: BorderSide(
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // NAME INPUT
                      Text(
                        "Location Name",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: "e.g. Main Campus, Library",
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Geofence Radius",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_radius.round()} m",
                              style: GoogleFonts.outfit(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                          inactiveTrackColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          thumbColor: Theme.of(context).colorScheme.primary,
                          overlayColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _radius,
                          min: 10,
                          max: 1000,
                          divisions: 99, // Smooth 10m steps (approx)
                          label: "${_radius.round()} m",
                          onChanged: (val) {
                            setState(() {
                              _radius = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Drag the map to center your campus. Adjust radius to cover your college area.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          if (await _checkDistanceWarning()) {
                            if (!context.mounted) return;
                            Navigator.pop(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'radius': _radius,
                              'name': _nameController.text.trim().isEmpty
                                  ? "Campus Location"
                                  : _nameController.text.trim(),
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Confirm Location",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.tooltip = "",
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurface,
          size: 24,
        ),
      ),
    );
  }
}
