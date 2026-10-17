import 'package:felectronic_dnie_example/certificates/certificate_store_section.dart';
import 'package:felectronic_dnie_example/certificates/certificate_use_section.dart';
import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_tab.dart';
import 'package:flutter/material.dart';

part 'certificates_tab_state.dart';

/// Signing with a certificate installed on the device.
final class CertificatesTab extends StatefulWidget {
  const factory CertificatesTab({Key? key}) = CertificatesTab._;

  const CertificatesTab._({super.key});

  @override
  State<CertificatesTab> createState() => _CertificatesTabState();
}
