import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Central HTTP client that attaches the Firebase ID token to every request.
///
/// NFR-SEC-02: The Fireworks AI API key lives only on the backend.
///             This client never includes it — it only sends the Firebase token
///             so the backend can verify the caller's identity (FR-AUTH-05).
///
/// Usage:
///   final response = await BackendService.instance.post(
///     '/events',
///     body: {...},
///   );
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  /// Base URL of the FastAPI backend.
  /// In dev: http://10.0.2.2:8000 (Android emulator → host machine)
  ///         http://localhost:8000  (web/desktop)
  /// Override via environment at build time if needed.
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://eventflow-backend-3x0m.onrender.com',
  );

  /// Get the current user's Firebase ID token (auto-refreshed when needed).
  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// POST to [path] with JSON [body]. Returns the decoded response body.
  /// Throws [BackendException] on non-2xx responses.
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = await _getIdToken();
    if (token == null) throw BackendException(401, 'Not authenticated');

    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  /// GET from [path]. Returns decoded response body.
  Future<Map<String, dynamic>> get(String path) async {
    final token = await _getIdToken();
    if (token == null) throw BackendException(401, 'Not authenticated');

    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.get(uri, headers: _headers(token));
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final rawBody = response.body.isEmpty ? '{}' : response.body;

    // Guard: backend sometimes returns an HTML error page (e.g. 502/503 from
    // the hosting proxy, or an unhandled 500). jsonDecode would throw a
    // FormatException in that case and swallow the real status code.
    // Parse safely and fall back to a plain-text detail message.
    dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      // Non-JSON body (HTML, plain text) — wrap it so callers get a clean error
      decoded = <String, dynamic>{
        'detail': 'Server error (${response.statusCode}): '
            '${rawBody.length > 200 ? rawBody.substring(0, 200) : rawBody}',
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }

    final detail = decoded is Map
        ? (decoded['detail'] ?? 'Unknown error')
        : rawBody;
    throw BackendException(response.statusCode, detail.toString());
  }
}

/// Thrown when the backend returns a non-2xx response.
class BackendException implements Exception {
  final int statusCode;
  final String message;
  BackendException(this.statusCode, this.message);

  @override
  String toString() => 'BackendException($statusCode): $message';
}
