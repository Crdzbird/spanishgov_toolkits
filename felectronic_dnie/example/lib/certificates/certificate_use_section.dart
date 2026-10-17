import 'package:felectronic_dnie_example/certificates/certificate_actions.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/section_title.dart';
import 'package:flutter/material.dart';

/// Using the default certificate, and removing it again.
final class CertificateUseSection extends StatelessWidget {
  const factory CertificateUseSection({
    required DemoController controller,
    Key? key,
  }) = CertificateUseSection._;

  const CertificateUseSection._({required this.controller, super.key});

  final DemoController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Use the default certificate'),
      ActionButton(
        controller: controller,
        icon: Icons.draw,
        label: 'Sign a text',
        working: 'Signing',
        action: CertificateActions.signWithDefault,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.security,
        label: 'Parse the X.509 certificate',
        working: 'Parsing',
        action: CertificateActions.parseDefault,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.clear,
        label: 'Forget the default',
        working: 'Clearing',
        action: CertificateActions.clearDefault,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.delete_outline,
        label: 'Delete the default certificate',
        working: 'Deleting',
        action: CertificateActions.deleteDefault,
      ),
    ],
  );
}
