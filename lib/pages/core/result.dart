import 'package:admin_app/pages/core/app_failure.dart';

sealed class Result<T> {
  const Result();
  R fold<R>(R Function(T data) onOk, R Function(AppFailure err) onErr);
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
  T? get dataOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  AppFailure? get errorOrNull => this is Err<T> ? (this as Err<T>).error : null;
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
  @override
  R fold<R>(R Function(T data) onOk, R Function(AppFailure err) onErr) =>
      onOk(value);
}

class Err<T> extends Result<T> {
  final AppFailure error;
  const Err(this.error);
  @override
  R fold<R>(R Function(T data) onOk, R Function(AppFailure err) onErr) =>
      onErr(error);
}
