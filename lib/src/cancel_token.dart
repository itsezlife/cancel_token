import 'dart:async';

import 'package:async/async.dart';
import 'package:cancel_token/src/cancelable.dart';
import 'package:cancel_token/src/cancelled_exception.dart';
import 'package:meta/meta.dart';

/// A cancel signal for in-flight work.
///
/// Pass the same instance into HTTP / fetch layers via [whenCancel], and use
/// [track] for [CancelableOperation]s that should die with this token.
///
/// Child tokens linked with [link] cancel together with this one. Call the
/// returned unlink callback when the child's work ends, or use [linkWhile] so
/// unlink happens when a [Future] completes.
final class CancelToken implements Cancelable {
  final Completer<void> _completer = Completer<void>();

  /// Active linked children only. Grows with live links, not total request count,
  /// because callers unlink (or [linkWhile] unlinks) when child work ends.
  Set<CancelToken>? _children;

  final List<CancelableOperation<dynamic>> _tracked = [];

  Object? _reason;

  @override
  bool get isCancelled => _completer.isCompleted;

  /// Completes when this token is cancelled.
  Future<void> get whenCancel => _completer.future;

  /// Reason from the first [cancel] call, if any.
  Object? get reason => _reason;

  /// Number of currently linked child tokens (tests / diagnostics).
  @visibleForTesting
  int get debugLinkedCount => _children?.length ?? 0;

  /// Number of tracked operations still retained (tests / diagnostics).
  @visibleForTesting
  int get debugTrackedCount => _tracked.length;

  /// Throws [CancelledException] if this token is already cancelled.
  void throwIfCancelled() {
    if (isCancelled) {
      throw CancelledException(_reason);
    }
  }

  @override
  void cancel([Object? reason]) {
    if (_completer.isCompleted) return;
    // Iterative walk — avoids stack overflow on deep link trees.
    final pending = <CancelToken>[this];
    while (pending.isNotEmpty) {
      final token = pending.removeLast();
      if (token._completer.isCompleted) continue;
      token._reason = reason;
      token._completer.complete();
      for (final operation in token._tracked) {
        if (!operation.isCanceled) {
          operation.cancel();
        }
      }
      token._tracked.clear();
      final children = token._children;
      token._children = null;
      if (children != null) pending.addAll(children);
    }
  }

  /// Links [child] so it cancels with this token. Returns an unlink callback.
  ///
  /// Without unlink (or [linkWhile]), the child stays in the parent's set for
  /// the parent's lifetime.
  void Function() link(CancelToken child) {
    if (isCancelled) {
      child.cancel(_reason);
      return () {};
    }
    (_children ??= <CancelToken>{}).add(child);
    return () => _children?.remove(child);
  }

  /// Links [child] until [future] completes (value or error), then unlinks.
  Future<T> linkWhile<T>(CancelToken child, Future<T> future) async {
    final unlink = link(child);
    try {
      return await future;
    } finally {
      unlink();
    }
  }

  /// Tracks [future] so [cancel] also aborts this operation.
  ///
  /// Completed or cancelled operations are dropped from the tracked set so a
  /// long-lived token does not retain every past future.
  CancelableOperation<T> track<T>(Future<T> future) {
    final operation = CancelableOperation<T>.fromFuture(future);
    if (isCancelled) {
      operation.cancel();
      return operation;
    }
    _tracked.add(operation);
    operation.valueOrCancellation().whenComplete(() {
      _tracked.remove(operation);
    });
    return operation;
  }
}
