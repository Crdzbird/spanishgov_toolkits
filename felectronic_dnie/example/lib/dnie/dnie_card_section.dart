import 'package:felectronic_dnie_example/dnie/dnie_card_actions.dart';
import 'package:felectronic_dnie_example/dnie/with_session.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/section_title.dart';
import 'package:flutter/material.dart';

/// The single operations: each button is one read of the card.
final class DnieCardSection extends StatelessWidget {
  const factory DnieCardSection({
    required DemoController controller,
    required WithSession withSession,
    Key? key,
  }) = DnieCardSection._;

  const DnieCardSection._({
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
      const SectionTitle('Card operations'),
      ActionButton(
        controller: controller,
        icon: Icons.contactless,
        label: 'Probe card',
        hint: 'No CAN or PIN needed',
        working: 'Hold the card against the phone',
        action: DnieCardActions.probe,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.lock_open,
        label: 'Verify PIN',
        working: 'Verifying the CAN and PIN',
        action: () => withSession(DnieCardActions.verify),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.draw,
        label: 'Sign a text',
        working: 'Signing',
        action: () => withSession(DnieCardActions.sign),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.info_outline,
        label: 'Certificate details',
        working: 'Reading the certificate',
        action: () => withSession(DnieCardActions.certificateDetails),
      ),
      ActionButton(
        controller: controller,
        icon: Icons.person,
        label: 'Personal data',
        working: 'Reading the personal data',
        action: () => withSession(DnieCardActions.personalData),
      ),
    ],
  );
}
