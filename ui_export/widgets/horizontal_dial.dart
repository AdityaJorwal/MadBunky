import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HorizontalDial extends StatefulWidget {
  final int min;
  final int max;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final double itemWidth;

  const HorizontalDial({
    super.key,
    this.min = 0,
    required this.max,
    this.initialValue = 0,
    required this.onChanged,
    this.itemWidth = 30.0, // Explicit width for easier touch
  });

  @override
  State<HorizontalDial> createState() => _HorizontalDialState();
}

class _HorizontalDialState extends State<HorizontalDial> {
  late FixedExtentScrollController _controller;
  int _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = FixedExtentScrollController(
      initialItem: widget.initialValue - widget.min,
    );
  }

  @override
  void didUpdateWidget(HorizontalDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      if (_currentValue != widget.initialValue) {
        _currentValue = widget.initialValue;
        if (_controller.hasClients) {
          _controller.animateToItem(
            widget.initialValue - widget.min,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 60,
          child: RotatedBox(
            quarterTurns: -1, // Make horizontal
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemWidth,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.001, // Almost flat
              diameterRatio: 100, // Flat
              onSelectedItemChanged: (index) {
                final newValue =
                    (widget.min + index).clamp(widget.min, widget.max);
                if (newValue != _currentValue) {
                  HapticFeedback.selectionClick();
                  // We update logic value but wait to setState text if needed?
                  // setState triggers build which might lag? No, text is cheap.
                  setState(() => _currentValue = newValue);
                  widget.onChanged(newValue);
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: (widget.max - widget.min) + 1,
                builder: (context, index) {
                  final isSelected =
                      (widget.min + index) == _currentValue; // Highlight center
                  final isMajor = (widget.min + index) % 5 == 0;

                  return RotatedBox(
                    quarterTurns: 1, // Rotate back
                    child: Container(
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: isMajor ? 32 : 18,
                        width: isSelected || isMajor ? 3 : 2,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isMajor
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "$_currentValue",
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
