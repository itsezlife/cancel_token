/// Thrown when scoped work is cancelled before it produces a value.
final class CancelledException implements Exception {
  /// Creates a cancellation exception with an optional [reason].
  const CancelledException([this.reason]);

  /// Optional cancel reason.
  final Object? reason;

  @override
  String toString() => switch (reason) {
    null => 'CancelledException',
    final value => 'CancelledException: $value',
  };
}
