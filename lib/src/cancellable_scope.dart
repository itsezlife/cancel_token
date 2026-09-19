import 'package:async/async.dart';
import 'package:cancelable/src/cancellable.dart';
import 'package:cancelable/src/cancellable_token.dart';
import 'package:cancelable/src/exceptions.dart';

/// Owns [CancellableToken]s / operations for a host lifetime.
///
/// Call [dispose] (or [cancelAll]) when the owner is disposed so in-flight
/// work and Futures are aborted.
final class CancellableScope implements Cancellable {
  final Set<Cancellable> _active = {};
  var _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  /// Creates a token registered in this scope (cancelled by [cancelAll]).
  CancellableToken createToken() {
    final token = CancellableToken();
    if (_isCancelled) {
      token.cancel('scope disposed');
      return token;
    }
    _active.add(token);
    return token;
  }

  /// Runs [body] with a fresh token; cancels the token and operation on
  /// [cancelAll].
  ///
  /// Throws [CancellableCancelledException] when the operation is cancelled
  /// before completion.
  Future<T> run<T>(Future<T> Function(CancellableToken token) body) async {
    final token = createToken();
    final operation = CancelableOperation<T>.fromFuture(
      body(token),
      onCancel: () => token.cancel('cancelled'),
    );
    final tracked = _TrackedOperation<T>(operation);
    _active.add(tracked);
    try {
      final result = await operation.valueOrCancellation();
      if (operation.isCanceled) {
        throw CancellableCancelledException(token.reason);
      }
      return result as T;
    } finally {
      _active
        ..remove(tracked)
        ..remove(token);
    }
  }

  @override
  void cancel([Object? reason]) => cancelAll(reason);

  /// Cancels every registered token / operation.
  void cancelAll([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    final snapshot = List<Cancellable>.of(_active);
    _active.clear();
    for (final cancellable in snapshot) {
      cancellable.cancel(reason ?? 'cancelled');
    }
  }

  /// Alias for [cancelAll] — use from controller [dispose].
  void dispose([Object? reason]) => cancelAll(reason ?? 'disposed');
}

final class _TrackedOperation<T> implements Cancellable {
  _TrackedOperation(this._operation);

  final CancelableOperation<T> _operation;

  @override
  bool get isCancelled => _operation.isCanceled;

  @override
  void cancel([Object? reason]) {
    if (!_operation.isCanceled) {
      _operation.cancel();
    }
  }
}
