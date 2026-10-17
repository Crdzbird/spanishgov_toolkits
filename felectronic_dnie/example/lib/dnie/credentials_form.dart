import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter/material.dart';

/// The certificate choice and the CAN and PIN every card action needs.
final class CredentialsForm extends StatelessWidget {
  const factory CredentialsForm({
    required TextEditingController can,
    required TextEditingController pin,
    required DnieCertificateType certificate,
    required ValueChanged<DnieCertificateType> onCertificateChanged,
    Key? key,
  }) = CredentialsForm._;

  const CredentialsForm._({
    required this.can,
    required this.pin,
    required this.certificate,
    required this.onCertificateChanged,
    super.key,
  });

  final TextEditingController can;
  final TextEditingController pin;
  final DnieCertificateType certificate;
  final ValueChanged<DnieCertificateType> onCertificateChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      SegmentedButton(
        segments: const [
          ButtonSegment(
            value: DnieCertificateType.sign,
            label: Text('Signing'),
            icon: Icon(Icons.draw),
          ),
          ButtonSegment(
            value: DnieCertificateType.auth,
            label: Text('Authentication'),
            icon: Icon(Icons.verified_user),
          ),
        ],
        selected: {certificate},
        onSelectionChanged: (selection) =>
            onCertificateChanged(selection.first),
      ),
      TextField(
        controller: can,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'CAN',
          helperText: 'The 6 digits printed on the front of the card',
          border: OutlineInputBorder(),
        ),
      ),
      TextField(
        controller: pin,
        obscureText: true,
        maxLength: 16,
        decoration: const InputDecoration(
          labelText: 'PIN',
          helperText: 'From the envelope that came with the card',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}
