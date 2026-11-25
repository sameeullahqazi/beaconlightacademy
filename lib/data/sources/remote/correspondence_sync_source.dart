import 'dart:convert';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/models/correspondence_model.dart';
import 'package:bla_flutter_app/models/correspondence_message_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Deliberately does NOT implement APIDataSourceInterface, same reasoning as
// ApiReportCard6PlusDataSource - apiCorrespondenceSync's response is a
// composite {"correspondences": [...], "messages": [...]}, not the single
// flat list that interface's contract assumes. Replaces the old two-call
// ApiCorrespondencesDataSource/ApiCorrespondenceMessagesDataSource pair
// (see project_correspondence_sync_optimization_2026_11_25 memory) with one
// endpoint cursored purely on message.created.
class ApiCorrespondenceSyncDataSource {
  final String baseUrl = APIStrings.baseUrl;

  Future<Map<String, List<dynamic>>> fetchCorrespondenceSync({
    String cookies = "",
    String? modifiedDate,
    String? userId,
    String? accessToken,
  }) async {
    var url =
        '$baseUrl?endpoint=apiCorrespondenceSync&accessToken=$accessToken&userId=$userId';
    if (modifiedDate != null && modifiedDate.isNotEmpty) {
      url += "&modifiedDate=$modifiedDate";
    }

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
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
      List<CorrespondenceModel> correspondences =
          (data['correspondences'] as List<dynamic>)
              .map((c) => CorrespondenceModel.fromMap(c))
              .toList();
      List<CorrespondenceMessageModel> messages =
          (data['messages'] as List<dynamic>)
              .map((m) => CorrespondenceMessageModel.fromMap(m))
              .toList();

      DateTime end = DateTime.now();
      debugPrint(
          "${runtimeType.toString()} downloading time ${end.difference(start).toString()}");

      return {"correspondences": correspondences, "messages": messages};
    } else {
      throw Exception(
          'Failed to fetch ${runtimeType.toString()}. Response code: ${response.statusCode} body:${response.body} request: ${response.request.toString()}');
    }
  }
}
