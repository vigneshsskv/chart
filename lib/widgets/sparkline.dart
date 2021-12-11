import 'package:chart/line/curves.dart';
import 'package:chart/utils/marker.dart';
import 'package:chart/utils/painting.dart';
import 'package:chart/utils/span.dart';
import 'package:chart/utils/utils.dart';
import 'package:chart/widgets/base.dart';
import 'package:chart/widgets/line_chart.dart';
import 'package:flutter/material.dart';

class _SparklinePoint {
  _SparklinePoint(this.value, this.index);

  final double value;
  final int index;

  static List<_SparklinePoint> createPoints(List<double> values) {
    return List.generate(values.length, (i) {
      return _SparklinePoint(values[i], i);
    });
  }
}

class Sparkline extends Line<_SparklinePoint, int, double?> {
  Sparkline({
    required List<double> data,
    PaintOptions stroke = const PaintOptions.stroke(
      color: Colors.black,
      strokeWidth: 2.0,
    ),
    PaintOptions? fill,
    MarkerOptions? marker,
    UnaryFunction<double, MarkerOptions>? markerFn,
    LineCurve curve = LineCurves.linear,
  }) : super(
          data: _SparklinePoint.createPoints(data),
          xFn: (point) => point.index,
          yFn: (point) => point.value,
          stroke: stroke,
          fill: fill,
          curve: curve,
          marker: marker,
          markerFn: (point) {
            if (markerFn == null) return null;
            return markerFn(point.value);
          },
          xAxis: ChartAxis<int>(
            span: IntSpan(0, data.length - 1),
            tickGenerator: const EmptyTickGenerator(),
            hideLine: true,
          ),
          yAxis: ChartAxis<double?>(
            spanFn: (values) {
              final sorted = values.where((numb) => numb != null).toList();
              sorted.sort();
              return DoubleSpan(sorted.first, sorted.last);
            },
            tickGenerator: const EmptyTickGenerator(),
            hideLine: true,
          ),
        );
}
