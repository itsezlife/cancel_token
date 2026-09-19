import 'dart:async';

import 'package:cancelable/cancelable.dart';
import 'package:test/test.dart';

void main() {
  group('CancellableToken', () {
    test('cancel marks token cancelled', () {
      final token = CancellableToken();
      expect(token.isCancelled, isFalse);

      token.cancel('bye');

      expect(token.isCancelled, isTrue);
      expect(token.token.isCancelled, isTrue);
      expect(token.reason, 'bye');
    });

    test('cancel aborts tracked CancelableOperation', () async {
      final token = CancellableToken();
      final completer = Completer<int>();
      final operation = token.track(completer.future);

      token.cancel();

      expect(operation.isCanceled, isTrue);
      await expectLater(
        operation.valueOrCancellation(-1),
        completion(-1),
      );
    });
  });

  group('CancellableScope', () {
    test('run completes with body result', () async {
      final scope = CancellableScope();
      final value = await scope.run((token) async {
        expect(token.isCancelled, isFalse);
        return 42;
      });
      expect(value, 42);
    });

    test('dispose cancels in-flight run', () async {
      final scope = CancellableScope();
      final started = Completer<void>();
      final gate = Completer<int>();

      final future = scope.run((token) async {
        started.complete();
        return gate.future;
      });

      await started.future;
      scope.dispose();

      await expectLater(
        future,
        throwsA(isA<CancellableCancelledException>()),
      );
      expect(scope.isCancelled, isTrue);
    });

    test('cancelAll cancels token from createToken', () {
      final scope = CancellableScope();
      final token = scope.createToken();

      scope.cancelAll('stop');

      expect(token.isCancelled, isTrue);
      expect(token.token.isCancelled, isTrue);
    });
  });
}
