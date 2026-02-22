import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../utils/morph_dialog.dart';

class ScanOptionsDialog extends StatefulWidget {
  final ScanOptions initialOptions;

  const ScanOptionsDialog({
    super.key,
    this.initialOptions = const ScanOptions(),
  });

  @override
  State<ScanOptionsDialog> createState() => _ScanOptionsDialogState();
}

class _ScanOptionsDialogState extends State<ScanOptionsDialog> {
  late bool _useGridAnalysis;
  late bool _useLineEnhancement;

  @override
  void initState() {
    super.initState();
    _useGridAnalysis = widget.initialOptions.useGridAnalysis;
    _useLineEnhancement = widget.initialOptions.useLineEnhancement;
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Scan Options",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              ScanOptions(
                useGridAnalysis: _useGridAnalysis,
                useLineEnhancement: _useLineEnhancement,
              ),
            );
          },
          child: const Text("Start Analysis"),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            "Configure how the app interprets your timetable.",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _OptionToggle(
            title: "Smart Grid Analysis",
            subtitle:
                "Recommended for clear tables/grids. Detects rows and columns automatically.",
            value: _useGridAnalysis,
            onChanged: (val) => setState(() => _useGridAnalysis = val),
            icon: Icons.grid_on_rounded,
          ),
          const Divider(height: 32),
          _OptionToggle(
            title: "Lines Processing",
            subtitle:
                "Enhances faint or broken lines in the image before analysis. Great for scanned PDFs.",
            value: _useLineEnhancement,
            onChanged: (val) => setState(() => _useLineEnhancement = val),
            icon: Icons.linear_scale_rounded,
          ),
          const SizedBox(height: 16),
          _PresetButton(
            title: "Standard Table",
            icon: Icons.table_chart_outlined,
            onTap: () {
              setState(() {
                _useGridAnalysis = true;
                _useLineEnhancement = true;
              });
            },
          ),
          const SizedBox(height: 8),
          _PresetButton(
            title: "Simple List / Notes",
            icon: Icons.format_list_bulleted_rounded,
            onTap: () {
              setState(() {
                _useGridAnalysis = false;
                _useLineEnhancement = false;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _OptionToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const _OptionToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _PresetButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
