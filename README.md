# cancel_token

[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![pub package](https://img.shields.io/pub/v/cancel_token.svg)](https://pub.dev/packages/cancel_token)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Cancel Dart Futures and share a `CancelToken` across requests.

## When to use

- Abort in-flight work when a host (screen, session, scope) is disposed
- Share one cancel signal across HTTP and tracked futures
- Nest per-request tokens under a parent that cancels children together

## API

| Type | Role |
|------|------|
| `CancelToken` | Cancel signal; `whenCancel`, `track`, child `link` / `linkWhile` |
| `CancelableScope` | Owns tokens for a lifetime; `run` / `dispose` / `cancel` |
| `CancelledException` | Thrown when a scoped `run` is cancelled before completion |
| `Cancelable` | Interface implemented by tokens and scopes |

## Usage

```dart
final scope = CancelableScope();

final value = await scope.run((token) async {
  // Pass token into your HTTP / fetch layer (await token.whenCancel, etc.).
  return fetchSomething(cancelToken: token);
});

// Later — abort everything still registered with the scope:
scope.dispose();
```

Runnable console demo:

```sh
cd example && dart pub get && dart run
```

See [`example/bin/cancel_token_example.dart`](example/bin/cancel_token_example.dart).

## Install

```yaml
dependencies:
  cancel_token: ^0.1.1
```

## Coverage

[![](https://codecov.io/gh/itsezlife/cancel_token/branch/main/graphs/sunburst.svg)](https://codecov.io/gh/itsezlife/cancel_token/branch/main)

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Maintainers

- [Emil Zulufov](https://github.com/itsezlife)

## License

MIT. See [LICENSE](LICENSE).

Copyright (c) 2026 Emil Zulufov <emilzulufov566@gmail.com>
