import 'package:chart/decor/tick.dart';
import 'package:chart/utils/chart_position.dart';
import 'package:chart/utils/merge_tween.dart';
import 'package:chart/utils/painting.dart';
import 'package:flutter/material.dart';

/// An axis of a chart.
@immutable
class ChartAxisDrawable implements MergeTweenable<ChartAxisDrawable> {
  const ChartAxisDrawable({
    required this.position,
    this.ticks = const [],
    this.paint = const PaintOptions.stroke(),
    this.size,
    this.offset = 0.0,
  });

  /// All the ticks which will be drawn along this axis.
  final List<AxisTickDrawable> ticks;

  /// The position of the axis - which side it will be placed.
  final ChartPosition position;

  /// The paint options for this axis' line.
  final PaintOptions? paint;

  final double? size;

  final double offset;

  void draw(CanvasArea fullArea, CanvasArea chartArea) {
    late Rect axisRect;

    final paddingTop = chartArea.rect.top - fullArea.rect.top;
    final paddingLeft = chartArea.rect.left - fullArea.rect.left;
    final paddingRight = fullArea.rect.right - chartArea.rect.right;
    final paddingBottom = fullArea.rect.bottom - chartArea.rect.bottom;

    var vertical = false;

    Offset? lineStart;
    Offset? lineEnd;

    switch (position) {
      case ChartPosition.top:
        axisRect = Offset(paddingLeft, offset) &
            Size(chartArea.width, size ?? paddingTop);
        lineStart = axisRect.bottomLeft;
        lineEnd = axisRect.bottomRight;
        break;
      case ChartPosition.left:
        vertical = true;
        axisRect = Offset(offset, paddingTop) &
            Size(size ?? paddingLeft, chartArea.height);
        lineStart = axisRect.bottomRight;
        lineEnd = axisRect.topRight;
        break;
      case ChartPosition.right:
        vertical = true;
        axisRect = chartArea.rect.topRight.translate(offset, 0.0) &
            Size(size ?? paddingRight, chartArea.height);
        lineStart = axisRect.bottomLeft;
        lineEnd = axisRect.topLeft;
        break;
      case ChartPosition.bottom:
        axisRect = chartArea.rect.bottomLeft.translate(0.0, offset) &
            Size(chartArea.width, size ?? paddingBottom);
        lineStart = axisRect.topLeft;
        lineEnd = axisRect.topRight;
        break;
      default:
        break;
    }

    if (paint != null) fullArea.drawLine(lineStart, lineEnd, paint);

    CanvasArea axisArea = fullArea.child(axisRect);

    final primary = vertical ? axisArea.height : axisArea.width;
    final secondary = vertical ? axisArea.width : axisArea.height;

    for (var tick in ticks) {
      final tickCenter = vertical ? (1 - tick.value!) : tick.value!;
      final tickPosition = (tickCenter - tick.width! / 2) * primary;
      final tickAreaSize = tick.width! * primary;

      Rect tickRect;

      if (vertical) {
        tickRect = Rect.fromLTWH(0.0, tickPosition, secondary, tickAreaSize);
      } else {
        tickRect = Rect.fromLTWH(tickPosition, 0.0, tickAreaSize, secondary);
      }

      tick.draw(axisArea.child(tickRect), position);
    }
  }

  @override
  ChartAxisDrawable get empty => ChartAxisDrawable(
        position: position,
        ticks: ticks.map((tick) => tick.empty).toList(),
        paint: paint,
        size: size,
        offset: offset,
      );

  @override
  Tween<ChartAxisDrawable> tweenTo(ChartAxisDrawable other) =>
      _ChartAxisDrawableTween(this, other);
}

/// Lerp between two [ChartAxisDrawable]'s.
class _ChartAxisDrawableTween extends Tween<ChartAxisDrawable> {
  _ChartAxisDrawableTween(ChartAxisDrawable begin, ChartAxisDrawable end)
      : _ticksTween = MergeTween(begin.ticks, end.ticks),
        super(begin: begin, end: end);

  final MergeTween<AxisTickDrawable> _ticksTween;

  @override
  ChartAxisDrawable lerp(double t) {
    return ChartAxisDrawable(
      position: t < 0.5 ? begin!.position : end!.position,
      ticks: _ticksTween.lerp(t),
      paint: PaintOptions.lerp(begin!.paint, end!.paint, t),
      size: t < 0.5 ? begin!.size : end!.size,
      offset: t < 0.5 ? begin!.offset : end!.offset,
    );
  }
}
