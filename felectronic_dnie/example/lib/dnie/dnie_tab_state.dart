part of 'dnie_tab.dart';

final class _DnieTabState extends State<DnieTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = DemoController();
  final _can = TextEditingController();
  final _pin = TextEditingController();
  final Future<NfcStatus> _nfc = checkNfcAvailability();
  DnieCertificateType _certificate = DnieCertificateType.sign;

  @override
  bool get wantKeepAlive => true;

  Future<DemoStatus> _withSession(
    Future<DemoStatus> Function(DnieSession session) action,
  ) async {
    final problem = _can.text.validateCan() ?? _pin.text.validatePin();
    if (problem != null) return DemoStatus.error(problem.message);
    return action(
      DnieSession(
        can: _can.text,
        pin: _pin.text,
        certificateType: _certificate,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _can.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DemoTab(
      controller: _controller,
      onStop: stopSign,
      children: [
        FutureBuilder(
          future: _nfc,
          builder: (context, nfc) => nfc.data?.isReady ?? true
              ? const SizedBox.shrink()
              : WarningBanner(
                  icon: Icons.nfc,
                  message: nfc.data!.statusMessage,
                ),
        ),
        AutoDetectTile(controller: _controller),
        const SizedBox(height: 8),
        CredentialsForm(
          can: _can,
          pin: _pin,
          certificate: _certificate,
          onCertificateChanged: (type) => setState(() => _certificate = type),
        ),
        DnieCardSection(controller: _controller, withSession: _withSession),
        DnieWorkflowSection(controller: _controller, withSession: _withSession),
      ],
    );
  }
}
