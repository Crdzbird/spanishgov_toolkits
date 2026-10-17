import 'package:felectronic_dnie_example/certificates/certificates_tab.dart';
import 'package:felectronic_dnie_example/clave/clave_tab.dart';
import 'package:felectronic_dnie_example/dnie/dnie_tab.dart';
import 'package:flutter/material.dart';

/// The three ways to sign, one per tab.
final class HomePage extends StatelessWidget {
  const factory HomePage({Key? key}) = HomePage._;

  const HomePage._({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Felectronic Suite'),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.nfc), text: 'DNIe'),
            Tab(icon: Icon(Icons.badge), text: 'Certificates'),
            Tab(icon: Icon(Icons.login), text: 'Cl@ve'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [DnieTab(), CertificatesTab(), ClaveTab()],
      ),
    ),
  );
}
