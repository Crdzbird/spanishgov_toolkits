import 'dart:async';
import 'dart:convert';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Example app demonstrating the felectronic_dnie plugin.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FelectronicDnie Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const DnieHomePage(),
    );
  }
}

/// Home page with all DNIe operations.
class DnieHomePage extends StatefulWidget {
  /// Creates the home page.
  const DnieHomePage({super.key});

  @override
  State<DnieHomePage> createState() => _DnieHomePageState();
}

class _DnieHomePageState extends State<DnieHomePage> {
  final _canController = TextEditingController();
  final _pinController = TextEditingController();

  String _status = 'Ready';
  String _result = '';
  bool _busy = false;
  NfcStatus? _nfcStatus;
  DnieCertificateType _certType = DnieCertificateType.sign;

  @override
  void initState() {
    super.initState();
    unawaited(_checkNfc());
  }

  Future<void> _checkNfc() async {
    try {
      final status = await checkNfcAvailability();
      setState(() => _nfcStatus = status);
    } on DnieError catch (e) {
      setState(() => _status = 'NFC check failed: ${e.message}');
    }
  }

  String? _validateCredentials({bool requirePin = true}) {
    final can = _canController.text.trim();
    if (can.length != 6) return 'CAN must be 6 digits';
    if (requirePin) {
      final pin = _pinController.text.trim();
      if (pin.length < 8 || pin.length > 16) {
        return 'PIN must be 8-16 characters';
      }
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _result = '';
    });
    try {
      await action();
    } on DnieError catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
        if (e is DnieWrongPinError && e.remainingRetries >= 0) {
          _status = '$_status (${e.remainingRetries} retries remaining)';
        }
        _result = '';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleProbeCard() => _run(() async {
        setState(() => _status = 'Hold your card near the device...');
        final probe = await probeCard();
        setState(() {
          _status = probe.isValidDnie
              ? 'Valid DNIe detected!'
              : 'Card detected but not a DNIe.';
          _result = 'ATR: ${probe.atrHex}\nTag ID: ${probe.tagId}';
        });
      });

  Future<void> _handleVerifyPin() => _run(() async {
        final error = _validateCredentials();
        if (error != null) {
          setState(() => _status = error);
          return;
        }
        setState(() => _status = 'Verifying PIN... Hold your DNIe near.');
        await verifyPin(
          can: _canController.text.trim(),
          pin: _pinController.text.trim(),
          certificateType: _certType,
        );
        setState(() {
          _status = 'PIN verified successfully!';
          _result = 'CAN and PIN are correct '
              '(${_certType.value} certificate).';
        });
      });

  Future<void> _handleSign() => _run(() async {
        final error = _validateCredentials();
        if (error != null) {
          setState(() => _status = error);
          return;
        }
        setState(() => _status = 'Signing... Hold your DNIe near.');
        final data = utf8.encode('Hello, DNIe!');
        final signed = await sign(
          data: data,
          can: _canController.text.trim(),
          pin: _pinController.text.trim(),
          certificateType: _certType,
        );
        final previewLength = signed.signedDataBase64.length.clamp(0, 40);
        setState(() {
          _status = 'Signed successfully (${_certType.value})!';
          _result = 'Base64: '
              '${signed.signedDataBase64.substring(0, previewLength)}...\n'
              'Certificate length: ${signed.certificate.length}';
        });
      });

  Future<void> _handleReadCertificate() => _run(() async {
        final error = _validateCredentials();
        if (error != null) {
          setState(() => _status = error);
          return;
        }
        setState(() => _status = 'Reading certificate... Hold your DNIe near.');
        final cert = await readCertificate(
          can: _canController.text.trim(),
          pin: _pinController.text.trim(),
          certificateType: _certType,
        );
        setState(() {
          _status = 'Certificate read (${_certType.value})!';
          _result = 'Certificate length: ${cert.certificate.length}';
        });
      });

