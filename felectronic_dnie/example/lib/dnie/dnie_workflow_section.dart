import 'package:felectronic_dnie_example/dnie/dnie_workflow_actions.dart';
import 'package:felectronic_dnie_example/dnie/with_session.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/section_title.dart';
import 'package:flutter/material.dart';

/// Actions that chain several reads of the card.
final class DnieWorkflowSection extends StatelessWidget {
  const factory DnieWorkflowSection({
    required DemoController controller,
    required WithSession withSession,
    Key? key,
  }) = DnieWorkflowSection._;

  const DnieWorkflowSection._({
    required this.controller,
    required this.withSession,
    super.key,
  });

  final DemoController controller;
  final WithSession withSession;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Workflows'),
      ActionButton(
        controller: controller,
        icon: Icons.checklist,
        label: 'Check readiness',
        hint: 'NFC, then the card, then the PIN',
        working: 'Checking',
        action: () => withSession(DnieWorkflowActions.readiness),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.perm_identity,
        label: 'Read full identity',
        hint: 'Personal data and certificate, two reads',
        working: 'Reading',
        action: () => withSession(DnieWorkflowActions.identity),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.playlist_add_check,
        label: 'Probe, then sign',
        working: 'Probing',
        action: () => withSession(DnieWorkflowActions.probeAndSign),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.security,
        label: 'Parse the X.509 certificate',
        working: 'Reading the certificate',
        action: () => withSession(DnieWorkflowActions.parseCertificate),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.compare_arrows,
        label: 'Read both certificates',
        hint: 'One session, switched with .signing and .auth',
        working: 'Reading both certificates',
        action: () => withSession(DnieWorkflowActions.bothCertificates),
      ),
    ],
  );
}
