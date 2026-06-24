import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/morph_dialog.dart';

class BatchSelectionDialog extends StatefulWidget {
  // final Set<String> availableBatches; // Partial fix: using split lists
  final Set<String> practicalBatches;
  final Set<String> clinicBatches;
  final Function(List<String> practicals, List<String> clinics) onConfirm;

  const BatchSelectionDialog({
    super.key,
    required this.practicalBatches,
    required this.clinicBatches,
    required this.onConfirm,
  });

  @override
  State<BatchSelectionDialog> createState() => _BatchSelectionDialogState();
}

class _BatchSelectionDialogState extends State<BatchSelectionDialog> {
  final Set<String> _selectedPracticals = {};
  final Set<String> _selectedClinics = {};

  @override
  void initState() {
    super.initState();
    // Default select all for both
    _selectedPracticals.addAll(widget.practicalBatches);
    _selectedClinics.addAll(widget.clinicBatches);
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      child: Container(
        width: 340, // Slightly wider content
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Select Your Batches",
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You may have different batches for Practicals and Clinics.",
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // --- Practical Section ---
              if (widget.practicalBatches.isNotEmpty) ...[
                _buildSectionHeader(context, "Practicals"),
                const SizedBox(height: 8),
                _buildChipGroup(
                    context, widget.practicalBatches, _selectedPracticals),
                const SizedBox(height: 24),
              ],

              // --- Clinics Section ---
              if (widget.clinicBatches.isNotEmpty) ...[
                _buildSectionHeader(context, "Clinics"),
                const SizedBox(height: 8),
                _buildChipGroup(
                    context, widget.clinicBatches, _selectedClinics),
                const SizedBox(height: 32),
              ],

              ElevatedButton(
                onPressed:
                    (_selectedPracticals.isEmpty && _selectedClinics.isEmpty)
                        ? null
                        : () {
                            widget.onConfirm(
                              _selectedPracticals.toList(),
                              _selectedClinics.toList(),
                            );
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text("Continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Icon(Icons.layers_outlined,
            size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChipGroup(
      BuildContext context, Set<String> options, Set<String> selectionSet) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start, // Align start looks better for sections
      children: options.map((batch) {
        final isSelected = selectionSet.contains(batch);
        return FilterChip(
          label: Text(batch),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                selectionSet.add(batch);
              } else {
                selectionSet.remove(batch);
              }
            });
          },
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.primary,
          labelStyle: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }
}
