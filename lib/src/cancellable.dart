/// Something that can be cooperatively cancelled.
abstract interface class Cancellable {
  /// Cancels this resource with an optional [reason].
  void cancel([Object? reason]);

  /// Whether [cancel] has already been called.
  bool get isCancelled;
}
