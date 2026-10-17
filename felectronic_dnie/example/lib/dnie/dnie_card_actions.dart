import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';

/// One call to the card per action, each turned into a status to show.
abstract final class DnieCardActions {
  static Future<DemoStatus> probe() async {
    final probe = await probeCard();
    return DemoStatus(
      probe.isValidDnie ? 'This card is a DNIe' : 'This card is not a DNIe',
      detail: 'ATR: ${probe.atrHex}\nTag: ${probe.tagId}',
    );
  }

  static Future<DemoStatus> verify(DnieSession session) async {
    await session.verifyCredentials();
    return DemoStatus(
      'CAN and PIN are correct',
      detail: 'The ${session.certificateType.name} certificate is unlocked.',
    );
  }

  static Future<DemoStatus> sign(DnieSession session) async {
    final signed = await session.signText('Hello, DNIe!');
    return DemoStatus(
      'Signed "Hello, DNIe!"',
      detail:
          'Signature: ${signed.signatureSizeBytes} bytes\n'
          'Certificate: ${signed.certificateDer?.length ?? 0} bytes',
    );
  }

  static Future<DemoStatus> certificateDetails(DnieSession session) async {
    final info = await session.certificateDetails();
    return DemoStatus(
      info.expiryStatus,
      detail:
          'Subject: ${info.subjectCommonName}\n'
          'Issuer: ${info.issuerCommonName}\n'
          'Can sign now: ${info.isValidForSigning}\n'
          'Expiring soon: ${info.isExpiringSoon}',
    );
  }

  static Future<DemoStatus> personalData(DnieSession session) async {
    final person = await session.personalData();
    return DemoStatus(
      person.displayName,
      detail:
          'NIF: ${person.nif} '
          '(${person.nif.isValidNif ? 'valid' : 'invalid'} control letter)\n'
          'Initials: ${person.initials}\n'
          'Country: ${person.country}\n'
          'Read from the ${person.certificateKind?.name} certificate',
    );
  }
}
