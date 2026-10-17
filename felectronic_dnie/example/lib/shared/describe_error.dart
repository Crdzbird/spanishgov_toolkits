import 'package:felectronic_certificates/felectronic_certificates.dart'
    as certs;
import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';

/// Turns anything an action threw into a status worth reading.
DemoStatus describeError(Object error) => switch (error) {
  DnieWrongPinError(:final remainingRetries, :final isLastAttempt) =>
    DemoStatus.error(
      'Wrong PIN',
      [
        if (remainingRetries != null) '$remainingRetries tries left.',
        if (isLastAttempt) 'One more wrong PIN locks the card.',
      ].join(' '),
    ),
  DnieError(:final message, :final isRetryable) => DemoStatus.error(
    message,
    isRetryable ? 'Hold the card still against the phone and try again.' : '',
  ),
  certs.CertificateError(:final message) => DemoStatus.error(message),
  ClaveError(:final message) => DemoStatus.error(
    error.runtimeType.toString(),
    message,
  ),
  _ => DemoStatus.error('Unexpected error', '$error'),
};
