import 'dart:async';
import 'dart:convert';

import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:http/http.dart' as http;

import '../data/sources/api_client.dart';

class AuthService {
  final String _baseUrl;
  String cookieValue = "";
  String? userId;
  String? accessToken;
  Timer? _keepUserLoggedInTimer;
  APIClient _apiClient = APIClient(APIStrings.baseUrl);

  AuthService(this._baseUrl);

  Future<UserModel?> login(String username, String password) async {
    // String url = '${APIStrings.baseUrl}${APIStrings.loginAPI}?username=$username&password=$password&companyId=1&referer=2';
    String url =
        "${APIStrings.baseUrl}?endpoint=login&rnd=1761395747335&username=$username&password=$password";
    // print("auth_service login url: $url");
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
        UserModel user = UserModel.fromJson(bodyMap["data"]);
        userId = user.id;
        accessToken = user.accessToken;
        return user;
      }
      return null;
    } catch (e, stackTrace) {
      print(
          "Exception in AuthService: ${e.toString()}, stackTrace: $stackTrace");
      return null;
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
