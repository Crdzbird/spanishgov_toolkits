import 'package:felectronic_certificates/felectronic_certificates.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/fake_certificates_platform.dart';

void main() {
  late FakeCertificatesPlatform platform;

  setUp(() => platform = FakeCertificatesPlatform.installed());

  Future<Future<CertificateSession?>> open(WidgetTester tester) async {
    late Future<CertificateSession?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showCertificatePicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the chosen certificate becomes the default', (tester) async {
    platform.certificates.addAll([certificate('01'), certificate('02')]);
    final result = await open(tester);

    expect(find.text('Choose a certificate'), findsOneWidget);
    await tester.tap(find.text('Holder 02'));
    await tester.pumpAndSettle();

    expect(platform.defaultSerial, '02');
    expect((await result)?.certificate.serialNumber, '02');
  });

  testWidgets('an expired certificate is listed, marked', (tester) async {
    platform.certificates.add(certificate('01', expires: DateTime.utc(2001)));
    await open(tester);

    expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
    expect(find.textContaining('Expired'), findsOneWidget);
  });

  testWidgets('dismissing the sheet chooses nothing', (tester) async {
    platform.certificates.add(certificate('01'));
    final result = await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(platform.defaultSerial, isNull);
  });

  testWidgets('an empty keychain on iOS names the usual cause', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await open(tester);

    expect(find.textContaining('configuration profile'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an empty list elsewhere says there is nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await open(tester);

    expect(
      find.text('No certificates are available on this device.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
