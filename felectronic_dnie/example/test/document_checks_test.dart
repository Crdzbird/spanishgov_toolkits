import 'package:felectronic_dnie_example/clave/document_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a valid DNI asks for its validity date', () {
    final status = DocumentChecks.document('12345678Z');
    expect(status.isError, isFalse);
    expect(DocumentChecks.contrastLabel('12345678Z'), 'Validity date');
  });

  test('a wrong control letter is an error', () {
    expect(DocumentChecks.document('12345678A').isError, isTrue);
  });

  test('a NIE asks for its support number', () {
    expect(DocumentChecks.contrastLabel('X1234567L'), 'Support number');
    expect(DocumentChecks.contrastHint('X1234567L'), 'C12345678');
  });

  test('Cl@ve Movil is refused before sending with a bad contrast', () {
    expect(DocumentChecks.problem('X1234567L', 'nonsense'), isNotNull);
    expect(DocumentChecks.problem('X1234567L', 'C12345678'), isNull);
  });
}
