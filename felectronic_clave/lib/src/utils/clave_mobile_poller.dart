import 'dart:async';

import 'package:felectronic_clave/src/clave_repository.dart';
import 'package:felectronic_clave/src/errors/clave_error.dart';
import 'package:felectronic_clave/src/models/clave_auth_result.dart';
import 'package:felectronic_clave/src/models/clave_mobile_session.dart';

/// {@template clave_mobile_poller}
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
/// {@endtemplate}
class ClaveMobilePoller {
  /// Creates a poller backed by the given repository.
  ClaveMobilePoller(this._repository);

  final ClaveRepository _repository;

  /// One flag per in-flight [poll]. An earlier revision kept a single flag and
  /// reset it at the top of [poll], so starting a second poll silently
  /// un-cancelled the first and [cancel] could not stop either reliably.
  final Set<_PollToken> _active = {};

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
    final token = _PollToken();
    _active.add(token);
    try {
      final start = DateTime.now();

      // Initial wait before the first poll: the user has to reach for their
      // phone and approve, so an immediate request is always idle.
      await Future<void>.delayed(initialDelay);
      if (token.cancelled) return;

      while (!token.cancelled) {
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
          if (token.cancelled) return;
          yield ClavePollError(e);
          return;
        }

        if (token.cancelled) return;
        await Future<void>.delayed(interval);
      }
    } finally {
      _active.remove(token);
    }
  }

  /// Cancels every poll started by this poller.
  ///
  /// The poll timeout is only checked between requests, so a poll can outlive
  /// it by at most one request. `ClaveHttpClient` bounds that.
  void cancel() {
    for (final token in _active) {
      token.cancelled = true;
    }
  }
}

/// Cancellation flag scoped to a single [ClaveMobilePoller.poll] call.
class _PollToken {
  bool cancelled = false;
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
