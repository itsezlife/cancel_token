import 'package:cancelable/cancelable.dart' show CancellableScope;

/// Thrown when a [CancellableScope.run] / tracked future is cancelled.
final class CancellableCancelledException implements Exception {
  /// Creates a cancellation exception with an optional [reason].
  const CancellableCancelledException([this.reason]);

  /// Optional cancel reason (often a [String]).
  final Object? reason;

  @override
  String toString() => switch (reason) {
    null => 'CancellableCancelledException',
    final value => 'CancellableCancelledException: $value',
  };
}
