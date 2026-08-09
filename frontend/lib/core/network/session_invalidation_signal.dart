import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionInvalidationSignalProvider = Provider<SessionInvalidationSignal>((
  ref,
) {
  final signal = SessionInvalidationSignal();
  ref.onDispose(signal.dispose);

  return signal;
});

class SessionInvalidationSignal {
  final _controller = StreamController<SessionInvalidationEvent>.broadcast();

  Stream<SessionInvalidationEvent> get stream => _controller.stream;

  void authenticationRequired({required int tokenVersion}) {
    if (_controller.isClosed) {
      return;
    }

    _controller.add(
      SessionInvalidationEvent(
        reason: SessionInvalidationReason.authenticationRequired,
        tokenVersion: tokenVersion,
      ),
    );
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class SessionInvalidationEvent {
  const SessionInvalidationEvent({
    required this.reason,
    required this.tokenVersion,
  });

  final SessionInvalidationReason reason;
  final int tokenVersion;
}

enum SessionInvalidationReason { authenticationRequired }
