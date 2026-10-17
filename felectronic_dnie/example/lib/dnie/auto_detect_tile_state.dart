part of 'auto_detect_tile.dart';

final class _AutoDetectTileState extends State<AutoDetectTile> {
  bool _on = false;
  bool _listening = false;

  DemoController get _controller => widget.controller;

  Future<void> _toggle(bool on) async {
    setState(() => _on = on);
    if (!on) return stopSign();
    if (_listening) return;
    _listening = true;
    _controller.value = const DemoStatus(
      'Listening for a card',
      detail: 'Hold a card flat against the back of the phone.',
      busy: true,
    );
    while (_on && mounted) {
      await _listenOnce();
    }
    _listening = false;
    if (!mounted) return;
    _controller.value = const DemoStatus('Automatic detection off');
  }

  Future<void> _listenOnce() async {
    try {
      final probe = await probeCard(timeout: const Duration(seconds: 10));
      if (!mounted) return;
      final at = DateTime.now().toIso8601String().substring(11, 19);
      _controller.value = DemoStatus(
        probe.isValidDnie ? 'DNIe seen at $at' : 'Card seen at $at, not a DNIe',
        detail: 'ATR: ${probe.atrHex}\nTag: ${probe.tagId}',
        busy: true,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
    } on DnieTimeoutError {
      return;
    } on DnieCancelledError {
      if (mounted) setState(() => _on = false);
    } on DnieError catch (error) {
      if (!mounted) return;
      _controller.value = DemoStatus(error.message, busy: true, isError: true);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _on = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _controller,
    builder: (context, status, _) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.contactless),
      title: const Text('Detect cards automatically'),
      subtitle: const Text('No CAN or PIN needed'),
      value: _on,
      onChanged: status.busy && !_on ? null : (on) => unawaited(_toggle(on)),
    ),
  );
}
