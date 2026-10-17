part of 'certificates_tab.dart';

final class _CertificatesTabState extends State<CertificatesTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = DemoController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DemoTab(
      controller: _controller,
      children: [
        CertificateStoreSection(controller: _controller),
        CertificateUseSection(controller: _controller),
      ],
    );
  }
}
