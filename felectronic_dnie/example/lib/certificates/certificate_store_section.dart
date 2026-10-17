import 'package:felectronic_dnie_example/certificates/certificate_actions.dart';
import 'package:felectronic_dnie_example/certificates/certificate_import.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/section_title.dart';
import 'package:flutter/material.dart';

/// Getting certificates into the app and choosing the default one.
final class CertificateStoreSection extends StatelessWidget {
  const factory CertificateStoreSection({
    required DemoController controller,
    Key? key,
  }) = CertificateStoreSection._;

  const CertificateStoreSection._({required this.controller, super.key});

  final DemoController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Get a certificate in'),
      ActionButton(
        controller: controller,
        icon: Icons.science,
        label: 'Import the bundled test certificate',
        hint: 'Self-signed, password "test"',
        working: 'Importing',
        action: CertificateImport.bundled,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.file_upload,
        label: 'Import a .p12 or .pfx',
        working: 'Choosing a file',
        action: () => CertificateImport.picked(context),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.list,
        label: 'List certificates',
        working: 'Listing',
        action: CertificateActions.list,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.touch_app,
        label: 'Pick the default certificate',
        working: 'Opening the picker',
        action: () => CertificateActions.pick(context),
      ),
    ],
  );
}
