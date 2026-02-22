import 'package:flutter/material.dart';

class NonClippingSizeTransition extends AnimatedWidget {
  /// Creates a [NonClippingSizeTransition].
  ///
  /// The [sizeFactor] and [axisAlignment] arguments must not be null.
  /// The [axis] argument defaults to [Axis.vertical].
  const NonClippingSizeTransition({
    super.key,
    this.axis = Axis.vertical,
    required Animation<double> sizeFactor,
    this.axisAlignment = 0.0,
    this.child,
  }) : super(listenable: sizeFactor);

  /// The axis along which to scale.
  final Axis axis;

  /// The animation that controls the (squared) size of the child.
  Animation<double> get sizeFactor => listenable as Animation<double>;

  /// Describes how to align the child along the axis that [sizeFactor] is
  /// modifying.
  final double axisAlignment;

  /// The widget below this widget in the tree.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final AlignmentDirectional alignment;
    if (axis == Axis.vertical) {
      alignment = AlignmentDirectional(-1.0, axisAlignment);
    } else {
      alignment = AlignmentDirectional(axisAlignment, -1.0);
    }
    return Align(
      alignment: alignment,
      heightFactor: axis == Axis.vertical ? sizeFactor.value : null,
      widthFactor: axis == Axis.horizontal ? sizeFactor.value : null,
      child: child,
    );
  }
}
