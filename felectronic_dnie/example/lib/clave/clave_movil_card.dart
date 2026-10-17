import 'dart:async';

import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie_example/clave/document_checks.dart';
import 'package:felectronic_dnie_example/clave/token_preview.dart';
import 'package:felectronic_dnie_example/shared/action_button.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:felectronic_dnie_example/shared/describe_error.dart';
import 'package:flutter/material.dart';

part 'clave_movil_card_state.dart';

/// Cl@ve Movil: push a notification to the Cl@ve app for the document above,
/// then poll until the user approves it there.
final class ClaveMovilCard extends StatefulWidget {
  const factory ClaveMovilCard({
    required ClaveRepository clave,
    required TextEditingController document,
    required TextEditingController contrast,
    required ValueNotifier<bool> signedIn,
    required DemoController controller,
    Key? key,
  }) = ClaveMovilCard._;

  const ClaveMovilCard._({
    required this.clave,
    required this.document,
    required this.contrast,
    required this.signedIn,
    required this.controller,
    super.key,
  });

  final ClaveRepository clave;
  final TextEditingController document;
  final TextEditingController contrast;
  final ValueNotifier<bool> signedIn;
  final DemoController controller;

  @override
  State<ClaveMovilCard> createState() => _ClaveMovilCardState();
}
