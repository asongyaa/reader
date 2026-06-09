import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StepSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(double) thumbLabel;
  final List<double>? tickLabels; // 特定位置显示数值标签
  final String? leftText; // 左端文字 "慢"
  final String? rightText; // 右端文字 "快"

  const StepSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.thumbLabel,
    this.tickLabels,
    this.leftText,
    this.rightText,
  });

  @override
  State<StepSlider> createState() => _StepSliderState();
}

class _StepSliderState extends State<StepSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(StepSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  double _snapToStep(double value) {
    final snapped = (value / widget.step).round() * widget.step;
    return snapped.clamp(widget.min, widget.max);
  }

  double _valueToPosition(double value, double trackWidth) {
    return (value - widget.min) / (widget.max - widget.min) * trackWidth;
  }

  double _positionToValue(double position, double trackWidth) {
    return widget.min + (position / trackWidth) * (widget.max - widget.min);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leftTextWidth = widget.leftText != null ? 28.0 : 0.0;
          final rightTextWidth = widget.rightText != null ? 28.0 : 0.0;
          final thumbRadius = 20.0;
          final trackWidth = constraints.maxWidth -
              leftTextWidth -
              rightTextWidth -
              thumbRadius;
          final trackStart = leftTextWidth + thumbRadius / 2;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final localX = details.localPosition.dx - trackStart;
              final rawValue = _positionToValue(localX, trackWidth);
              final snapped = _snapToStep(rawValue);
              if (snapped != _currentValue) {
                setState(() => _currentValue = snapped);
                widget.onChanged(snapped);
                HapticFeedback.selectionClick();
              }
            },
            onTapDown: (details) {
              final localX = details.localPosition.dx - trackStart;
              final rawValue = _positionToValue(localX, trackWidth);
              final snapped = _snapToStep(rawValue);
              if (snapped != _currentValue) {
                setState(() => _currentValue = snapped);
                widget.onChanged(snapped);
                HapticFeedback.selectionClick();
              }
            },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (widget.leftText != null)
                  Positioned(
                    left: 0,
                    child: Text(
                      widget.leftText!,
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (widget.rightText != null)
                  Positioned(
                    right: 0,
                    child: Text(
                      widget.rightText!,
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                // Tick marks
                Positioned(
                  left: trackStart,
                  child: CustomPaint(
                    size: Size(trackWidth, 56),
                    painter: _TickPainter(
                      min: widget.min,
                      max: widget.max,
                      step: widget.step,
                      tickColor: colorScheme.onSurface.withOpacity(0.15),
                    ),
                  ),
                ),
                // Tick value labels
                if (widget.tickLabels != null)
                  ...widget.tickLabels!.map((labelValue) {
                    final pos =
                        _valueToPosition(labelValue, trackWidth) + trackStart;
                    return Positioned(
                      left: pos - 16,
                      child: SizedBox(
                        width: 32,
                        child: Text(
                          labelValue == labelValue.toInt().toDouble()
                              ? '${labelValue.toInt()}.0'
                              : labelValue.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    );
                  }),
                // Thumb
                Positioned(
                  left: _valueToPosition(_currentValue, trackWidth) +
                      trackStart -
                      thumbRadius,
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.thumbLabel(_currentValue),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final double min, max, step;
  final Color tickColor;
  _TickPainter(
      {required this.min,
      required this.max,
      required this.step,
      required this.tickColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final steps = ((max - min) / step).round();
    final centerY = size.height / 2;
    for (int i = 0; i <= steps; i++) {
      final x = i / steps * size.width;
      canvas.drawLine(
          Offset(x, centerY - 5), Offset(x, centerY + 5), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      min != old.min ||
      max != old.max ||
      step != old.step ||
      tickColor != old.tickColor;
}
