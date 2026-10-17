import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie_example/clave/clave_config.dart';
import 'package:felectronic_dnie_example/clave/clave_method_icon.dart';
import 'package:felectronic_dnie_example/clave/clave_session_actions.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:flutter/material.dart';

part 'clave_login_card_state.dart';

/// Signing in through the Cl@ve browser, by each method the chosen level of
/// assurance allows.
final class ClaveLoginCard extends StatefulWidget {
  const factory ClaveLoginCard({
    required ClaveSessionActions actions,
    required DemoController controller,
    Key? key,
  }) = ClaveLoginCard._;

  const ClaveLoginCard._({
    required this.actions,
    required this.controller,
    super.key,
  });

  final ClaveSessionActions actions;
  final DemoController controller;

  @override
  State<ClaveLoginCard> createState() => _ClaveLoginCardState();
}
