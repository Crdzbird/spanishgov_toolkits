import 'dart:async';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:flutter/material.dart';

part 'auto_detect_tile_state.dart';

/// A switch that keeps NFC listening and reports every card it sees, the
/// quickest way to check that the phone reads the card at all.
final class AutoDetectTile extends StatefulWidget {
  const factory AutoDetectTile({
    required DemoController controller,
    Key? key,
  }) = AutoDetectTile._;

  const AutoDetectTile._({required this.controller, super.key});

  final DemoController controller;

  @override
  State<AutoDetectTile> createState() => _AutoDetectTileState();
}
