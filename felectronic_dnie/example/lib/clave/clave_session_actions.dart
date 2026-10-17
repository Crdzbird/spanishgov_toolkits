import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:felectronic_dnie_example/clave/token_preview.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:flutter/foundation.dart';

/// Signing in and managing the stored session, keeping the signed-in flag
/// current.
final class ClaveSessionActions {
  const factory ClaveSessionActions(
    ClaveRepository clave,
    ValueNotifier<bool> signedIn,
  ) = ClaveSessionActions._;

  const ClaveSessionActions._(this._clave, this._signedIn);

  final ClaveRepository _clave;
  final ValueNotifier<bool> _signedIn;

  Future<DemoStatus> login(ClaveAuthMethod method, ClaveLoaLevel loa) async {
    final result = await _clave.login(method: method, loa: loa);
    _signedIn.value = true;
    final nif = _clave.getNifFromToken(result.accessToken);
    return DemoStatus(
      'Signed in with ${method.name}',
      detail:
          'NIF: ${nif.isEmpty ? 'not in the token' : nif}\n'
          'Access token: ${result.accessToken.tokenPreview}\n'
          'Refresh token: ${result.refreshToken == null ? 'none' : 'yes'}\n'
          'Expires in: ${result.expiresIn ?? '?'} s',
    );
  }

  Future<DemoStatus> storedToken() async {
    final token = await _clave.getStoredToken();
    if (token == null) return const DemoStatus('No token stored');
    final claims = JwtParser.parsePayload(token) ?? const {};
    return DemoStatus(
      token.tokenPreview,
      detail: [
        for (final key in ['preferred_username', 'name', 'loa', 'exp', 'iss'])
          if (claims[key] != null) '$key: ${claims[key]}',
      ].join('\n'),
    );
  }

  Future<DemoStatus> validate() async {
    final info = await _clave.validateToken();
    _signedIn.value = info.isNotEmpty;
    if (info.isEmpty) return const DemoStatus.error('The gateway refused it');
    return DemoStatus(
      'The gateway accepts the token',
      detail: info.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
  }

  Future<DemoStatus> refresh() async {
    final token = await _clave.refreshToken();
    _signedIn.value = token != null;
    if (token == null) return const DemoStatus.error('The refresh was spent');
    return DemoStatus('Refreshed', detail: token.tokenPreview);
  }

  Future<DemoStatus> logout() async {
    await _clave.logout();
    _signedIn.value = false;
    return const DemoStatus('Signed out');
  }
}
