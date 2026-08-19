import 'dart:io' show Platform;

import 'package:felectronic_certificates/src/apple_certificates.dart';
import 'package:felectronic_certificates/src/certificate_session.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter/material.dart';

/// Presents the installed certificates and lets the user choose one.
///
/// ## Why this exists in the plugin
///
/// Android has a system picker; iOS and macOS have none, and
/// `selectDefaultCertificate` there simply takes the first identity in the
/// app's keychain. With more than one imported that is a coin toss, and with
/// none it returns null — which is indistinguishable at the call site from a
/// user cancelling.
///
/// The parts to build a picker were already public (`getAllCertificates` and
/// `setDefaultCertificateBySerialNumber`), but every app would have written
/// the same list, the same empty state and the same "why is this empty?"
/// explanation. It belongs here once.
///
/// Returns the chosen certificate as a ready-to-use [CertificateSession], or
/// null if the user dismissed the sheet or there was nothing to choose from.
/// The choice is persisted as the default, so [CertificateSession.fromDefault]
/// finds it on the next launch.
Future<CertificateSession?> showCertificatePicker(
  BuildContext context, {
  String title = 'Choose a certificate',
}) async {
  final certificates = await FelectronicCertificatesPlatform.instance
      .getAllCertificates();
  if (!context.mounted) return null;

  final chosen = await showModalBottomSheet<DeviceCertificate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CertificateList(
      title: title,
      certificates: certificates,
    ),
  );
  if (chosen == null) return null;

  await FelectronicCertificatesPlatform.instance
      .setDefaultCertificateBySerialNumber(chosen.serialNumber);
  return CertificateSession.fromDefault();
}

class _CertificateList extends StatelessWidget {
  const _CertificateList({required this.title, required this.certificates});

  final String title;
  final List<DeviceCertificate> certificates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (certificates.isEmpty)
              _EmptyState(theme: theme)
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: certificates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final certificate = certificates[index];
                    return ListTile(
                      leading: Icon(
                        certificate.isExpired
                            ? Icons.gpp_bad
                            : Icons.verified_user,
                        // An expired certificate is still listed: it may be
                        // the one the user wants to inspect, and hiding it
                        // would look like the import failed.
                        color: certificate.isExpired
                            ? theme.colorScheme.error
                            : null,
                      ),
                      title: Text(certificate.displayName),
                      subtitle: Text(
                        '${certificate.issuerName}\n'
                        '${certificate.expiryStatus}',
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.of(context).pop(certificate),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // On Apple platforms the usual cause is a certificate installed as a
    // configuration profile, which an app cannot read. Saying so beats an
    // empty list, which reads as a failure.
    final explanation = Platform.isIOS || Platform.isMacOS
        ? AppleCertificates.emptyKeychainExplanation
        : 'No certificates are available on this device.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(explanation, style: theme.textTheme.bodyMedium),
    );
  }
}
