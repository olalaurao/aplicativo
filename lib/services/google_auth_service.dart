// lib/services/google_auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveScope,
      drive
          .DriveApi
          .driveAppdataScope, // or driveFileScope depending on if we want visible folder or appDataFolder
      drive.DriveApi.driveFileScope,
      calendar.CalendarApi.calendarScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  AuthClient? _authClient;
  DateTime? _authClientExpiresAt;

  Future<AuthClient?> ensureClient({bool forceRefresh = false}) async {
    final expiresAt = _authClientExpiresAt;
    final hasFreshClient =
        _authClient != null &&
        expiresAt != null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
    if (!forceRefresh && hasFreshClient) return _authClient;

    _authClient?.close();
    _authClient = null;
    _authClientExpiresAt = null;

    // When forceRefresh is true, use signIn() to get fresh tokens
    // signInSilently() may return cached expired tokens
    _currentUser = forceRefresh
        ? await _googleSignIn.signIn()
        : await _googleSignIn.signInSilently();
    if (_currentUser == null) return null;
    final headers = await _currentUser!.authHeaders;
    _authClientExpiresAt = DateTime.now().toUtc().add(
      const Duration(minutes: 55),
    );
    _authClient = GoogleAuthClient(
      headers,
      http.Client(),
      _authClientExpiresAt!,
    );
    return _authClient;
  }

  Future<AuthClient?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return null;

      final headers = await _currentUser!.authHeaders;
      _authClient?.close();
      _authClientExpiresAt = DateTime.now().toUtc().add(
        const Duration(minutes: 55),
      );
      _authClient = GoogleAuthClient(
        headers,
        http.Client(),
        _authClientExpiresAt!,
      );
      return _authClient;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    _authClient?.close();
    _authClient = null;
    _authClientExpiresAt = null;
  }

  AuthClient? get authClient => _authClient;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
}

class GoogleAuthClient extends http.BaseClient implements AuthClient {
  final Map<String, String> _headers;
  final http.Client _client;
  final DateTime _expiresAt;
  late final AccessCredentials _credentials;

  GoogleAuthClient(this._headers, this._client, this._expiresAt) {
    final authorization =
        _headers['Authorization'] ?? _headers['authorization'] ?? '';
    final token = authorization.startsWith('Bearer ')
        ? authorization.substring('Bearer '.length)
        : authorization;
    _credentials = AccessCredentials(
      AccessToken('Bearer', token, _expiresAt),
      null,
      const [],
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  AccessCredentials get credentials => _credentials;
}
