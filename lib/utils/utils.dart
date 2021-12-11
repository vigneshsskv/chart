/// A generic typedef for a function that takes one type and returns another.
typedef UnaryFunction<E, F> = F Function(E argument);

List<double>? generateContinuousTicks(int count) {
  // TODO
  return null;
}

List<double> generateCategoricalTicks(int count) {
  final categoryWidth = 1 / count;
  return List.generate(count, (i) => i * categoryWidth + categoryWidth / 2);
}
