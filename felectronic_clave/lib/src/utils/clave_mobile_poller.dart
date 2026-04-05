import 'dart:async';

import 'package:felectronic_clave/src/clave_repository.dart';
import 'package:felectronic_clave/src/errors/clave_error.dart';
import 'package:felectronic_clave/src/models/clave_auth_result.dart';
import 'package:felectronic_clave/src/models/clave_mobile_session.dart';

/// Stream-based polling for Cl@ve Movil validation.
///
/// Replaces manual polling loops with a clean stream API:
///
/// ```dart
/// final poller = ClaveMobilePoller(repository);
/// await for (final status in poller.poll(session: session)) {
///   if (status is ClavePollWaiting) {
///     print('Waiting... ${status.elapsedSeconds}s');
///   } else if (status is ClavePollSuccess) {
///     print('Authenticated: ${status.result.accessToken}');
///   } else if (status is ClavePollError) {
///     print('Failed: ${status.error.message}');
///   }
/// }
/// ```
class ClaveMobilePoller {
  /// Creates a poller backed by the given repository.
  ClaveMobilePoller(this._repository);

  final ClaveRepository _repository;
  bool _cancelled = false;

  /// Polls for Cl@ve Movil validation.
  ///
  /// Emits [ClavePollWaiting] while the user hasn't confirmed yet,
  /// [ClavePollSuccess] on successful authentication, or
  /// [ClavePollError] on terminal failure.
  ///
  /// The stream completes after success, error, or [timeout].
  Stream<ClavePollStatus> poll({
    required ClaveMobileSession session,
    Duration initialDelay = const Duration(seconds: 20),
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    _cancelled = false;
    final start = DateTime.now();

    // Initial wait before first poll
    await Future<void>.delayed(initialDelay);
    if (_cancelled) return;

    while (!_cancelled) {
      final elapsed = DateTime.now().difference(start);
      if (elapsed >= timeout) {
        yield const ClavePollError(ClaveSessionExpiredError());
        return;
      }

      try {
        final result = await _repository.validateNotificationCode(
          session: session,
        );
        yield ClavePollSuccess(result);
        return;
      } on ClaveIdleError {
        yield ClavePollWaiting(elapsed.inSeconds);
      } on ClaveError catch (e) {
        yield ClavePollError(e);
        return;
      }

      if (_cancelled) return;
      await Future<void>.delayed(interval);
    }
  }

  /// Cancels the polling loop.
  void cancel() => _cancelled = true;
}

/// Status emitted by [ClaveMobilePoller.poll].
sealed class ClavePollStatus {
  const ClavePollStatus();
}

/// The user hasn't confirmed yet — still polling.
class ClavePollWaiting extends ClavePollStatus {
  /// Creates a waiting status with [elapsedSeconds] since polling started.
  const ClavePollWaiting(this.elapsedSeconds);

  /// Seconds elapsed since polling started.
  final int elapsedSeconds;
}

/// Authentication succeeded.
class ClavePollSuccess extends ClavePollStatus {
  /// Creates a success status with the [result].
  const ClavePollSuccess(this.result);

  /// The authentication result.
  final ClaveAuthResult result;
}

/// A terminal error occurred.
class ClavePollError extends ClavePollStatus {
  /// Creates an error status with the [error].
  const ClavePollError(this.error);

  /// The error that caused polling to stop.
  final ClaveError error;
}
