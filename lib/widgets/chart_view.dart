import 'dart:math';

import 'package:chart/chart_drawable.dart';
import 'package:chart/decor/decor.dart';
import 'package:chart/utils/painting.dart';
import 'package:flutter/material.dart';

/// Used as a callback for touch/move pointer events. For each touch/move/release, a unique
/// [pointer] id is generated. The [data] parameter maps the chart index to the chart touch
/// data that the chart resolved to.
typedef ChartTouchListener = void Function(
    int pointer, Map<int, ChartTouch> data);

/// Used as a callback for pointer release events. The [pointer] is the same unique id
/// used in the [ChartTouchListener] callback.
typedef ChartTouchCallback = void Function(int pointer);

typedef IndicatorToolbar = Widget Function(Map<int, ChartTouch> data);

/// The rotation of a chart.
@immutable
class ChartRotation {
  /// rotated 0 degrees
  static const none = ChartRotation._(0.0);

  /// rotated 180 degrees
  static const upsideDown = ChartRotation._(pi);

  /// rotated 90 degrees clockwise
  static const clockwise = ChartRotation._(pi / 2);

  /// rotated 90 degrees counter clockwise (270 clockwise)
  static const counterClockwise = ChartRotation._(-pi / 2);

  const ChartRotation._(this.theta);

  /// The rotation in radians.
  final double theta;
}

@immutable
class ToolTipStyle {
  final bool hide;
  final PaintOptions? toolTipLineStyle;
  final IndicatorToolbar? toolbar;

  const ToolTipStyle({
    this.hide = true,
    this.toolTipLineStyle,
    this.toolbar,
  });
}

/// A widget for displaying raw charts.
class ChartView extends StatefulWidget {
  const ChartView({
    Key? key,
    required this.charts,
    this.decor,
    this.rotation = ChartRotation.none,
    this.chartPadding = const EdgeInsets.all(0.0),
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.fastOutSlowIn,
    this.onTouch,
    this.onMove,
    this.onRelease,
    this.toolTip,
    this.indicator,
  }) : super(key: key);

  /// The charts to draw within the view. The order of the list is the
  /// order that they are drawn (later means they are on top).
  final List<ChartDrawable> charts;

  /// The chart decoration to use.
  final ChartDecor? decor;

  /// The rotation of the chart.
  final ChartRotation rotation;

  /// The padding for the chart which gives room for the [decor]
  /// around the chart.
  final EdgeInsets chartPadding;

  /// The time it takes to animate from one chart to another. Set to null
  /// or [Duration.zero] to disable animation.
  final Duration animationDuration;

  /// The animation curve.
  final Curve animationCurve;

  final ChartTouchListener? onTouch;

  final ChartTouchListener? onMove;

  final ChartTouchCallback? onRelease;

  final ToolTipStyle? toolTip;

  final void Function(Offset position, Map<int, ChartTouch>? data)? indicator;

  @override
  _ChartViewState createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> with TickerProviderStateMixin {
  final GlobalKey _paintKey = GlobalKey();

  AnimationController? _controller;
  late Animation<double> _curve;
  _ChartPainter? _painter;
  Offset? showLine;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  _ChartPainter _createPainter() {
    final charts = widget.charts;
    final decor = widget.decor == null ? ChartDecor.none : widget.decor!;
    final rotation = widget.rotation;
    final chartPadding = widget.chartPadding;

    // animate from these
    ChartDecor fromDecor;
    List<ChartDrawable> fromCharts;

    if (_painter == null) {
      fromDecor = ChartDecor.none;
      fromCharts = widget.charts.map((c) => c.empty as ChartDrawable).toList();
    } else {
      fromDecor = _painter!.decor.value;
      fromCharts = _painter!.charts.map((c) => c.value).toList();
    }

    // to these
    final toDecor = fromDecor.tweenTo(decor).animate(_curve);
    final toCharts = <Animation<ChartDrawable>>[];

    for (var i = 0; i < charts.length; i++) {
      final drawable = charts[i];

      // find a chart which be tween to the chart
      final matches =
          fromCharts.where((c) => c.runtimeType == drawable.runtimeType);

      ChartDrawable prevDrawable;

      if (matches.isEmpty) {
        // if there is no match, animate from empty
        prevDrawable = drawable.empty as ChartDrawable;
      } else {
        // otherwise we take the first match and remove it from the list,
        // to prevent other charts in the list from tweening from it
        prevDrawable = matches.first;
        fromCharts.remove(prevDrawable);
      }

      final tween = prevDrawable.tweenTo(drawable);
      toCharts.add(tween.animate(_curve) as Animation<ChartDrawable>);
    }

    return _ChartPainter(
      charts: toCharts,
      decor: toDecor,
      rotation: rotation,
      chartPadding: chartPadding,
      repaint: _controller,
      showLine: showLine,
      toolTipLineStyle: widget.toolTip?.toolTipLineStyle,
    );
  }

  void updateIndicatorLine(Offset? offset) {
    var visible = widget.toolTip?.hide ?? true;
    if (!visible) {
      showLine = offset;
      _updatePainter();
    }
  }

  void _updatePainter() {
    var duration = widget.animationDuration;
    if (duration.inMilliseconds == 0) {
      duration = const Duration(milliseconds: 1);
    }

    _controller?.dispose();

    _controller = AnimationController(vsync: this, duration: duration);
    _curve = CurvedAnimation(
      parent: _controller!,
      curve: widget.animationCurve,
    );

    _ChartPainter painter = _createPainter();
    setState(() {
      _painter = painter;
    });

    _controller?.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(ChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePainter();
  }

  @override
  void initState() {
    super.initState();
    _updatePainter();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        RenderBox box =
            _paintKey.currentContext!.findRenderObject() as RenderBox;
        Offset offset = box.globalToLocal(event.position);
        final events = _painter?.resolveTouch(offset, box.size);
        if (events != null) {
          updateIndicatorLine(offset);
        } else {
          updateIndicatorLine(null);
        }
        if (widget.indicator != null) {
          widget.indicator!(offset, events);
        }
        if (events == null) return;
        if (widget.onTouch != null) {
          widget.onTouch!(event.pointer, events);
        }
      },
      onPointerMove: (event) {
        RenderBox box =
            _paintKey.currentContext?.findRenderObject() as RenderBox;
        Offset offset = box.globalToLocal(event.position);
        final events = _painter!.resolveTouch(offset, box.size);
        if (events != null) {
          updateIndicatorLine(offset);
        } else {
          updateIndicatorLine(null);
        }
        if (widget.indicator != null) {
          widget.indicator!(offset, events);
        }
        if (events == null) return;
        if (widget.onMove != null) {
          widget.onMove!(event.pointer, events);
        }
      },
      onPointerUp: (event) {
        updateIndicatorLine(null);
        if (widget.indicator != null) {
          widget.indicator!(Offset.zero, null);
        }
        if (widget.onRelease != null) {
          widget.onRelease!(event.pointer);
        }
      },
      child: CustomPaint(
        key: _paintKey,
        painter: _painter,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 10.0,
            minHeight: 10.0,
          ),
        ),
      ),
    );
  }
}

