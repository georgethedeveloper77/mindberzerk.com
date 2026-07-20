/// A value, or a reason it isn't one.
///
/// Exceptions are for bugs. Expected failures - no network, permission denied,
/// server unreachable - are values, and the type system should force you to
/// handle them.
sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };

  T? get valueOrNull => switch (this) { Ok<T>(:final value) => value, _ => null };
  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Every failure the app can show a human.
class Failure {
  const Failure(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'Failure($message)';
}
