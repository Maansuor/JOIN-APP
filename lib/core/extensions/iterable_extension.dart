/// Extensiones útiles para elementos Iterable
extension IterableExtension<T> on Iterable<T> {
  /// Retorna el primer elemento que cumple la condición, o null si no encuentra
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
