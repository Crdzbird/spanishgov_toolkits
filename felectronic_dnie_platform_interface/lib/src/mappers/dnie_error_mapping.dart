import 'package:felectronic_dnie_platform_interface/src/errors/dnie_error.dart';
import 'package:flutter/services.dart';

/// Turns the [PlatformException]s a native call fails with into [DnieError]s.
extension DnieErrorMapping<T> on Future<T> {
  /// This future, failing with a [DnieError] where it would have failed with
  /// a [PlatformException]. The original stack trace is kept.
  Future<T> mapDnieErrors() => onError<PlatformException>(
    (e, stack) =>
        Error.throwWithStackTrace(DnieError.fromPlatformException(e), stack),
  );
}
