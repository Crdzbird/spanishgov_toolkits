import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/dnie/auto_detect_tile.dart';
import 'package:felectronic_dnie_example/dnie/credentials_form.dart';
import 'package:felectronic_dnie_example/dnie/dnie_card_section.dart';
import 'package:felectronic_dnie_example/dnie/dnie_workflow_section.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:felectronic_dnie_example/shared/demo_tab.dart';
import 'package:felectronic_dnie_example/shared/warning_banner.dart';
import 'package:flutter/material.dart';

part 'dnie_tab_state.dart';

/// Reading and signing with the DNIe over NFC.
final class DnieTab extends StatefulWidget {
  const factory DnieTab({Key? key}) = DnieTab._;

  const DnieTab._({super.key});

  @override
  State<DnieTab> createState() => _DnieTabState();
}
