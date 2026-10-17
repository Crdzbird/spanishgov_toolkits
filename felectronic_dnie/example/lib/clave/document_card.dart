import 'package:felectronic_dnie_example/clave/document_checks.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/section_card.dart';
import 'package:flutter/material.dart';

/// The document and contrast, checked offline. Cl@ve Movil uses them too.
final class DocumentCard extends StatelessWidget {
  const factory DocumentCard({
    required TextEditingController document,
    required TextEditingController contrast,
    required DemoController controller,
    Key? key,
  }) = DocumentCard._;

  const DocumentCard._({
    required this.document,
    required this.contrast,
    required this.controller,
    super.key,
  });

  final TextEditingController document;
  final TextEditingController contrast;
  final DemoController controller;

  @override
  Widget build(BuildContext context) => SectionCard(
    children: [
      TextField(
        controller: document,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'DNI or NIE',
          hintText: '12345678Z',
          border: OutlineInputBorder(),
        ),
      ),
      ListenableBuilder(
        listenable: document,
        builder: (context, _) => TextField(
          controller: contrast,
          decoration: InputDecoration(
            labelText: DocumentChecks.contrastLabel(document.text),
            hintText: DocumentChecks.contrastHint(document.text),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: () =>
                controller.value = DocumentChecks.document(document.text),
            child: const Text('Check document'),
          ),
          FilledButton.tonal(
            onPressed: () => controller.value = DocumentChecks.contrast(
              document.text,
              contrast.text,
            ),
            child: const Text('Check contrast'),
          ),
        ],
      ),
    ],
  );
}
