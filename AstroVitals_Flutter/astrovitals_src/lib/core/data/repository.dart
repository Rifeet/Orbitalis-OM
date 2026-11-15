/// Repository layer - the contract-facing data layer.
///
/// The demo build runs fully offline: every payload the app would send to the
/// back end goes through [SyncQueue] (with client id + seq + dedupe), and
/// [DemoRepository] logs it. Swapping to the real backend means implementing
/// AstroRepository against the Api endpoints - no UI changes needed.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../contract/api_contract.dart';
import '../contract/models.dart';

class QueuedItem {
  final String id;
  final int seq;
  final String kind; // reading | entry | alert_action | emergency | report
  final Map<String, dynamic> payload;
  final int time; // epoch ms
  final String endpoint;
  const QueuedItem(this.id, this.seq, this.kind, this.payload, this.time, this.endpoint);

  Map<String, dynamic> toJson() => {
        'id': id, 'seq': seq, 'kind': kind, 'payload': payload,
        'time': time, 'endpoint': endpoint,
      };
}

/// Offline send queue with duplicate protection (contract section 2:
/// "Send queue - what is waiting to go to Earth, and its status" and
/// "Validation: duplicate check").
class SyncQueue extends ChangeNotifier {
  final Map<String, QueuedItem> _items = {}; // dedupe by client id
  int _seq = 1000;
  int sentCount = 0;

  List<QueuedItem> get items => _items.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  int get pendingCount => _items.length;

  String nextId(String prefix) {
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = (_seq * 7919) % 1299709;
    return '${prefix}_01${t}x${r.toRadixString(36)}';
  }

  /// enqueue a payload; returns false when a duplicate id is detected
  bool enqueue(String kind, String id, Map<String, dynamic> payload, String endpoint) {
    if (_items.containsKey(id) || _sentIds.contains(id)) return false;
    _items[id] = QueuedItem(id, ++_seq, kind, payload,
        DateTime.now().millisecondsSinceEpoch, endpoint);
    notifyListeners();
    return true;
  }

  final Set<String> _sentIds = {};

  /// pretend to send the queue (demo). Real backend: POST each item.
  Future<void> flush() async {
    if (_items.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    sentCount += _items.length;
    for (final it in _items.values) {
      debugPrint('[sync] POST ${it.endpoint} (${it.kind}) id=${it.id} seq=${it.seq}');
      _sentIds.add(it.id);
    }
    _items.clear();
    notifyListeners();
  }
}

/// contract interface - implement this against the real back end.
abstract class AstroRepository {
  SyncQueue get queue;
  void postReadings(List<Reading> readings);
  void postEntry(CrewEntry entry);
  void postAlertAction(String alertId, String action, {String? reason, int? time});
  void postEmergencyStart(String type, int time);
  void postEmergencyEvent(String emergencyId, String kind, String key, dynamic value);
  void postContextConfirm(String suggested, String answer, Map<String, dynamic> signals);
  AuthResult authSignIn(String email, String password);
  AuthResult authSignUp(String name, String role, String email, String password);
  void authSignOut();
}

/// auth request result (ok + session, or an error message for the form)
class AuthResult {
  final bool ok;
  final AuthSession? session;
  final String? error;
  const AuthResult.ok(this.session) : ok = true, error = null;
  const AuthResult.err(this.error) : ok = false, session = null;
}

class DemoRepository implements AstroRepository {
  @override
  final SyncQueue queue = SyncQueue();

  @override
  void postReadings(List<Reading> readings) {
    for (final r in readings) {
      queue.enqueue('reading', r.id, r.toJson(), Api.readings);
    }
  }

  @override
  void postEntry(CrewEntry e) {
    queue.enqueue('entry', e.id, e.toJson(), Api.entries);
  }

  @override
  void postAlertAction(String alertId, String action, {String? reason, int? time}) {
    final body = <String, dynamic>{'time': time ?? DateTime.now().millisecondsSinceEpoch};
    if (reason != null) body['reason'] = reason;
    final ep = action == 'ack'
        ? Api.alertAck(alertId)
        : action == 'start'
            ? Api.alertStart(alertId)
            : Api.alertOverride(alertId);
    queue.enqueue('alert_action', '${action}_$alertId', body, ep);
  }

  @override
  void postEmergencyStart(String type, int time) {
    queue.enqueue('emergency', 'em_${type}_$time', {'type': type, 'time': time}, Api.emergency);
  }

  @override
  void postEmergencyEvent(String emergencyId, String kind, String key, dynamic value) {
    queue.enqueue('emergency_event', 'ev_$emergencyId$key',
        {'kind': kind, 'key': key, 'value': value}, Api.emergencyEvents(emergencyId));
  }

  @override
  void postContextConfirm(String suggested, String answer, Map<String, dynamic> signals) {
    queue.enqueue('context', 'ctx_$suggested',
        {'suggested': suggested, 'answer': answer, 'signals': signals}, Api.contextConfirm);
  }

  // ---- auth: the demo gateway validates locally and queues the payload.
  // A real backend returns a session token from Api.authLogin / Api.authSignup.
  @override
  AuthResult authSignIn(String email, String password) {
    final err = _authGateError(email, password);
    if (err != null) return AuthResult.err(err);
    final session = AuthSession(
      token: queue.nextId('tok'),
      email: email.toLowerCase(),
      name: profileNameFallback,
      role: 'Flight engineer',
      issuedAt: DateTime.now().millisecondsSinceEpoch,
    );
    queue.enqueue('auth', 'login_${session.issuedAt}', {
      'email': email.toLowerCase(), 'password': '***', 'time': session.issuedAt,
    }, Api.authLogin);
    return AuthResult.ok(session);
  }

  @override
  AuthResult authSignUp(String name, String role, String email, String password) {
    final err = _authGateError(email, password);
    if (err != null) return AuthResult.err(err);
    final session = AuthSession(
      token: queue.nextId('tok'),
      email: email.toLowerCase(),
      name: name,
      role: role,
      issuedAt: DateTime.now().millisecondsSinceEpoch,
    );
    queue.enqueue('auth', 'signup_${session.issuedAt}', {
      'name': name, 'role': role, 'email': email.toLowerCase(), 'password': '***',
      'time': session.issuedAt,
    }, Api.authSignup);
    return AuthResult.ok(session);
  }

  @override
  void authSignOut() {
    queue.enqueue('auth', 'logout_${DateTime.now().millisecondsSinceEpoch}',
        {'time': DateTime.now().millisecondsSinceEpoch}, Api.authLogout);
  }

  /// format gate shared by both auth endpoints (demo: no stored accounts)
  String? _authGateError(String email, String password) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Password needs 8+ characters with letters and numbers.';
    }
    return null;
  }

  /// shown in the demo session envelope when no sign-up name is known
  static const String profileNameFallback = 'Lena Ortiz';
}
