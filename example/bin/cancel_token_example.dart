import 'dart:async';

import 'package:cancel_token/cancel_token.dart';

/// Minimal repro: dispose a [CancelableScope] while work is still in flight.
///
/// Run:
///   cd example && dart pub get && dart run
Future<void> main() async {
  final scope = CancelableScope();

  final work = scope.run((token) async {
    print('fetch started');
    return fetchSomething(token);
  });

  // Simulate the host going away (screen dispose, session end, ...).
  await Future<void>.delayed(const Duration(milliseconds: 50));
  print('host disposed -> scope.dispose()');
  scope.dispose();

  try {
    final value = await work;
    print('unexpected success: $value');
  } on CancelledException catch (e) {
    print('cancelled as expected (reason: ${e.reason})');
  }
}

/// Stand-in for an HTTP / IO client that honors [CancelToken.whenCancel].
Future<String> fetchSomething(CancelToken token) async {
  final done = Completer<String>();

  final timer = Timer(const Duration(seconds: 2), () {
    if (!done.isCompleted) done.complete('ok');
  });

  unawaited(
    token.whenCancel.then((_) {
      timer.cancel();
      if (!done.isCompleted) {
        done.completeError(CancelledException(token.reason));
      }
    }),
  );

  return done.future;
}
