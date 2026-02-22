import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../utils/morph_dialog.dart';

class GlassColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final bool initialIsNeon;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<bool>? onNeonChanged; // Changed to nullable

  const GlassColorPickerDialog({
    super.key,
    required this.initialColor,
    this.initialIsNeon = false,
    required this.onColorChanged,
    this.onNeonChanged, // Optional
  });

  @override
  State<GlassColorPickerDialog> createState() => _GlassColorPickerDialogState();
}

class _GlassColorPickerDialogState extends State<GlassColorPickerDialog> {
  // State for the picker
  late Color _pickerColor;
  late Color _swatchBaseColor; // Anchor for generating shades
  late bool _isNeon; // Added
  bool _isWheel = false;

  // Curated list of colors for the horizontal picker
  final List<Color> _baseColors = [
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
    const Color(0xFF9E9E9E), // True Neutral Grey
    const Color(0xFF424242), // True Neutral Dark Grey
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.initialColor;
    _swatchBaseColor = widget.initialColor;
    _isNeon = widget.initialIsNeon; // Added
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Customize Look",
      padding: EdgeInsets.zero,
      actions: [
        // ... (Keep existing actions, but ensure Apply updates Neon too)
        TextButton(
          onPressed: () {
            // Sentinel for removal
            widget.onColorChanged(Colors.transparent);
            if (widget.onNeonChanged != null) {
              widget.onNeonChanged!(false); // Reset Neon
            }
            Navigator.of(context).pop(Colors.transparent);
          },
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.pastelRed,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          child: const Text("Remove Color"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorChanged(_pickerColor);
            if (widget.onNeonChanged != null) {
              widget.onNeonChanged!(_isNeon); // Apply Neon
            }
            Navigator.of(context).pop(_pickerColor);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _pickerColor,
            foregroundColor:
                ThemeData.estimateBrightnessForColor(_pickerColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text("Apply"),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _buildTab("Palette", !_isWheel),
                  _buildTab("Wheel", _isWheel),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve:
                        Curves.easeInOutCubic, // Smooth resizing without bounce
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: !_isWheel
                          ? KeyedSubtree(
                              key: const ValueKey('Palette'),
                              child: _buildPrimaryPicker())
                          : KeyedSubtree(
                              key: const ValueKey('Wheel'),
                              child: _buildWheelPicker()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Neon Mode Toggle (Only show if callback provided)
          if (widget.onNeonChanged != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.blur_on,
                    color: _isNeon
                        ? _pickerColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Neon Mode",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Vibrant colors & deep contrast",
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isNeon,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _isNeon = val);
                    },
                    activeThumbColor: _pickerColor,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isSelected) return;
          HapticFeedback.selectionClick();
          setState(() => _isWheel = label == "Wheel");
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Horizontal Scrollable Primary Colors (2 Rows)
        SizedBox(
          height: 100, // 2 rows * ~44px + spacing
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _baseColors.length,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final color = _baseColors[index];
              final isSelected = _pickerColor.toARGB32() ==
                  color.toARGB32(); // Simple value check

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  // Update BOTH picker and base when selecting a main color
                  setState(() {
                    _pickerColor = color;
                    _swatchBaseColor = color;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),
        const Divider(height: 1),

        // 2. Shades (Custom Implementation)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text('Shade',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ),

        Builder(
          builder: (context) {
            // Use custom swatch generator on the BASE anchor color
            final MaterialColor swatch = _createCustomSwatch(_swatchBaseColor);
            final List<int> indexes = [
              50,
              100,
              200,
              300,
              400,
              500,
              600,
              700,
              800,
              // 850 excluded
              900
            ];

            return Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: indexes.map((i) {
                  final Color? shade = swatch[i];
                  if (shade == null) return const SizedBox.shrink();

                  final bool isSelected =
                      _pickerColor.toARGB32() == shade.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // Only update picker color, keep base anchor
                      setState(() => _pickerColor = shade);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: shade,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: shade.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  // Custom Swatch Generator to prevent color drift
  MaterialColor _createCustomSwatch(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = <int, Color>{};
    // Removed unused r, g, b

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    // For specific shades logic or just linear interpolation
    // Using a simple lighter/darker logic based on the picked color
    // This simple algorithm ensures we stay in the same "hue" (or lack thereof for grey)
    // It's a simplified version of what Flutter does but anchored strictly to the RGB of the base.

    // Note: To get precise Material 2014 shades we usually use HSL, but this
    // simple mix with white/black is robust for preventing "Teal" drift on Greys.
    for (var strength in strengths) {
      final double ds = 0.5 - strength;

      // If we are making it lighter (strength < 0.5), mix with white
      // If darker, mix with black
      Color newColor;
      if (ds > 0) {
        // Lighten
        // 0.05 strength (index 50) -> very light
        // strength 0.5 -> original (mostly)
        // Map strength .05 .. .5 to factor

        // Actually, let's use tinycolor logic: mix with white or black
        // 50: 95% white, 500: 0% white, 900: 90% black
        // This is a rough approximation but safe for hue.

        // Removed unused 'weight' var
        // Let's stick to standard `Color.lerp`
        // index 50 (strength .05) should be ~90% white
        // index 500 (strength .5) is base

        double t = (0.5 - strength) * 2; // .05 -> .45*2 = .9 (mix 90% white)
        newColor = Color.lerp(color, Colors.white, t)!;
      } else {
        // Darken
        // Strength .6 -> .9
        double t = (strength - 0.5) * 2; // .9 -> .4*2 = .8 (mix 80% black)
        newColor = Color.lerp(color, Colors.black, t)!;
      }

      // Fix index mapping
      int index = (strength * 1000).round();
      swatch[index] = newColor;
    }
    // Ensure 500 is base
    swatch[500] = color;

    return MaterialColor(color.toARGB32(), swatch);
  }

  Widget _buildWheelPicker() {
    return Column(
      children: [
        ColorPicker(
          color: _pickerColor,
          onColorChanged: (c) => setState(() => _pickerColor = c),
          wheelDiameter: 220, // Nice and large
          wheelWidth: 16,
          enableOpacity: false,
          pickersEnabled: const {
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.wheel: true,
          },
          showColorCode: true,
          colorCodeHasColor: true,
          enableTooltips: true,
          heading:
              Text("Wheel", style: Theme.of(context).textTheme.titleMedium),
          subheading: Text("Select shade",
              style: Theme.of(context).textTheme.titleSmall),
          wheelSubheading: Text("Selected color and its shades",
              style: Theme.of(context).textTheme.titleSmall),
          showMaterialName: false,
          showRecentColors: false,
          title: const SizedBox.shrink(), // No Title
          width: 40,
          height: 40,
          borderRadius: 4,
          spacing: 5,
          runSpacing: 5,
        ),
      ],
    );
  }
}
