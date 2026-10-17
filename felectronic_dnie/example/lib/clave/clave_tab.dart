import 'dart:async';

import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie_example/clave/clave_config.dart';
import 'package:felectronic_dnie_example/clave/clave_login_card.dart';
import 'package:felectronic_dnie_example/clave/clave_movil_card.dart';
import 'package:felectronic_dnie_example/clave/clave_session_actions.dart';
import 'package:felectronic_dnie_example/clave/clave_session_card.dart';
import 'package:felectronic_dnie_example/clave/document_card.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_tab.dart';
import 'package:felectronic_dnie_example/shared/section_title.dart';
import 'package:flutter/material.dart';

part 'clave_tab_state.dart';

/// Signing in to Spanish public services with Cl@ve.
final class ClaveTab extends StatefulWidget {
  const factory ClaveTab({Key? key}) = ClaveTab._;

  const ClaveTab._({super.key});

  @override
  State<ClaveTab> createState() => _ClaveTabState();
}
