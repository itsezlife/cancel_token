import 'dart:async';

import 'package:cancelable/cancelable.dart';
import 'package:test/test.dart';

void main() {
  group('CancelableScope', () {
    test('run completes with the body result', () async {
      final scope = CancelableScope();
      final value = await scope.run((token) async {
        expect(token.isCancelled, isFalse);
        return 42;
      });
      expect(value, 42);
      expect(scope.isCancelled, isFalse);
    });

    test('run passes a CancelToken usable as the HTTP cancel signal', () async {
      final scope = CancelableScope();
      late CancelToken seen;
      await scope.run((token) async {
        seen = token;
        return null;
      });
      expect(seen, isA<CancelToken>());
    });

    test('dispose cancels an in-flight run', () async {
      final scope = CancelableScope();
      final started = Completer<void>();
      final gate = Completer<int>();

      final future = scope.run((token) async {
        started.complete();
        return gate.future;
      });

      await started.future;
      scope.dispose();

      await expectLater(future, throwsA(isA<CancelledException>()));
      expect(scope.isCancelled, isTrue);
    });

    test('cancel aborts tokens from createToken', () {
      final scope = CancelableScope();
      final token = scope.createToken();

      scope.cancel('stop');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'stop');
      expect(scope.isCancelled, isTrue);
    });

    test('dispose defaults reason to disposed', () {
      final scope = CancelableScope();
      final token = scope.createToken();

      scope.dispose();

      expect(token.reason, 'disposed');
    });

    test(
      'createToken on a disposed scope returns an already-cancelled token',
      () {
        final scope = CancelableScope();
        scope.dispose();

        final token = scope.createToken();

        expect(token.isCancelled, isTrue);
        expect(token.reason, 'scope disposed');
      },
    );

    test('cancel is idempotent', () {
      final scope = CancelableScope();
      final token = scope.createToken();
      scope.cancel('once');
      scope.cancel('twice');
      expect(token.reason, 'once');
    });

    test('successful run removes token from the active set', () async {
      final scope = CancelableScope();
      CancelToken? token;
      await scope.run((t) async {
        token = t;
        return 1;
      });

      scope.cancel('later');
      // Token left the scope on success; cancel after run must not hit it.
      expect(token!.isCancelled, isFalse);
    });
  });
}
