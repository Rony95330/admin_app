import 'dart:async';
import 'app_failure.dart';
import 'result.dart';

Future<Result<T>> guard<T>(Future<T> Function() run) async {
  try {
    final data = await run();
    return Ok<T>(data);
  } catch (e, st) {
    return Err<T>(mapToFailure(e, st));
  }
}

Future<Result<T>> guardWithRetry<T>(
  Future<T> Function() run, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
}) async {
  var attempt = 0;
  var delay = initialDelay;

  while (true) {
    attempt++;
    final r = await guard(run);
    if (r is Ok<T>) return r;

    final err = (r as Err<T>).error;
    final transient = switch (err) {
      NetworkFailure() || TimeoutFailure() || RateLimitFailure() => true,
      ServerFailure() => true,
      DatabaseFailure(:final code)
          when code.contains('40001') || code.contains('55P03') =>
        true,
      _ => false,
    };

    if (!transient || attempt >= maxAttempts) return r;
    await Future.delayed(delay);
    delay *= 2;
  }
}
