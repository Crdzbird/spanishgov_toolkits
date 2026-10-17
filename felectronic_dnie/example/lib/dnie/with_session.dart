import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';

/// Runs an action with a [DnieSession] built from the form, or reports why
/// the CAN or PIN cannot be used.
typedef WithSession =
    Future<DemoStatus> Function(
      Future<DemoStatus> Function(DnieSession session) action,
    );
