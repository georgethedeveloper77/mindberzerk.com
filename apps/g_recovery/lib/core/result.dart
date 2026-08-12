/// Every platform call returns one of these. The Kotlin side throws, the bridge
/// wrapper catches, and nothing above the bridge ever sees a raw exception.
sealed class GResult<T> {
  const GResult();

  bool get isOk => this is GOk<T>;

  T? get valueOrNull => switch (this) {
    GOk<T>(:final T value) => value,
    GErr<T>() => null,
  };

  R fold<R>({
    required R Function(T value) ok,
    required R Function(GErr<T> error) err,
  }) => switch (this) {
    GOk<T>(:final T value) => ok(value),
    final GErr<T> failure => err(failure),
  };
}

final class GOk<T> extends GResult<T> {
  const GOk(this.value);

  final T value;
}

final class GErr<T> extends GResult<T> {
  const GErr(this.message, {this.code, this.cause});

  /// Shown to the user. Plain language, no jargon, no ellipsis characters.
  final String message;

  /// Stable identifier for logs. Never shown to the user.
  final String? code;

  final Object? cause;
}
