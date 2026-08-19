import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose validation answers from a scripted queue.
class _ScriptedRepository implements ClaveRepository {
  _ScriptedRepository(this.script);

  /// Each entry is either a [ClaveAuthResult] to return or a [ClaveError] to
  /// throw.
  final List<Object> script;
  int calls = 0;

  @override
  Future<ClaveAuthResult> validateNotificationCode({
    required ClaveMobileSession session,
  }) async {
    final step = script[calls.clamp(0, script.length - 1)];
    calls++;
    if (step is ClaveAuthResult) return step;
    throw step as ClaveError;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _session = ClaveMobileSession(
  token: 'tok',
  verificationCode: '1234',
  document: '12345678Z',
);

const _fast = Duration(milliseconds: 1);

void main() {
  test('waits while the user has not confirmed, then succeeds', () async {
    final repo = _ScriptedRepository([
      const ClaveIdleError(),
      const ClaveIdleError(),
      const ClaveAuthResult(accessToken: 'at'),
    ]);
    final statuses = await ClaveMobilePoller(repo)
        .poll(session: _session, initialDelay: _fast, interval: _fast)
        .toList();

    expect(statuses.whereType<ClavePollWaiting>(), hasLength(2));
    expect(statuses.last, isA<ClavePollSuccess>());
  });

  test('a terminal error stops the loop', () async {
    final repo = _ScriptedRepository([const ClaveRefusedError()]);
    final statuses = await ClaveMobilePoller(repo)
        .poll(session: _session, initialDelay: _fast, interval: _fast)
        .toList();

    expect(statuses.single, isA<ClavePollError>());
    expect((statuses.single as ClavePollError).error, isA<ClaveRefusedError>());
    expect(repo.calls, 1);
  });

  test('the loop gives up at the timeout', () async {
    final repo = _ScriptedRepository([const ClaveIdleError()]);
    final statuses = await ClaveMobilePoller(repo)
        .poll(
          session: _session,
          initialDelay: _fast,
          interval: const Duration(milliseconds: 5),
          timeout: const Duration(milliseconds: 30),
        )
        .toList();

    expect(statuses.last, isA<ClavePollError>());
    expect(
      (statuses.last as ClavePollError).error,
      isA<ClaveSessionExpiredError>(),
    );
  });

  test('cancelling ends the stream', () async {
    final repo = _ScriptedRepository([const ClaveIdleError()]);
    final poller = ClaveMobilePoller(repo);
    final seen = <ClavePollStatus>[];

    final done = poller
        .poll(
      session: _session,
      initialDelay: _fast,
      interval: const Duration(milliseconds: 5),
      timeout: const Duration(seconds: 10),
    )
        .forEach((s) {
      seen.add(s);
      if (seen.length == 2) poller.cancel();
    });

    await done;
    expect(seen, hasLength(2));
  });

  test('two concurrent polls do not un-cancel each other', () async {
    // The previous single-flag design reset cancellation at the top of poll(),
    // so starting a second poll revived the first.
    final poller = ClaveMobilePoller(
      _ScriptedRepository([const ClaveIdleError()]),
    );

    final first = poller
        .poll(
          session: _session,
          initialDelay: _fast,
          interval: const Duration(milliseconds: 5),
          timeout: const Duration(seconds: 10),
        )
        .take(1)
        .toList();
    final second = poller
        .poll(
          session: _session,
          initialDelay: _fast,
          interval: const Duration(milliseconds: 5),
          timeout: const Duration(seconds: 10),
        )
        .take(1)
        .toList();

    expect((await first).single, isA<ClavePollWaiting>());
    expect((await second).single, isA<ClavePollWaiting>());

    poller.cancel();
  });
}
