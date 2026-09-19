import 'package:test/test.dart';

import 'cancel_token/cancel_token_test.dart' as cancel_token_test;
import 'cancelable_scope/cancelable_scope_test.dart' as cancelable_scope_test;
import 'cancelled_exception/cancelled_exception_test.dart'
    as cancelled_exception_test;

/// Aggregate entrypoint for the unit suite.
void main() => group('Unit', () {
  cancel_token_test.main();
  cancelable_scope_test.main();
  cancelled_exception_test.main();
});
