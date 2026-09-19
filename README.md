# cancelable

Unified cancellation for Dart Futures (`CancelableOperation`) and a
transport-agnostic `CancelToken`.

## When to use

- Abort in-flight work when a host (screen, session, scope) is disposed
- Share one cancel signal across HTTP and tracked futures
- Nest per-request tokens under a parent that cancels children together

## API surface

| Type | Role |
|------|------|
| `CancelToken` | Completer-backed cancel signal; supports linked children |
| `CancellableToken` | Bridges `CancelToken` + tracked `CancelableOperation`s |
| `CancellableScope` | Owns tokens for a lifetime; `run` / `dispose` / `cancelAll` |
| `CancellableCancelledException` | Thrown when a scoped `run` is cancelled before completion |
| `Cancellable` | Interface implemented by tokens and scopes |

## Usage

```dart
final scope = CancellableScope();

final value = await scope.run((token) async {
  // Pass token.token into your HTTP / fetch layer.
  return fetchSomething(cancelToken: token.token);
});

// Later — abort everything still registered with the scope:
scope.dispose();
```

## Install

```yaml
dependencies:
  cancelable:
    git:
      url: https://github.com/itsezlife/cancelable.git
```

## License

MIT
