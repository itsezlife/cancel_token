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
      // Snapshot then clear: each operation's onCancel untracks itself
      // synchronously, which would mutate the list mid-iteration.
      final tracked = List.of(token._tracked);
      token._tracked.clear();
      for (final operation in tracked) {
        if (!operation.isCanceled) {
          operation.cancel();
        }
      }
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
  /// The operation leaves the tracked set when [future] completes (value or
  /// error) or when the operation is cancelled — by this token or directly by
  /// the caller — so a long-lived token does not retain every past future.
  ///
  /// A failure of [future] is delivered exactly once, through the returned
  /// operation's [CancelableOperation.value]: to the caller when awaited, or as
  /// one unhandled error in the current zone when nobody listens. Tracking adds
  /// no error report of its own. Once cancelled, a later failure of [future]
  /// is discarded, as with any [CancelableOperation].
  CancelableOperation<T> track<T>(Future<T> future) {
    late final CancelableOperation<T> operation;
    void untrack() => _tracked.remove(operation);
    operation = CancelableOperation<T>.fromFuture(future, onCancel: untrack);
    if (isCancelled) {
      operation.cancel();
      return operation;
    }
    _tracked.add(operation);
    // Cleanup listens to the source, not to the operation: a listener on
    // `operation.value` would mark its error handled for fire-and-forget
    // callers, and the derived cleanup Future would carry the same error as a
    // second unhandled report. The source's error is already delivered through
    // `operation.value`, so the cleanup chain's own outcome is ignored.
    future.whenComplete(untrack).ignore();
    return operation;
  }
}
