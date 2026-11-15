/// API contract - endpoints and shared identities per the agreed contract doc.
/// The demo build never opens a socket; the repository just queues payloads so
/// the future backend swap is a drop-in (implement AstroRepository).
library;

import 'models.dart';

/// identities (not in the demo store yet - see contract section 2)
class ContractIdentity {
  static const String crewId = 'c1';
  static const String missionId = 'm_astrovitals_demo';
  static const String deviceId = 'tablet_flightdeck_1';
}

class Api {
  static const String base = 'https://astrovitals.example/v1';

  static const String readings = '$base/readings'; // POST batch, GET history
  static const String entries = '$base/entries'; // POST manual entry
  static const String status = '$base/status'; // GET levels, alerts, index
  static const String alerts = '$base/alerts'; // GET list
  static String alertAck(String id) => '$base/alerts/$id/ack';
  static String alertStart(String id) => '$base/alerts/$id/start';
  static String alertOverride(String id) => '$base/alerts/$id/override';
  static const String context = '$base/context'; // GET, POST /confirm
  static const String contextConfirm = '$base/context/confirm';
  static const String profiles = '$base/profiles'; // env profiles + rules
  static const String emergency = '$base/emergency'; // POST start
  static String emergencyEvents(String id) => '$base/emergency/$id/events';
  static const String reportsGround = '$base/reports/ground';
  static const String syncQueue = '$base/sync/queue';
  static const String stream = 'wss://astrovitals.example/v1/stream';

  // ---- auth (added with the sign in / sign up pages; same contract style) ----
  static const String authSignup = '$base/auth/signup'; // POST -> session
  static const String authLogin = '$base/auth/login'; // POST -> session
  static const String authLogout = '$base/auth/logout'; // POST
}

/// session returned by the auth endpoints (contract identity envelope)
class AuthSession {
  final String token;
  final String email;
  final String name;
  final String role;
  final int issuedAt; // UTC epoch ms
  const AuthSession({required this.token, required this.email, required this.name, required this.role, required this.issuedAt});

  Map<String, dynamic> toJson() => {
        'token': token,
        'email': email,
        'name': name,
        'role': role,
        'time': issuedAt,
      };
}

/// reading quality derived from device freshness (DEV table) - contract:
/// "No quality field -> add confidence or quality (ok, stale, suspect)".
ReadingQuality qualityForAge(int ageMin) {
  if (ageMin <= 60) return ReadingQuality.ok;
  if (ageMin <= 24 * 60) return ReadingQuality.stale;
  return ReadingQuality.suspect;
}
