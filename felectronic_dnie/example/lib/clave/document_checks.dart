import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';

/// The offline checks Cl@ve Movil needs before it will send anything: a valid
/// DNI or NIE, and the matching contrast (a validity date for a DNI, a support
/// number for a NIE).
abstract final class DocumentChecks {
  static DemoStatus document(String text) {
    final document = text.trim();
    final error = document.validateDocument();
    if (error != null) return DemoStatus.error(error.message);
    return DemoStatus(
      'Valid ${document.documentType}',
      detail: 'Contrast needed: ${DocumentValidator.contrastTypeFor(document)}',
    );
  }

  static DemoStatus contrast(String document, String contrast) =>
      problem(document, contrast) ??
      DemoStatus('Valid contrast', detail: contrastLabel(document));

  /// Why [document] and [contrast] cannot be used together, or null.
  static DemoStatus? problem(String document, String contrast) {
    final documentError = document.trim().validateDocument();
    if (documentError != null) return DemoStatus.error(documentError.message);
    final contrastError = contrast.trim().validateContrast(
      isDni: DocumentValidator.isDni(document.trim()),
    );
    if (contrastError != null) return DemoStatus.error(contrastError.message);
    return null;
  }

  static String contrastLabel(String document) {
    if (DocumentValidator.isDni(document.trim())) return 'Validity date';
    if (DocumentValidator.isNie(document.trim())) return 'Support number';
    return 'Contrast (enter the document first)';
  }

  static String contrastHint(String document) {
    if (DocumentValidator.isDni(document.trim())) return 'dd-MM-yyyy';
    if (DocumentValidator.isNie(document.trim())) return 'C12345678';
    return '';
  }
}
