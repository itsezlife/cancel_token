import 'package:async/async.dart';
import 'package:cancelable/src/cancel_token.dart';
import 'package:cancelable/src/cancellable.dart';
import 'package:cancelable/src/cancellable_scope.dart';

/// Bridges [CancelableOperation] tracking and a transport-agnostic [CancelToken].
///
/// Pass [token] into the fetch / HTTP layer. Call [cancel] (or cancel via a
/// [CancellableScope]) to abort both transport work and tracked futures.
final class CancellableToken implements Cancellable {
  /// Creates a token, optionally wrapping an existing [CancelToken].
  CancellableToken([CancelToken? token]) : _token = token ?? CancelToken();

  final CancelToken _token;
  final List<CancelableOperation<dynamic>> _tracked = [];
  var _isCancelled = false;
  Object? _reason;

  /// Transport-agnostic cancel token for the fetch / HTTP layer.
  CancelToken get token => _token;

  /// Optional reason from the last [cancel] call.
  Object? get reason => _reason ?? _token.reason;

  @override
  bool get isCancelled => _isCancelled || _token.isCancelled;

  /// Tracks [future] so [cancel] also aborts this operation.
  CancelableOperation<T> track<T>(Future<T> future) {
    final operation = CancelableOperation<T>.fromFuture(future);
    _tracked.add(operation);
    if (isCancelled) {
      operation.cancel();
    }
    return operation;
  }

  @override
  void cancel([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason ?? 'cancelled';
    if (!_token.isCancelled) {
      _token.cancel(_reason);
    }
    for (final operation in _tracked) {
      if (!operation.isCanceled) {
        operation.cancel();
      }
    }
    _tracked.clear();
  }
}

/// Wraps [future] in a [CancelableOperation] (no HTTP token).
CancelableOperation<T> cancellableFromFuture<T>(Future<T> future) {
  return CancelableOperation<T>.fromFuture(future);
}
