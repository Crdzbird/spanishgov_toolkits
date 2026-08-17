import 'package:felectronic_dnie_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Launch smoke test.
///
/// The plugin's real functionality — reading a DNIe over NFC, signing with a
/// certificate — needs physical hardware and a card, so it cannot run in CI.
/// What this does catch is the app failing to boot, plugin registration
/// throwing, or the first frame not rendering, which is what an end-to-end
/// job on a plugin repository is actually for.
///
/// Replaces the `very_good create flutter_plugin` scaffolding test, which
/// tapped a "Get Platform Name" button that no longer exists in this app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('app launch', () {
    testWidgets('boots and renders the main screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // The app bar title of the example app. Asserted rather than a section
      // heading because sections live in a scroll view and may not be built
      // on the first frame.
      expect(find.text('Felectronic Suite'), findsWidgets);
    });
  });
}
