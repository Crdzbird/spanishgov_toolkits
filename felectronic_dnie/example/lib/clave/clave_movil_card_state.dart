part of 'clave_movil_card.dart';

final class _ClaveMovilCardState extends State<ClaveMovilCard> {
  ClaveMobilePoller? _poller;
  StreamSubscription<ClavePollStatus>? _polling;
  String? _code;

  Future<DemoStatus> _send() async {
    final document = widget.document.text.trim();
    final contrast = widget.contrast.text.trim();
    final problem = DocumentChecks.problem(document, contrast);
    if (problem != null) return problem;
    final session = await widget.clave.sendNotificationCode(
      document: document,
      contrast: contrast,
    );
    if (!mounted) return const DemoStatus('Sent');
    _stopPolling();
    final poller = ClaveMobilePoller(widget.clave);
    setState(() {
      _code = session.verificationCode;
      _poller = poller;
    });
    _polling = poller.poll(session: session).listen(_onPoll);
    return const DemoStatus(
      'Sent: approve it in the Cl@ve app',
      detail: 'The first check runs after 20 seconds, then every 5.',
    );
  }

  void _onPoll(ClavePollStatus status) {
    if (!mounted) return;
    widget.controller.value = switch (status) {
      ClavePollWaiting(:final elapsedSeconds) => DemoStatus(
        'Waiting for approval, $elapsedSeconds s',
      ),
      ClavePollSuccess(:final result) => DemoStatus(
        'Approved',
        detail: result.accessToken.tokenPreview,
      ),
      ClavePollError(:final error) => describeError(error),
    };
    if (status is ClavePollWaiting) return;
    widget.signedIn.value = status is ClavePollSuccess;
    setState(_stopPolling);
  }

  void _stopPolling() {
    _poller?.cancel();
    unawaited(_polling?.cancel());
    _poller = null;
    _code = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_code != null)
        ListTile(
          title: Text('Verification code: $_code'),
          subtitle: const Text('Approve only if the Cl@ve app shows the same.'),
          trailing: TextButton(
            onPressed: () => setState(_stopPolling),
            child: const Text('Stop'),
          ),
        ),
      ActionButton(
        controller: widget.controller,
        icon: Icons.phone_android,
        label: 'Send a notification',
        hint: 'Uses the document and contrast above',
        working: 'Sending',
        action: _send,
      ),
    ],
  );
}
