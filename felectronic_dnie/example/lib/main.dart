import 'dart:async';
import 'dart:convert';

import 'package:felectronic_certificates/felectronic_certificates.dart'
    as certs;
import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Felectronic Suite',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Felectronic Suite'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.nfc), text: 'DNIe NFC'),
              Tab(
                icon: Icon(Icons.badge),
                text: 'Certificates',
              ),
              Tab(icon: Icon(Icons.login), text: 'Cl@ve'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DnieTab(),
            _CertificatesTab(),
            _ClaveTab(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DNIe NFC Tab
// =============================================================================

class _DnieTab extends StatefulWidget {
  const _DnieTab();
  @override
  State<_DnieTab> createState() => _DnieTabState();
}

class _DnieTabState extends State<_DnieTab>
    with AutomaticKeepAliveClientMixin {
  final _canCtl = TextEditingController();
  final _pinCtl = TextEditingController();
  String _status = 'Ready';
  String _result = '';
  bool _busy = false;
  NfcStatus? _nfc;
  DnieCertificateType _certType = DnieCertificateType.sign;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_checkNfc());
  }

  Future<void> _checkNfc() async {
    try {
      final s = await checkNfcAvailability();
      setState(() => _nfc = s);
    } on DnieError catch (e) {
      setState(() => _status = 'NFC: ${e.message}');
    }
  }

  String? _validate({bool pin = true}) {
    final ce = _canCtl.text.trim().validateCan();
    if (ce != null) return ce.message;
    if (pin) {
      final pe = _pinCtl.text.trim().validatePin();
      if (pe != null) return pe.message;
    }
    return null;
  }

  String get _can => _canCtl.text.trim();
  String get _pin => _pinCtl.text.trim();

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _result = '';
    });
    try {
      await fn();
    } on DnieError catch (e) {
      var m = 'Error: ${e.message}';
      if (e is DnieWrongPinError && e.remainingRetries >= 0) {
        m = '$m (${e.remainingRetries} retries left)';
      }
      setState(() {
        _status = m;
        _result = '';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runValidated(
    String loadingMsg,
    Future<void> Function() action,
  ) =>
      _run(() async {
        final error = _validate();
        if (error != null) return setState(() => _status = error);
        setState(() => _status = loadingMsg);
        await action();
      });

  @override
  void dispose() {
    _canCtl.dispose();
    _pinCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_nfc != null && !_nfc!.isReady)
          _WarningBanner(
            icon: Icons.nfc,
            message: _nfc!.statusMessage,
          ),
        if (_nfc != null && !_nfc!.isReady)
          const SizedBox(height: 16),

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
          onSelectionChanged: (s) =>
              setState(() => _certType = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _canCtl,
          decoration: const InputDecoration(
            labelText: 'CAN (6 digits)',
            hintText: 'Printed on the front',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinCtl,
          decoration: const InputDecoration(
            labelText: 'PIN (8-16 characters)',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          maxLength: 16,
        ),
        const SizedBox(height: 24),

        // --- Basic ---
        const _Section(title: 'Basic Operations'),
        _Btn(
          busy: _busy,
          icon: Icons.contactless,
          label: 'Probe Card',
          subtitle: 'No PIN required',
          filled: false,
          onPressed: () => _run(() async {
            setState(() => _status = 'Hold card near...');
            final p = await probeCard();
            setState(() {
              _status = p.isValidDnie
                  ? 'Valid DNIe!'
                  : 'Not a DNIe.';
              _result = 'ATR: ${p.atrHex}\n'
                  'Tag: ${p.tagId}';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.lock_open,
          label: 'Verify PIN',
          onPressed: () => _runValidated('Verifying...', () async {
            await verifyPin(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = 'PIN verified!';
              _result = '${_certType.value} cert OK.';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.nfc,
          label: 'Sign Data',
          onPressed: () => _runValidated('Signing...', () async {
            final s = await sign(
              data: utf8.encode('Hello, DNIe!'),
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = 'Signed (${_certType.value})!';
              _result = 'Complete: ${s.isComplete}\n'
                  'Size: ${s.signatureSizeBytes} bytes';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.badge,
          label: 'Read Certificate',
          onPressed: () => _runValidated('Reading cert...', () async {
            final c = await readCertificate(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = 'Certificate read!';
              _result =
                  'Has cert: ${c.hasCertificate}\n'
                  'Length: ${c.certificate.length}';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.info_outline,
          label: 'Certificate Details',
          onPressed: () => _runValidated('Reading details...', () async {
            final i = await readCertificateDetails(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = i.expiryStatus;
              _result =
                  'Subject: ${i.subjectCommonName}\n'
                  'NIF: ${i.subjectSerialNumber}\n'
                  'Issuer: ${i.issuerCommonName}\n'
                  'Valid: ${i.isCurrentlyValid}\n'
                  'For signing: ${i.isValidForSigning}\n'
                  'Expiring soon: ${i.isExpiringSoon}';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.person,
          label: 'Personal Data',
          onPressed: () => _runValidated('Reading data...', () async {
            final pd = await readPersonalData(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = 'Personal data read!';
              _result = 'Name: ${pd.fullName}\n'
                  'Initials: ${pd.initials}\n'
                  'NIF: ${pd.nif}\n'
                  'Country: ${pd.country}\n'
                  'Signing: ${pd.isSigningCert}\n'
                  'Auth: ${pd.isAuthCert}';
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- X.509 Parsing ---
        const _Section(title: 'X.509 Certificate Parser'),
        _Btn(
          busy: _busy,
          icon: Icons.security,
          label: 'Parse Full X.509',
          subtitle: 'Read cert + parse all fields',
          filled: false,
          onPressed: () => _runValidated('Reading cert...', () async {
            final c = await readCertificate(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            final x = c.parsedCertificate;
            if (x == null) {
              setState(() {
                _status = 'Failed to parse';
                _result = 'Certificate could not be '
                    'parsed from base64.';
              });
              return;
            }
            setState(() {
              _status = 'X.509 v${x.version} parsed!';
              _result = 'Subject DN:\n'
                  '  ${x.subject.distinguishedName}\n'
                  '  CN: ${x.subject.commonName}\n'
                  '  O: ${x.subject.organization}\n'
                  '  C: ${x.subject.country}\n'
                  '  NIF: ${x.subject.serialNumber}\n\n'
                  'Issuer DN:\n'
                  '  ${x.issuer.distinguishedName}\n'
                  '  CN: ${x.issuer.commonName}\n'
                  '  O: ${x.issuer.organization}\n\n'
                  'Serial: ${x.serialNumber}\n'
                  'Algorithm: '
                  '${x.signatureAlgorithmName}\n'
                  'Key: ${x.publicKeyAlgorithm} '
                  '${x.publicKeySize}-bit\n'
                  'Valid: ${x.notValidBefore.toIso8601String()
                      .split('T').first}'
                  ' to ${x.notValidAfter.toIso8601String()
                      .split('T').first}\n'
                  'Self-signed: ${x.isSelfSigned}\n'
                  'Days left: ${x.daysUntilExpiry}\n\n'
                  'Key usage: '
                  '${x.keyUsage.join(', ')}\n'
                  'Ext key usage: '
                  '${x.extendedKeyUsage.join(', ')}\n'
                  'SANs: '
                  '${x.subjectAltNames.join(', ')}\n'
                  'Is CA: ${x.isCA}\n'
                  'OCSP: '
                  '${x.ocspUrls.join(', ')}\n'
                  'CRL: '
                  '${x.crlDistributionPoints.join(', ')}\n'
                  'Policies: '
                  '${x.certificatePolicies.join(', ')}';
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- Workflows ---
        const _Section(title: 'Workflows'),
        _Btn(
          busy: _busy,
          icon: Icons.checklist,
          label: 'Check Readiness',
          subtitle: 'NFC + Probe + PIN',
          filled: false,
          onPressed: () => _runValidated('Checking...', () async {
            final r = await checkReadiness(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status =
                  r.isReady ? 'Ready!' : 'Not ready';
              _result =
                  'NFC: ${r.nfcStatus.statusMessage}\n'
                  'Valid DNIe: ${r.isValidDnie}\n'
                  'PIN OK: ${r.isPinCorrect}'
                  '${r.error != null ? '\nError: ${r.error!.message}' : ''}';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.perm_identity,
          label: 'Read Full Identity',
          subtitle: 'Personal + Certificate (2 taps)',
          filled: false,
          onPressed: () => _runValidated('Reading...', () async {
            final id = await readFullIdentity(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              _status = id.isValid
                  ? 'Identity OK'
                  : 'Cert invalid';
              _result = 'Name: ${id.fullName}\n'
                  'NIF: ${id.nif}\n'
                  'Valid: ${id.isValid}\n'
                  '${id.certificateInfo.expiryStatus}';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.playlist_add_check,
          label: 'Probe + Sign',
          subtitle: 'Probe card then sign if valid',
          filled: false,
          onPressed: () => _runValidated('Probing...', () async {
            final r = await probeAndSign(
              data: utf8.encode('Probe+Sign test'),
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            setState(() {
              if (r != null) {
                _status = 'Probe + Sign OK!';
                _result = 'Complete: ${r.isComplete}\n'
                    'Size: ${r.signatureSizeBytes} bytes';
              } else {
                _status = 'Card is not a valid DNIe.';
              }
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- DnieSession ---
        const _Section(title: 'DnieSession'),
        _Btn(
          busy: _busy,
          icon: Icons.play_circle,
          label: 'Session Demo',
          subtitle: 'Verify + Details + Personal',
          filled: false,
          onPressed: () => _runValidated('Verifying via session...', () async {
            final session = DnieSession(
              can: _can,
              pin: _pin,
              certificateType: _certType,
            );
            await session.verifyCredentials();
            setState(
              () => _status = 'Reading details...',
            );
            final info = await session.certificateDetails();
            setState(
              () => _status = 'Reading personal...',
            );
            final pd = await session.personalData();
            setState(() {
              _status = 'Session complete!';
              _result = 'Name: ${pd.fullName}\n'
                  'NIF: ${pd.nif}\n'
                  '${info.expiryStatus}\n'
                  'Signing OK: ${info.isValidForSigning}';
            });
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await stopSign();
            setState(() => _status = 'Scan stopped.');
          },
          icon: const Icon(Icons.stop),
          label: const Text('Stop Scan'),
        ),
        const SizedBox(height: 24),
        _StatusCard(
          busy: _busy,
          status: _status,
          result: _result,
        ),
      ],
    );
  }
}

// =============================================================================
// Certificates Tab
// =============================================================================

class _CertificatesTab extends StatefulWidget {
  const _CertificatesTab();
  @override
  State<_CertificatesTab> createState() =>
      _CertificatesTabState();
}

class _CertificatesTabState extends State<_CertificatesTab>
    with AutomaticKeepAliveClientMixin {
  String _status = 'Ready';
  String _result = '';
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _result = '';
    });
    try {
      await fn();
    } on certs.CertificateError catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
        _result = '';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  String _fmt(certs.DeviceCertificate c) {
    final l = <String>[
      c.displayName,
      '  Serial: ${c.serialNumber}',
      '  Issuer: ${c.issuerName}',
      '  ${c.expiryStatus}',
      '  Usages: ${c.usageSummary}',
    ];
    if (c.isExpiringSoon) l.add('  ! Expiring soon');
    if (c.canSign) l.add('  + Can sign');
    if (c.canAuthenticate) l.add('  + Can authenticate');
    return l.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _Section(title: 'Certificate Management'),
        _Btn(
          busy: _busy,
          icon: Icons.list,
          label: 'List All Certificates',
          filled: false,
          onPressed: () => _run(() async {
            setState(() => _status = 'Listing...');
            final l = await certs.getAllCertificates();
            setState(() {
              _status = '${l.length} certificate(s).';
              _result = l.isEmpty
                  ? 'No certificates found.\n'
                      'Use "Select" to pick one.'
                  : l.map(_fmt).join('\n\n');
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.touch_app,
          label: 'Select Certificate',
          subtitle: 'Opens system picker',
          onPressed: () => _run(() async {
            setState(() => _status = 'Opening picker...');
            final c =
                await certs.selectDefaultCertificate();
            setState(() {
              if (c != null) {
                _status = 'Selected: ${c.displayName}';
                _result = _fmt(c);
              } else {
                _status = 'No certificate selected.';
              }
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.star,
          label: 'Get Default Certificate',
          onPressed: () => _run(() async {
            setState(() => _status = 'Getting default...');
            final c = await certs.getDefaultCertificate();
            setState(() {
              if (c != null) {
                _status = 'Default: ${c.displayName}';
                _result = _fmt(c);
              } else {
                _status = 'No default certificate set.';
                _result = 'Tap "Select" first.';
              }
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- X.509 Parsing ---
        const _Section(title: 'X.509 Certificate Parser'),
        _Btn(
          busy: _busy,
          icon: Icons.security,
          label: 'Parse Default X.509',
          subtitle: 'Full certificate analysis',
          filled: false,
          onPressed: () => _run(() async {
            setState(() => _status = 'Getting default...');
            final c = await certs.getDefaultCertificate();
            if (c == null) {
              setState(() {
                _status = 'No default set.';
                _result = 'Select a certificate first.';
              });
              return;
            }
            final x = c.parsed;
            if (x == null) {
              setState(() {
                _status = 'Parse failed';
                _result = 'Could not parse DER bytes.';
              });
              return;
            }
            setState(() {
              _status = 'X.509 v${x.version}';
              _result = 'Subject:\n'
                  '  ${x.subject.distinguishedName}\n\n'
                  'Issuer:\n'
                  '  ${x.issuer.distinguishedName}\n\n'
                  'Serial: ${x.serialNumber}\n'
                  'Algorithm: '
                  '${x.signatureAlgorithmName}\n'
                  'Key: ${x.publicKeyAlgorithm} '
                  '${x.publicKeySize}-bit\n'
                  'Self-signed: ${x.isSelfSigned}\n'
                  'Days left: ${x.daysUntilExpiry}\n\n'
                  'Key usage: '
                  '${x.keyUsage.join(', ')}\n'
                  'Ext key usage: '
                  '${x.extendedKeyUsage.join(', ')}\n'
                  'OCSP: ${x.ocspUrls.join(', ')}\n'
                  'CRL: '
                  '${x.crlDistributionPoints.join(', ')}\n'
                  'Is CA: ${x.isCA}\n\n'
                  'PEM (first 120 chars):\n'
                  '${x.pem.substring(0, x.pem.length.clamp(0, 120))}...';
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- Session Pattern ---
        const _Section(title: 'Session Pattern'),
        _Btn(
          busy: _busy,
          icon: Icons.play_arrow,
          label: 'Session: Select + Sign',
          subtitle: 'CertificateSession demo',
          filled: false,
          onPressed: () => _run(() async {
            setState(() => _status = 'Opening picker...');
            final s =
                await certs.CertificateSession.select();
            if (s == null) {
              setState(
                () => _status = 'No cert selected.',
              );
              return;
            }
            final data = utf8.encode('Session test');
            final sig = await s.sign(data);
            setState(() {
              _status = 'Signed via session!';
              _result =
                  'Cert: ${s.certificate.displayName}\n'
                  'Signature: ${sig.length} bytes';
            });
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.replay,
          label: 'Session from Default',
          subtitle: 'No picker, use existing default',
          filled: false,
          onPressed: () => _run(() async {
            final s =
                await certs.CertificateSession.fromDefault();
            if (s == null) {
              setState(() {
                _status = 'No default set.';
                _result = 'Select a certificate first.';
              });
              return;
            }
            final data = utf8.encode('Default session');
            final sig = await s.sign(data);
            setState(() {
              _status = 'Signed from default!';
              _result =
                  'Cert: ${s.certificate.displayName}\n'
                  'Signature: ${sig.length} bytes';
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- Signing ---
        const _Section(title: 'Signing'),
        _Btn(
          busy: _busy,
          icon: Icons.draw,
          label: 'Sign with Default',
          onPressed: () => _run(() async {
            setState(() => _status = 'Signing...');
            final data = utf8.encode('Test data');
            final sig = await certs
                .signWithDefaultCertificate(data);
            setState(() {
              _status = 'Signed!';
              _result = 'Signature: ${sig.length} bytes';
            });
          }),
        ),
        const SizedBox(height: 16),

        // --- Cleanup ---
        const _Section(title: 'Cleanup'),
        _Btn(
          busy: _busy,
          icon: Icons.clear,
          label: 'Clear Default',
          filled: false,
          onPressed: () => _run(() async {
            await certs.clearDefaultCertificate();
            setState(() => _status = 'Default cleared.');
          }),
        ),
        _Btn(
          busy: _busy,
          icon: Icons.delete_outline,
          label: 'Delete Default Certificate',
          filled: false,
          onPressed: () => _run(() async {
            await certs.deleteDefaultCertificate();
            setState(
              () => _status = 'Default cert deleted.',
            );
          }),
        ),
        const SizedBox(height: 24),
        _StatusCard(
          busy: _busy,
          status: _status,
          result: _result,
        ),
      ],
    );
  }
}

// =============================================================================
// Cl@ve Tab
// =============================================================================

class _ClaveTab extends StatefulWidget {
  const _ClaveTab();
  @override
  State<_ClaveTab> createState() => _ClaveTabState();
}

class _ClaveTabState extends State<_ClaveTab>
    with AutomaticKeepAliveClientMixin {
  final _docCtl = TextEditingController();
  final _contrastCtl = TextEditingController();
  String _status = 'Ready';
  String _result = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _docCtl.dispose();
    _contrastCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // --- Document Validator ---
        const _Section(title: 'Document Validator'),
        _CardSection(
          children: [
            TextField(
              controller: _docCtl,
              decoration: const InputDecoration(
                labelText: 'DNI or NIE',
                hintText: 'e.g. 12345678Z',
                border: OutlineInputBorder(),
              ),
              textCapitalization:
                  TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _validateDoc,
              icon: const Icon(Icons.check_circle),
              label: const Text('Validate'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Contrast Validator ---
        const _Section(title: 'Contrast Validator'),
        _CardSection(
          children: [
            TextField(
              controller: _contrastCtl,
              decoration: InputDecoration(
                labelText: _cLabel,
                hintText: _cHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _validateContrast,
              icon: const Icon(Icons.fact_check),
              label: const Text('Validate Contrast'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Support Number ---
        const _Section(title: 'Support Number'),
        _CardSection(
          children: [
            Text(
              'Test values:',
              style:
                  Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _chip(context, 'C12345678', true),
                _chip(context, 'E12345678', true),
                _chip(context, 'A12345678', false),
                _chip(context, 'C1234567', false),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Auth Methods ---
        const _Section(title: 'Cl@ve Auth Methods'),
        _CardSection(
          children: ClaveAuthMethod.values
              .map(
                (m) => ListTile(
                  dense: true,
                  leading: Icon(_icon(m)),
                  title: Text(m.name),
                  subtitle: Text('IDP: ${m.idpValue}'),
                  contentPadding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),

        // --- LOA Levels ---
        const _Section(title: 'LOA Levels'),
        _CardSection(
          children: ClaveLoaLevel.values
              .map(
                (l) => ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.shield,
                    color: switch (l) {
                      ClaveLoaLevel.low => Colors.green,
                      ClaveLoaLevel.medium =>
                        Colors.orange,
                      ClaveLoaLevel.high => Colors.red,
                    },
                  ),
                  title: Text(
                    '${l.name} (Level ${l.value})',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        _StatusCard(
          busy: false,
          status: _status,
          result: _result,
        ),
      ],
    );
  }

  void _validateDoc() {
    final doc = _docCtl.text.trim();
    final error = doc.validateDocument();
    if (error != null) {
      setState(() {
        _status = error.message;
        _result = '';
      });
      return;
    }
    final type = doc.documentType ?? 'Unknown';
    final ct =
        DocumentValidator.contrastTypeFor(doc) ?? '?';
    setState(() {
      _status = 'Valid $type!';
      _result = 'Document: $doc\n'
          'Type: $type\n'
          'Valid: ${doc.isValidDocument}\n'
          'Contrast needed: $ct';
    });
  }

  void _validateContrast() {
    final doc = _docCtl.text.trim();
    final contrast = _contrastCtl.text.trim();
    final isDni = DocumentValidator.isDni(doc);
    final error =
        contrast.validateContrast(isDni: isDni);
    if (error != null) {
      setState(() {
        _status = error.message;
        _result = '';
      });
      return;
    }
    setState(() {
      _status = 'Valid contrast!';
      _result = 'Contrast: $contrast\n'
          'Format: ${isDni ? 'Date' : 'Support number'}';
    });
  }

  Widget _chip(BuildContext ctx, String val, bool valid) {
    return Chip(
      label: Text(
        '$val ${valid ? "valid" : "invalid"}',
        style: Theme.of(ctx).textTheme.bodySmall,
      ),
      avatar: Icon(
        valid ? Icons.check : Icons.close,
        size: 16,
        color: valid ? Colors.green : Colors.red,
      ),
    );
  }

  String get _cLabel {
    final d = _docCtl.text.trim();
    if (DocumentValidator.isDni(d)) return 'Validity Date';
    if (DocumentValidator.isNie(d)) return 'Support Number';
    return 'Contrast (enter document first)';
  }

  String get _cHint {
    final d = _docCtl.text.trim();
    if (DocumentValidator.isDni(d)) return 'dd-MM-yyyy';
    if (DocumentValidator.isNie(d)) return 'C12345678';
    return '';
  }

  IconData _icon(ClaveAuthMethod m) => switch (m) {
        ClaveAuthMethod.clavePin => Icons.pin,
        ClaveAuthMethod.clavePermanente => Icons.lock,
        ClaveAuthMethod.electronicCertificate =>
          Icons.badge,
        ClaveAuthMethod.europeanCredential =>
          Icons.language,
        ClaveAuthMethod.claveMovil => Icons.phone_android,
      };
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _CardSection extends StatelessWidget {
  const _CardSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.icon,
    required this.message,
  });
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: c.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: c.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.busy,
    required this.status,
    required this.result,
  });
  final bool busy;
  final String status;
  final String result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          const Center(child: CircularProgressIndicator())
        else
          Text(
            status,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        if (result.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                result,
                style:
                    Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.busy,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.filled = true,
  });
  final bool busy;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool filled;
  final VoidCallback onPressed;

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
                  style:
                      Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: filled
          ? FilledButton(
              onPressed: busy ? null : onPressed,
              child: child,
            )
          : OutlinedButton(
              onPressed: busy ? null : onPressed,
              child: child,
            ),
    );
  }
}