/// Paints animated [ChartDrawable] and [ChartDecor].
class _ChartPainter extends CustomPainter {
  final List<Animation<ChartDrawable>> charts;
  final Animation<ChartDecor> decor;
  final ChartRotation rotation;
  final EdgeInsets chartPadding;
  final Offset? showLine;
  final PaintOptions? toolTipLineStyle;

  Size? _size;

  _ChartPainter({
    required this.charts,
    required this.decor,
    required this.rotation,
    required this.chartPadding,
    required Listenable? repaint,
    required this.showLine,
    required this.toolTipLineStyle,
  }) : super(repaint: repaint);

  Map<int, ChartTouch>? resolveTouch(Offset touch, Size boxSize) {
    final size = _size ?? boxSize;
    final touchChart = touch.translate(-chartPadding.left, -chartPadding.top);

    final width = size.width - chartPadding.left - chartPadding.right;
    final height = size.height - chartPadding.top - chartPadding.bottom;

    if (touchChart.dx < 0 || touchChart.dy < 0) return null;
    if (touchChart.dx > width || touchChart.dy > height) return null;

    final events = <int, ChartTouch>{};

    for (var i = 0; i < charts.length; i++) {
      final chart = charts[i];

      final event = chart.value.resolveTouch(Size(width, height), touchChart);
      events[i] = event;
    }

    return events;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;

    // it is important to definitively not draw outside the canvas so we clip
    //  to the size of the canvas. subsequent drawings can be clipped further
    // (i.e. the chart should stay within its bounds, not reach outside the
    // canvas
    canvas.clipRect(Offset.zero & size);
    canvas.save();

    var canvasArea = CanvasArea.fromCanvas(canvas, size);
    var chartArea = canvasArea.contract(chartPadding);

    decor.value.draw(canvasArea, chartArea);

    late Size rotatedCanvasSize;

    // rotate and translate canvas as necessary based on rotation
    canvas.rotate(rotation.theta);
    switch (rotation) {
      case ChartRotation.none:
        rotatedCanvasSize = size;
        break;
      case ChartRotation.upsideDown:
        rotatedCanvasSize = size;
        canvas.translate(-rotatedCanvasSize.width, -rotatedCanvasSize.height);
        break;
      case ChartRotation.clockwise:
        rotatedCanvasSize = size.flipped;
        canvas.translate(0.0, -rotatedCanvasSize.height);
        break;
      case ChartRotation.counterClockwise:
        rotatedCanvasSize = size.flipped;
        canvas.translate(-rotatedCanvasSize.width, 0.0);
        break;
    }

    var rotatedCanvasArea = CanvasArea.fromCanvas(canvas, rotatedCanvasSize);
    var rotatedChartArea = rotatedCanvasArea.contract(chartPadding);

    for (final animation in charts) {
      final chart = animation.value;
      chart.draw(rotatedChartArea);
    }

    if (showLine != null) {
      canvas.drawLine(
        Offset(showLine?.dx ?? 0, 25),
        Offset(showLine?.dx ?? 0, size.height - 25),
        Paint()
          ..color = toolTipLineStyle?.color ?? Colors.black
          ..strokeWidth = toolTipLineStyle?.strokeWidth ?? 2
          ..style = toolTipLineStyle?.style ?? PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // restore to before clip (see start of method)
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
