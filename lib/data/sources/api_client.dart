import 'dart:convert';
import 'dart:io';
import 'package:bla_flutter_app/data/errors/api/response_failure.dart';
import 'package:bla_flutter_app/data/errors/api/unauthorized_exception.dart';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/helpers.dart';

class APIClient {
  final String baseUrl;
  static const classLogName = "APIClient:";

  APIClient(this.baseUrl);

  Future<Map<String, dynamic>> get({
    required String endPoint,
    List<String>? params,
    String cookies = "",
    bool shouldIncludeContentType = true,
    String? fullUrl,
    bool? bIncludeCredentials,
  }) async {
    var url = fullUrl ?? '${APIStrings.baseUrl}$endPoint';

    if (params != null && params.isNotEmpty) {
      url += "?${params.join('&')}";
    }
    // print("APIClient::get() - url: $url");
    var uri = Uri.parse(url);

    var headers = <String, String>{};

    headers.addIf(shouldIncludeContentType, 'Content-Type', 'application/json');

    headers.addIf(cookies.isNotEmpty, 'Cookie', cookies);

    headers.addIf(bIncludeCredentials ?? false, 'credentials', 'include');

    final response = await http.get(
      uri,
      headers: headers,
    );
    if (response.statusCode == 200) {
      if (!isJsonDecodable(response.body)) {
        return {"date": response.body};
      }
      var decodedBody = jsonDecode(response.body);
      if (decodedBody["success"] == false) {
        throw ResponseFailureException(
            '$endPoint API Response has failure with message: ${decodedBody["message"]}');
      }
      // var dataList = decodedBody['data'] as List<dynamic>;
      // // Here you need to adjust the conversion based on your BaseModel implementation
      // // List<BaseModel> convertedDataList = dataList.map((c) => ColorModel.fromMap(c)).toList();
      // var date = response.headers["date"];
      return decodedBody;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('$endPoint is not authorized.');
    } else {
      throw Exception(
          'Failed to fetch ${runtimeType.toString()}. Response code: ${response.statusCode} body:${response.body} request: ${response.request.toString()}');
    }
  }

  Future<Map<String, dynamic>> post({
    required String endPoint,
    required String body,
    required String cookies,
    String? uploadFilename,
    String? accessToken,
  }) async {
    var url = '${APIStrings.baseUrl}?endpoint=$endPoint';
    if (accessToken != null) {
      url += "&accessToken=$accessToken";
    }
    // print("APIClient::post() - uploadFilename: $uploadFilename, url: $url");
    var response;
    if (uploadFilename == null) {
      var uri = Uri.parse(url);

      response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          "Connection": "keep-alive",
          'Cookie': cookies,
        },
        body: body,
      );
    } else {
      String userName = (await getLoggedInTopUser()).username!;
      Directory appDocDir = Platform.isIOS
          ? await getLibraryDirectory()
          : await getApplicationCacheDirectory();
      String filename = join(
        '${appDocDir.path}/${APIStrings.env}/$userName',
        uploadFilename,
      );
      // print("filename $filename exists: ${await File(filename).exists()}");
      var request = http.MultipartRequest('POST', Uri.parse(url));
      Map<String, String> headers = {
        "Content-type": "multipart/form-data",
        "Cookie": cookies,
      };
      request.headers.addAll(headers);
      request.files.add(
        http.MultipartFile.fromBytes(
          'body',
          File(filename).readAsBytesSync(),
          filename: uploadFilename.split("/").last, // filename.split("/").last,
        ),
      );
      var res = await request.send();
      response = await http.Response.fromStream(res);
    }
    if (response.statusCode == 200) {
      //Check if it is a decodable object otherwise it is a date
      if (!isJsonDecodable(response.body)) {
        return {"date": response.body};
      }

      var decodedBody = jsonDecode(response.body);
      // print("post() - response.body: ${response.body}");
      if (decodedBody["success"] == false) {
        throw ResponseFailureException(
            '$endPoint API Response has failure with message: ${decodedBody["error"]}');
      }
      // var dataList = jsonDecode(response.body)['data'] as List<dynamic>;
      // var date = response.headers["date"];
      return decodedBody;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('$endPoint is not authorized.');
    } else {
      print(
          "$classLogName Response: ${response.statusCode.toString()} ${response.body.toString()}");
      throw Exception('Failed to post to API. ');
    }
  }

  Future<File> downloadZipFile(
    String url,
    String cookies, {
    String? pathName,
    String? fileName,
  }) async {
    try {
      // Send HTTP GET request
      var response = await http.get(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/zip',
          "Connection": "keep-alive",
          'Cookie': cookies,
        },
      );

      // Check if response is successful (status code 200)
      if (response.statusCode == 200) {
        Directory tempDir = await getTemporaryDirectory();
        if (!await tempDir.exists()) {
          await tempDir.create(recursive: true);
        }
        fileName = fileName ?? "temp.zip";
        pathName = pathName ?? tempDir.path;
        // print("downloadZipFile() - fileName: $fileName, pathName: $pathName");
        // var savePath = join(tempDir.path, "temp.zip");
        var savePath = join(pathName, fileName);
        // Open a file for writing
        File file = File(savePath);

        // print('File downloaded successfully: $savePath');
        return await file.writeAsBytes(response.bodyBytes);
      } else {
        print('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading file: $e');
    }
    throw Exception("$url failed to download json file");
  }
}