  Future<void> _handleCertificateDetails() => _run(() async {
        final error = _validateCredentials();
        if (error != null) {
          setState(() => _status = error);
          return;
        }
        setState(
          () => _status = 'Reading certificate details... Hold your DNIe near.',
        );
        final info = await readCertificateDetails(
          can: _canController.text.trim(),
          pin: _pinController.text.trim(),
          certificateType: _certType,
        );
        setState(() {
          _status = 'Certificate details read (${_certType.value})!';
          _result = 'Subject: ${info.subjectCommonName}\n'
              'NIF: ${info.subjectSerialNumber}\n'
              'Issuer: ${info.issuerCommonName} (${info.issuerOrganization})\n'
              'Serial: ${info.serialNumber}\n'
              'Valid from: ${info.notValidBefore}\n'
              'Valid until: ${info.notValidAfter}\n'
              'Currently valid: ${info.isCurrentlyValid}';
        });
      });

  Future<void> _handlePersonalData() => _run(() async {
        final error = _validateCredentials();
        if (error != null) {
          setState(() => _status = error);
          return;
        }
        setState(
          () => _status = 'Reading personal data... Hold your DNIe near.',
        );
        final data = await readPersonalData(
          can: _canController.text.trim(),
          pin: _pinController.text.trim(),
          certificateType: _certType,
        );
        setState(() {
          _status = 'Personal data read (${_certType.value})!';
          _result = 'Name: ${data.fullName}\n'
              'Given name: ${data.givenName}\n'
              'Surnames: ${data.surnames}\n'
              'NIF: ${data.nif}\n'
              'Country: ${data.country}\n'
              'Certificate type: ${data.certificateType}';
        });
      });

  Future<void> _handleStopScan() async {
    await stopSign();
    setState(() => _status = 'Scan stopped.');
  }

  @override
  void dispose() {
    _canController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FelectronicDnie')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // NFC status banner
          if (_nfcStatus != null && !_nfcStatus!.isEnabled)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.nfc,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nfcStatus!.isAvailable
                            ? 'NFC is disabled. Enable it in Settings.'
                            : 'This device does not have NFC.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_nfcStatus != null && !_nfcStatus!.isEnabled)
            const SizedBox(height: 16),

          // Certificate type selector
          SegmentedButton<DnieCertificateType>(
            segments: const [
              ButtonSegment(
                value: DnieCertificateType.sign,
                label: Text('SIGN'),
                icon: Icon(Icons.draw),
              ),
              ButtonSegment(
                value: DnieCertificateType.auth,
                label: Text('AUTH'),
                icon: Icon(Icons.verified_user),
              ),
            ],
            selected: {_certType},
            onSelectionChanged: (set) {
              setState(() => _certType = set.first);
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _canController,
            decoration: const InputDecoration(
              labelText: 'CAN (6 digits)',
              hintText: 'Printed on the front of your DNIe',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: 'PIN (8-16 characters)',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            maxLength: 16,
          ),
          const SizedBox(height: 24),
          _ActionButton(
            onPressed: _busy ? null : _handleProbeCard,
            icon: Icons.contactless,
            label: 'Probe Card',
            subtitle: 'No PIN required',
            filled: false,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            onPressed: _busy ? null : _handleVerifyPin,
            icon: Icons.lock_open,
            label: 'Verify PIN',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            onPressed: _busy ? null : _handleSign,
            icon: Icons.nfc,
            label: 'Sign Data',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            onPressed: _busy ? null : _handleReadCertificate,
            icon: Icons.badge,
            label: 'Read Certificate',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            onPressed: _busy ? null : _handleCertificateDetails,
            icon: Icons.info_outline,
            label: 'Certificate Details',
          ),
          const SizedBox(height: 8),
          _ActionButton(
            onPressed: _busy ? null : _handlePersonalData,
            icon: Icons.person,
            label: 'Personal Data',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _handleStopScan,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Scan'),
          ),
          const SizedBox(height: 24),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _result,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.subtitle,
    this.filled = true,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );

    if (filled) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}
