import 'package:flutter/foundation.dart';

/// What a demo tab shows in its status panel: a headline, optional detail,
/// and whether an action is still running.
@immutable
final class DemoStatus {
  const factory DemoStatus(
    String title, {
    String detail,
    bool busy,
    bool isError,
  }) = DemoStatus._;

  const DemoStatus._(
    this.title, {
    this.detail = '',
    this.busy = false,
    this.isError = false,
  });

  /// A failure, shown in the error colour.
  const factory DemoStatus.error(String title, [String detail]) =
      DemoStatus._error;

  const DemoStatus._error(this.title, [this.detail = ''])
    : busy = false,
      isError = true;

  final String title;
  final String detail;
  final bool busy;
  final bool isError;
}
