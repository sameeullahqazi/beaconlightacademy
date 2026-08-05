import 'dart:convert';
import 'package:bla_flutter_app/data/sources/remote/api_data_source_interface.dart';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/models/class_model.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

class ApiClassesDataSource implements APIDataSourceInterface {
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
        '${baseUrl}?endpoint=apiClassList&rnd=1767540592954&accessToken=$accessToken&userId=$userId';

    // ✅ FIX: Join parameters correctly with '&'
    if (params != null && params.isNotEmpty) {
      url += "&${params.join('&')}";
    }

    // print("classes fetchData() - url :$url");
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
    // print("classes fetchData() - response code :${response.statusCode}, body: ${response.body}");
    if (response.statusCode == 200) {
      var dataList = response.body.isNotEmpty
          ? jsonDecode(response.body)['data'] as List<dynamic>
          : [];
      List<ClassModel> list =
          dataList.map((c) => ClassModel.fromMap(c)).toList();
      List<BaseModel> convertedDataList = <BaseModel>[];
      convertedDataList = list;
      print(
          "classes fetchData() - fetched ${convertedDataList.length} records");
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
}
