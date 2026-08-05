import 'dart:convert';
import 'package:bla_flutter_app/data/sources/remote/api_data_source_interface.dart';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiDiariesDataSource implements APIDataSourceInterface {
  final String baseUrl = APIStrings.baseUrl;

  @override
  Future<Map<String, dynamic>> fetchData({
    String cookies = "",
    List<String>? params,
    bool shouldDownloadJson = false,
    String? userId,
    String? accessToken,
  }) async {
    var url =
        '${baseUrl}?endpoint=apiDiaryList&rnd=1767540592954&accessToken=$accessToken&userId=$userId';

    // ✅ FIX: Join parameters correctly with '&'
    if (params != null && params.isNotEmpty) {
      url += "&${params.join('&')}";
    }

    // print("diaries fetchData() - url :$url");
    var uri = Uri.parse(url);
    DateTime start = DateTime.now();
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        "Connection": "keep-alive",
        'Cookie': cookies,
      },
    );
    // print("Diaries fetchData() - response code :${response.statusCode}, body: ${response.body}");
    if (response.statusCode == 200) {
      // print("diaries fetchData() - response received, parsing data...response.body: ${response.body}");
      var dataList = jsonDecode(response.body)['data'] as List<dynamic>;
      List<DiaryModel> list =
          dataList.map((c) => DiaryModel.fromMap(c)).toList();
      List<BaseModel> convertedDataList = <BaseModel>[];
      convertedDataList = list;
      // print("diaries fetchData() - fetched ${convertedDataList.length} records");
      //Calculate downloading time
      DateTime end = DateTime.now();
      debugPrint(
          "${runtimeType.toString()} downloading time ${end.difference(start).toString()}");

      var date = response.headers["date"];
      return {"date": date, "dataList": convertedDataList};
    } else {
      throw Exception(
          'Failed to fetch ${runtimeType.toString()}. Response code: ${response.statusCode} body:${response.body} request: ${response.request.toString()}');
    }
  }

  Future<Map<String, dynamic>> postData(
      {required String cookies,
      required String endPoint,
      required String body}) async {
    var url = '$baseUrl$endPoint';

    var uri = Uri.parse(url);
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        "Connection": "keep-alive",
        'Cookie': cookies,
      },
      body: body,
    );
    if (response.statusCode == 200) {
      var dataList = jsonDecode(response.body)['data'] as List<dynamic>;
      var date = response.headers["date"];
      return {"date": date, "dataList": dataList};
    } else {
      throw Exception('Failed to fetch colors. ');
    }
  }
}
