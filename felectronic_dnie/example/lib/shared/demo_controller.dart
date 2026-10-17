import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:felectronic_dnie_example/shared/describe_error.dart';
import 'package:flutter/foundation.dart';

/// Runs a tab's actions one at a time and holds what its status panel shows.
final class DemoController extends ValueNotifier<DemoStatus> {
  factory DemoController() = DemoController._;

  DemoController._() : super(const DemoStatus('Ready'));

  /// Whether an action is running, so the others should not start.
  bool get busy => value.busy;

  /// Shows [working] while [action] runs, then whatever it returns, or what
  /// went wrong if it throws.
  Future<void> run(String working, Future<DemoStatus> Function() action) async {
    value = DemoStatus(working, busy: true);
    try {
      value = await action();
    } on Object catch (error) {
      value = describeError(error);
    }
  }
}
