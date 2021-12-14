import 'dart:collection';

import 'package:chart/chart_drawable.dart';
import 'package:chart/decor/decor.dart';
import 'package:chart/decor/legend.dart';
import 'package:chart/line/curves.dart';
import 'package:chart/line/drawable.dart';
import 'package:chart/utils/chart_position.dart';
import 'package:chart/utils/marker.dart';
import 'package:chart/utils/painting.dart';
import 'package:chart/utils/span.dart';
import 'package:chart/utils/utils.dart';
import 'package:chart/widgets/base.dart';
import 'package:chart/widgets/chart_view.dart';
import 'package:flutter/material.dart';

class Line<Datum, X, Y> {
  Line({
    required this.data,
    required this.xFn,
    required this.yFn,
    ChartAxis<X>? xAxis,
    ChartAxis<Y>? yAxis,
    this.stroke = const PaintOptions.stroke(color: Colors.black),
    this.fill,
    this.curve = LineCurves.monotone,
    this.marker = const MarkerOptions(),
    this.markerFn,
    this.legend,
  })  : xAxis = xAxis ?? ChartAxis<X>(),
        yAxis = yAxis ?? ChartAxis<Y>();

  List<Datum> data;

  UnaryFunction<Datum, X> xFn;

  UnaryFunction<Datum, Y> yFn;

  ChartAxis<X> xAxis;

  ChartAxis<Y> yAxis;

  PaintOptions stroke;

  PaintOptions? fill;

  LineCurve curve;

  MarkerOptions? marker;

  UnaryFunction<Datum, MarkerOptions?>? markerFn;

  LegendItem? legend;

  MarkerOptions? markerFor(Datum datum) => marker ?? markerFn!(datum);

  Iterable<X> get xs => data.map(xFn);

  Iterable<Y> get ys => data.map(yFn);

  LineChartDrawable generateChartData(List xValues, List yValues) {
    final xValuesCasted = xValues.map((dynamic x) => x as X).toList();
    final yValuesCasted = yValues.map((dynamic y) => y as Y).toList();

    final xSpan = xAxis.span ?? xAxis.spanFn(xValuesCasted);
    final ySpan = yAxis.span ?? yAxis.spanFn(yValuesCasted);

    return LineChartDrawable(
      points: _generatePoints(xSpan, ySpan),
      stroke: stroke,
      fill: fill,
      curve: curve,
    );
  }

  List<LinePointDrawable> _generatePoints(
    SpanBase<X> xSpan,
    SpanBase<Y> ySpan,
  ) {
    return List.generate(data.length, (j) {
      final datum = data[j];
      final X x = xFn(datum);
      final Y y = yFn(datum);

      final xPos = xSpan.toDouble(x);
      final yPos = y == null ? null : ySpan.toDouble(y);

      // todo: should this be able to be null
      final marker = markerFor(datum);

      return LinePointDrawable(
        x: xPos,
        y: yPos,
        paint: marker == null ? [] : marker.paintList,
        shape: marker == null ? MarkerShapes.circle : marker.shape,
        size: marker == null ? 4.0 : marker.size,
      );
    });
  }
}

class LineChart extends Chart {
  const LineChart({
    Key? key,
    required this.lines,
    this.vertical = false,
    this.chartPadding = const EdgeInsets.all(20.0),
    this.legendPosition = ChartPosition.top,
    this.legendLayout = LegendLayout.horizontal,
    this.legendOffset = Offset.zero,
    this.onTouch,
    this.onMove,
    this.onRelease,
    required this.toolTip,
  }) : super(key: key);

  final List<Line> lines;

  final bool vertical;

  final EdgeInsets chartPadding;

  final ChartPosition legendPosition;

  final LegendLayout legendLayout;

  final Offset legendOffset;

  final ChartTouchListener? onTouch;

  final ChartTouchListener? onMove;

  final ChartTouchCallback? onRelease;

  final ToolTipStyle toolTip;

  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    final vertical = widget.vertical;

    // TODO: Deal with axes
    final xAxes = LinkedHashSet<ChartAxis>();
    final yAxes = LinkedHashSet<ChartAxis>();

    final axisData = <ChartAxis, List<dynamic>>{};

    for (var line in lines) {
      xAxes.add(vertical ? line.yAxis : line.xAxis);
      yAxes.add(vertical ? line.xAxis : line.yAxis);

      final xs = line.xs;
      final ys = line.ys;

      axisData.putIfAbsent(line.xAxis, () => <dynamic>[]);
      axisData.putIfAbsent(line.yAxis, () => <dynamic>[]);
      axisData[line.xAxis]?.addAll(xs);
      axisData[line.yAxis]?.addAll(ys);
    }

    final axes = xAxes.toSet()..addAll(yAxes);

    final axesData = axes.map((axis) {
      var position =
          xAxes.contains(axis) ? ChartPosition.bottom : ChartPosition.left;

      if (axis.opposite) {
        position = position == ChartPosition.bottom
            ? ChartPosition.top
            : ChartPosition.right;
      }

      return axis.generateAxisData(position, axisData[axis]!);
    }).toList();

    final lineCharts = widget.lines.map((line) {
      final xValues = axisData[line.xAxis]!;
      final yValues = axisData[line.yAxis]!;

      return line.generateChartData(xValues, yValues);
    }).toList();

    final legendItems =
        widget.lines.where((line) => line.legend != null).map((line) {
      return line.legend!.toDrawable();
    });

    final legend = legendItems.isEmpty
        ? null
        : LegendDrawable(
            items: legendItems.toList(),
            position: widget.legendPosition,
            layout: widget.legendLayout,
            offset: widget.legendOffset,
          );

    return ChartView(
      charts: lineCharts,
      toolTip: widget.toolTip,
      decor: ChartDecor(
        axes: axesData,
        legend: legend,
      ),
      chartPadding: widget.chartPadding,
      rotation: widget.vertical ? ChartRotation.clockwise : ChartRotation.none,
      onMove: widget.onMove,
      onRelease: widget.onRelease,
      onTouch: widget.onTouch,
    );
  }
}
