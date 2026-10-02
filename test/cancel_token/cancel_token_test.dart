import 'dart:async';

import 'package:cancel_token/cancel_token.dart';
import 'package:test/test.dart';

void main() {
  group('CancelToken', () {
    test('cancel marks token cancelled and completes whenCancel', () async {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
      expect(token.reason, isNull);

      final whenCancel = token.whenCancel;
      token.cancel('bye');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'bye');
      await whenCancel;
    });

    test('cancel without reason leaves reason null', () {
      final token = CancelToken();
      token.cancel();
      expect(token.reason, isNull);
    });

    test('cancel is idempotent and keeps the first reason', () {
      final token = CancelToken();
      token.cancel('first');
      token.cancel('second');
      expect(token.reason, 'first');
    });

    test('throwIfCancelled is a no-op when active', () {
      final token = CancelToken();
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('throwIfCancelled throws CancelledException when cancelled', () {
      final token = CancelToken();
      token.cancel('stop');
      expect(
        token.throwIfCancelled,
        throwsA(
          isA<CancelledException>().having((e) => e.reason, 'reason', 'stop'),
        ),
      );
    });

    test('link cancels child when parent cancels', () {
      final parent = CancelToken();
      final child = CancelToken();
      parent.link(child);

      parent.cancel('parent');

      expect(child.isCancelled, isTrue);
      expect(child.reason, 'parent');
      expect(parent.debugLinkedCount, 0);
    });

    test('link on already-cancelled parent cancels child immediately', () {
      final parent = CancelToken();
      parent.cancel('gone');
      final child = CancelToken();

      final unlink = parent.link(child);

      expect(child.isCancelled, isTrue);
      expect(child.reason, 'gone');
      unlink();
    });

    test('unlink stops parent from cancelling child', () {
      final parent = CancelToken();
      final child = CancelToken();
      final unlink = parent.link(child);
      unlink();

      parent.cancel();

      expect(child.isCancelled, isFalse);
      expect(parent.debugLinkedCount, 0);
    });

    test('linkWhile unlinks child after future completes', () async {
      final parent = CancelToken();
      final child = CancelToken();

      await parent.linkWhile(child, Future.value(1));

      expect(parent.debugLinkedCount, 0);
      parent.cancel();
      expect(child.isCancelled, isFalse);
    });

    test('linkWhile still unlinks when future throws', () async {
      final parent = CancelToken();
      final child = CancelToken();

      await expectLater(
        parent.linkWhile(child, Future<int>.error(StateError('boom'))),
        throwsA(isA<StateError>()),
      );

      expect(parent.debugLinkedCount, 0);
    });

    test('cancel walks linked children transitively', () {
      final root = CancelToken();
      final mid = CancelToken();
      final leaf = CancelToken();
      root.link(mid);
      mid.link(leaf);

      root.cancel('tree');

      expect(mid.isCancelled, isTrue);
      expect(leaf.isCancelled, isTrue);
      expect(leaf.reason, 'tree');
    });

    test('track cancels the operation when token cancels', () async {
      final token = CancelToken();
      final completer = Completer<int>();
      final operation = token.track(completer.future);

      token.cancel();

      expect(operation.isCanceled, isTrue);
      expect(token.debugTrackedCount, 0);
      await expectLater(operation.valueOrCancellation(-1), completion(-1));
    });

    test('track on cancelled token cancels immediately', () async {
      final token = CancelToken();
      token.cancel();
      final completer = Completer<int>();

      final operation = token.track(completer.future);

      expect(operation.isCanceled, isTrue);
      expect(token.debugTrackedCount, 0);
    });

    test('completed track is dropped so it does not retain forever', () async {
      final token = CancelToken();
      final operation = token.track(Future.value(7));
      expect(await operation.value, 7);
      expect(token.debugTrackedCount, 0);
    });

    test('awaited failed track reports its error only to the caller', () async {
      final token = CancelToken();
      final zoneErrors = <Object>[];
      Object? caught;

      // Assertions stay outside the guarded zone: a failure inside it would be
      // routed to the zone handler and hang the test instead of failing it.
      await runZonedGuarded(() async {
        try {
          await token.track(Future<int>.error(StateError('boom'))).value;
        } on StateError catch (error) {
          caught = error;
        }
        // Flush so a leaked cleanup error would surface before we assert.
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => zoneErrors.add(error));

      expect(caught, isA<StateError>());
      expect(zoneErrors, isEmpty);
      expect(token.debugTrackedCount, 0);
    });

    test('unawaited failed track still reports exactly one zone error',
        () async {
      final token = CancelToken();
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        token.track(Future<int>.error(StateError('boom')));
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => zoneErrors.add(error));

      expect(zoneErrors, [isA<StateError>()]);
      expect(token.debugTrackedCount, 0);
    });

    test('track cancelled by the caller is dropped from the tracked set', () {
      final token = CancelToken();
      final operation = token.track(Completer<int>().future);
      expect(token.debugTrackedCount, 1);

      operation.cancel();

      expect(token.debugTrackedCount, 0);
    });
  });
}
