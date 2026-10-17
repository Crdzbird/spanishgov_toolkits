import 'package:felectronic_dnie_example/app/home_page.dart';
import 'package:flutter/material.dart';

/// The example app: one tab per way of signing.
final class ExampleApp extends StatelessWidget {
  const factory ExampleApp({Key? key}) = ExampleApp._;

  const ExampleApp._({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Felectronic Suite',
    theme: ThemeData(colorSchemeSeed: Colors.blue),
    home: const HomePage(),
  );
}
