## 0.1.2

- **FIXED**: `CancelToken.track` no longer reports a failed underlying Future a
  second time as an unhandled zone error. Before, awaiting the returned
  operation delivered the error to the caller and the internal cleanup Future
  reported it again, tripping `runZonedGuarded` hosts. Now the failure is
  delivered exactly once: to the caller when awaited, or as a single unhandled
  error when the operation is never listened to.
- **FIXED**: An operation cancelled directly via `CancelableOperation.cancel`
  leaves the token's tracked set immediately instead of on a later microtask.

## 0.1.1

- **CHANGED**: Repository URLs to `itsezlife/cancel_token`.

## 0.1.0

- **ADDED**: Initial release.
