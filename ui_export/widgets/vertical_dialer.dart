import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerticalDialer extends StatefulWidget {
  final int min;
  final int max;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final double itemHeight;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle;

  const VerticalDialer({
    super.key,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    this.itemHeight = 40.0,
    this.textStyle,
    this.selectedTextStyle,
  });

  @override
  State<VerticalDialer> createState() => _VerticalDialerState();
}

class _VerticalDialerState extends State<VerticalDialer> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.initialValue - widget.min,
    );
  }

  @override
  void didUpdateWidget(VerticalDialer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      if (_controller.hasClients) {
        final targetItem = widget.initialValue - widget.min;
        if (_controller.selectedItem != targetItem) {
          _controller.animateToItem(
            targetItem,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
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
    return SizedBox(
      height: widget.itemHeight * 3, // Show 3 items (prev, current, next)
      width: 50,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: widget.itemHeight,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.005,
        diameterRatio: 1.2,
        onSelectedItemChanged: (index) {
          HapticFeedback.selectionClick();
          widget.onChanged(widget.min + index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.max - widget.min + 1,
          builder: (context, index) {
            final value = widget.min + index;
            // Removed unused isSelected variable to fix lint

            return Center(
              child: Text(
                value.toString().padLeft(2, '0'),
                style: widget.textStyle ??
                    const TextStyle(
                      fontSize: 20,
                      color: Colors.white54,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
