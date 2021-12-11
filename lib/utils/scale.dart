import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Common scales used for charts.
class Scales {
  /// Linear scale.
  static const LinearScale linear = LinearScale._();

  /// Natural log scale.
  static const LogScale log = LogScale(math.e);

  /// Log scale, base 2.
  static const LogScale log2 = LogScale(2.0);

  /// Log scale, base 10.
  static const LogScale log10 = LogScale(10.0);
}

/// Maps values to a visual encoding of the value.
@immutable
abstract class Scale {
  double apply(double value);

  double invert(double value);
}

/// A linear scale, the default. Use [Scales.linear].
@immutable
class LinearScale implements Scale {
  const LinearScale._();

  @override
  double apply(double value) => value;

  @override
  double invert(double value) => value;
}

/// A logarithmic scale with a provided base.
@immutable
class LogScale implements Scale {
  const LogScale(this.base);

  final double base;

  /// Applies log of base to the value.
  @override
  double apply(double value) => math.log(value) / math.log(base);

  /// Takes base to the power of value.
  @override
  double invert(double value) => math.pow(base, value).toDouble();
}
