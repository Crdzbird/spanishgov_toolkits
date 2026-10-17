import 'package:felectronic_dnie_example/clave/clave_session_actions.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:flutter/material.dart';

/// What can be done with a stored Cl@ve session.
final class ClaveSessionCard extends StatelessWidget {
  const factory ClaveSessionCard({
    required ClaveSessionActions actions,
    required ValueNotifier<bool> signedIn,
    required DemoController controller,
    Key? key,
  }) = ClaveSessionCard._;

  const ClaveSessionCard._({
    required this.actions,
    required this.signedIn,
    required this.controller,
    super.key,
  });

  final ClaveSessionActions actions;
  final ValueNotifier<bool> signedIn;
  final DemoController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ValueListenableBuilder(
        valueListenable: signedIn,
        builder: (context, isSignedIn, _) => Text(
          isSignedIn ? 'A token is stored.' : 'Not signed in.',
        ),
      ),
      const SizedBox(height: 8),
      ActionButton(
        controller: controller,
        icon: Icons.key,
        label: 'Show the stored token',
        working: 'Reading the token',
        action: actions.storedToken,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.verified,
        label: 'Validate with the gateway',
        working: 'Checking',
        action: actions.validate,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.refresh,
        label: 'Refresh the token',
        working: 'Refreshing',
        action: actions.refresh,
      ),
      ActionButton(
        controller: controller,
        icon: Icons.logout,
        label: 'Sign out',
        working: 'Signing out',
        action: actions.logout,
      ),
    ],
  );
}
