import 'package:async/async.dart';
import 'package:cancel_token/src/cancel_token.dart';
import 'package:cancel_token/src/cancelable.dart';
import 'package:cancel_token/src/cancelled_exception.dart';

/// Owns [CancelToken]s for a host lifetime (screen, session, scope).
///
/// Call [dispose] or [cancel] when the owner goes away so in-flight work aborts.
final class CancelableScope implements Cancelable {
  final Set<CancelToken> _tokens = {};
  final Set<CancelableOperation<dynamic>> _operations = {};
  var _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  /// Creates a token registered in this scope (cancelled by [cancel]/[dispose]).
  CancelToken createToken() {
    final token = CancelToken();
    if (_isCancelled) {
      token.cancel('scope disposed');
      return token;
    }
    _tokens.add(token);
    return token;
  }

  /// Runs [body] with a fresh [CancelToken]; cancels it when the scope cancels.
  ///
  /// Throws [CancelledException] when the operation is cancelled before it
  /// produces a value.
  Future<T> run<T>(Future<T> Function(CancelToken token) body) async {
    final token = createToken();
    final operation = CancelableOperation<T>.fromFuture(
      body(token),
      onCancel: () {
        if (!token.isCancelled) token.cancel();
      },
    );
    _operations.add(operation);
    try {
      final result = await operation.valueOrCancellation();
      if (operation.isCanceled) {
        throw CancelledException(token.reason);
      }
      return result as T;
    } finally {
      _operations.remove(operation);
      _tokens.remove(token);
    }
  }

  @override
  void cancel([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    final operations = List<CancelableOperation<dynamic>>.of(_operations);
    final tokens = List<CancelToken>.of(_tokens);
    _operations.clear();
    _tokens.clear();
    // Tokens first so dispose/cancel [reason] sticks before run's onCancel fires.
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
    for (final operation in operations) {
      if (!operation.isCanceled) {
        operation.cancel();
      }
    }
  }

  /// Cancels the scope. Defaults [reason] to `'disposed'` when omitted.
  void dispose([Object? reason]) => cancel(reason ?? 'disposed');
}
