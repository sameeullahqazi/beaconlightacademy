import 'dart:async';
import 'dart:convert';

import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:http/http.dart' as http;

import '../data/sources/api_client.dart';

// Phase 2 (v9 security, gap #9): lets a caller distinguish "the server
// genuinely rejected these credentials" from "couldn't reach the server/
// parse its response" - login() previously returned a bare null for both,
// which is exactly what let tryAutoLogin() silently keep running on a
// stale session after a real password rejection (e.g. changed elsewhere).
//
// verificationRequired (OTP new-device gate, v9 security): the password
// was correct but this (userId, deviceId) pair has never completed phone
// verification - the server deliberately withheld tokens rather than
// rejecting the login outright, so this is NOT an error state the way
// invalidCredentials is.
enum LoginFailureReason {
  none,
  networkError,
  invalidCredentials,
  verificationRequired,
}

class AuthService {
  final String _baseUrl;
  String cookieValue = "";
  String? userId;
  String? accessToken;
  // Phase 2: the long-lived token used to silently mint a new accessToken
  // once the current one's 24h 'exp' claim passes, without a full
  // username+password login. Set on every successful login()/refresh().
  String? refreshToken;
  LoginFailureReason lastLoginFailureReason = LoginFailureReason.none;
  // OTP new-device gate: set alongside LoginFailureReason.verificationRequired
  // so the caller knows which account/device to carry into the Firebase
  // Phone Auth flow and the verifyDeviceOTP() call that follows it.
  String? pendingVerificationUserId;
  String? pendingVerificationDeviceId;
  Timer? _keepUserLoggedInTimer;
  APIClient _apiClient = APIClient(APIStrings.baseUrl);

  AuthService(this._baseUrl);

  // [deviceId] is optional so every existing call site keeps working
  // untouched if it doesn't pass one - but every real Flutter call site
  // should pass it (see login_controller.dart) so the backend can tell
  // this login apart from the Vue web app / admin panel, which never send
  // it. Without a deviceId, the OTP new-device gate never activates for
  // this call, same as today.
  Future<UserModel?> login(String username, String password,
      {String? deviceId}) async {
    // String url = '${APIStrings.baseUrl}${APIStrings.loginAPI}?username=$username&password=$password&companyId=1&referer=2';
    String url =
        "${APIStrings.baseUrl}?endpoint=login&rnd=1761395747335&username=$username&password=$password";
    if (deviceId != null && deviceId.isNotEmpty) {
      url += "&platform=mobile&deviceId=$deviceId";
    }
    // print("auth_service login url: $url");
    lastLoginFailureReason = LoginFailureReason.none;
    pendingVerificationUserId = null;
    pendingVerificationDeviceId = null;
    try {
      var response = await http.post(Uri.parse(url), headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      });

      // print("login() - url: $url, body: ${response.body}, headers: ${response.headers}, statusCode: ${response.statusCode}");

      final Map<String, dynamic> bodyMap = jsonDecode(response.body);
      // print("bodyMap: $bodyMap");

      if (response.headers['set-cookie'] != null) {
        cookieValue = response.headers['set-cookie'].toString();
      }
      // print("login() - cookieValue: $cookieValue");

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          bodyMap["success"]) {
        final data = bodyMap["data"];
        // OTP new-device gate: the password was right, but the server
        // deliberately withheld tokens for this unrecognized device - must
        // be checked BEFORE UserModel.fromJson(), which would otherwise
        // happily parse this minimal {id, requiresVerification} shape into
        // a mostly-empty, tokenless "user" that callers would wrongly
        // treat as a successful login.
        if (data?["requiresVerification"] == true) {
          lastLoginFailureReason = LoginFailureReason.verificationRequired;
          pendingVerificationUserId = data["id"]?.toString();
          pendingVerificationDeviceId = deviceId;
          return null;
        }
        UserModel user = UserModel.fromJson(data);
        userId = user.id;
        accessToken = user.accessToken;
        refreshToken = data?["refreshToken"];
        return user;
      }
      // The server responded (we got this far without throwing) but said
      // no - a genuine rejection, not a connectivity problem.
      lastLoginFailureReason = LoginFailureReason.invalidCredentials;
      return null;
    } catch (e, stackTrace) {
      print(
          "Exception in AuthService: ${e.toString()}, stackTrace: $stackTrace");
      lastLoginFailureReason = LoginFailureReason.networkError;
      return null;
    }
  }

  // OTP new-device gate: completes verification after the Flutter client
  // has already successfully finished Firebase Phone Auth itself - this
  // call hands the resulting Firebase ID token to our OWN backend, which
  // independently re-verifies it server-side before trusting this device
  // or issuing any token (see classes/API.class.php's verifyDeviceOTP()
  // for why a bare client-side "it worked" can never be trusted alone).
  Future<UserModel?> verifyDeviceOTP(
      String userId, String deviceId, String firebaseIdToken) async {
    final url = "${APIStrings.baseUrl}?endpoint=verifyDeviceOTP";
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'deviceId': deviceId,
          'firebaseIdToken': firebaseIdToken,
        }),
      );
      final Map<String, dynamic> bodyMap = jsonDecode(response.body);
      if (response.statusCode == 200 && bodyMap["success"] == true) {
        final data = bodyMap["data"];
        UserModel user = UserModel.fromJson(data);
        this.userId = user.id;
        accessToken = user.accessToken;
        refreshToken = data?["refreshToken"];
        return user;
      }
      return null;
    } catch (e, stackTrace) {
      print(
          "Exception in AuthService.verifyDeviceOTP(): ${e.toString()}, stackTrace: $stackTrace");
      return null;
    }
  }

  // Phase 2: exchanges the stored refresh token for a fresh access token +
  // a new refresh token (the backend rotates on every use), without
  // needing the user's password. Returns false if the refresh token is
  // missing, revoked (e.g. password changed elsewhere), or the request
  // fails for any reason - callers should fall back to a full password
  // login in that case, same as if no refresh token had ever been stored.
  Future<bool> refreshAccessToken(String token) async {
    final url = "${APIStrings.baseUrl}?endpoint=refreshToken";
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': token}),
      );
      final Map<String, dynamic> bodyMap = jsonDecode(response.body);
      if (response.statusCode == 200 && bodyMap["success"] == true) {
        accessToken = bodyMap["data"]["accessToken"];
        refreshToken = bodyMap["data"]["refreshToken"];
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      print(
          "Exception in AuthService.refreshAccessToken(): ${e.toString()}, stackTrace: $stackTrace");
      return false;
    }
  }

  void startKeepUserLoggedInScheduler() async {
    _keepUserLoggedInTimer?.cancel();
    _keepUserLoggedInTimer =
        Timer.periodic(Duration(minutes: 1), (Timer t) async {
      try {
        // Make the HTTP GET request
        await _apiClient.get(
          endPoint: APIStrings.getKeepUserLoggedIn,
          cookies: cookieValue,
          shouldIncludeContentType: false,
        );
        // print("${APIClient.classLogName} refresh session at ${DateTime.now().toIso8601String()}");
      } catch (e, stackTrace) {
        print('Error calling API: $e, stackTrace: $stackTrace');
      }
    });
  }

  Map<String, String> getAuthHeader() {
    return <String, String>{
      "Cookie": cookieValue,
    };
  }

  dispose() {
    _keepUserLoggedInTimer?.cancel();
  }

  void setCredentials({
    required String userId,
    String? accessToken,
    cookie,
  }) {
    this.userId = userId;
    this.accessToken = accessToken;
    cookieValue = cookie;
  }
}
