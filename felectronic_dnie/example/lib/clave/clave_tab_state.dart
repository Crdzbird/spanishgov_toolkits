part of 'clave_tab.dart';

final class _ClaveTabState extends State<ClaveTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = DemoController();
  final _clave = ClaveRepository(ExampleClaveConfig.config);
  final ValueNotifier<bool> _signedIn = ValueNotifier(false);
  final _document = TextEditingController();
  final _contrast = TextEditingController();
  late final _actions = ClaveSessionActions(_clave, _signedIn);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(
      _clave.getStoredToken().then((token) => _signedIn.value = token != null),
    );
  }

  @override
  void dispose() {
    _clave.dispose();
    _controller.dispose();
    _signedIn.dispose();
    _document.dispose();
    _contrast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DemoTab(
      controller: _controller,
      children: [
        const SectionTitle('Check a document'),
        DocumentCard(
          document: _document,
          contrast: _contrast,
          controller: _controller,
        ),
        const SectionTitle('Sign in'),
        ClaveLoginCard(actions: _actions, controller: _controller),
        const SectionTitle('Session'),
        ClaveSessionCard(
          actions: _actions,
          signedIn: _signedIn,
          controller: _controller,
        ),
        const SectionTitle('Cl@ve Movil'),
        ClaveMovilCard(
          clave: _clave,
          document: _document,
          contrast: _contrast,
          signedIn: _signedIn,
          controller: _controller,
        ),
      ],
    );
  }
}
