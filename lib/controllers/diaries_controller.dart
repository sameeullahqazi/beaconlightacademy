import 'dart:async';

import 'package:bla_flutter_app/data/repositories/data_repository.dart';
import 'package:bla_flutter_app/data/sources/remote/diaries_source.dart';
import 'package:bla_flutter_app/models/diary_model.dart';
import 'package:bla_flutter_app/services/data_sync_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:bla_flutter_app/constants/table_names_strings.dart';

class ColorLibraryController with ChangeNotifier {
  final DataRepository _dataRepository;
  late ApiDiariesDataSource _colorDataSource;
  late Stream<List<DiaryModel>> diaryStream;
  StreamController<List<DiaryModel>> streamController =
      StreamController.broadcast();

  List<Map<String, dynamic>> _selectedColorData = [];

  List<Map<String, dynamic>> get getSelectedColorData => _selectedColorData;

  ApiDiariesDataSource get getColorsDataSource => _colorDataSource;

  ColorLibraryController(this._dataRepository);

  Future<void> saveReadNotification(int id) async {
    try {
      // Save locally
      await _dataRepository
          .rawQuery("update diaries set bRead = 1, bLocal = 1 where id = $id");

      // ToDos: Add backend api endpoint to post_api_queue
/*
      var request =
          "${APIStrings.}/toggleFavorite/$id?bFavorite=$iFavorite${PostAPIQueueModel.requestSeparator}{}";

      var postQueueItem = _dataRepository.composeQueueItem(
          entityName: PostAPIEntityNames.toggleColorFavorite,
          action: PostAPIActions.toggleColorFavorite,
          request: request,
          localEntityId: id,
          serverEntityId: null,
          bCompleted: false,
          shouldAddPlaceholder: true);

      // Add a new row in the post_api_queue table as shown
      var res = await _dataRepository.saveDataToLocal(
          TableNames.postApiQueue, postQueueItem.toMap());
          */
    } catch (e) {
      print("exception in saveReadNotification() - ${e.toString()}");
      rethrow;
    }
  }

  /* Fetch functions related to colors and formulas */

  Future<List<DiaryModel>> getAllDiaries(
      {int offset = 0,
      List<String> filters = const [], // "statusName='Active'"],
      String? orderByClause,
      int? limit}) async {
    // print("colorController::getAllColors() called!");
    var orderBy =
        orderByClause != null && orderByClause.isNotEmpty ? orderByClause : "";

    var listDiaryMap = await _dataRepository.getAllDataFromTable(
        TableNames.diaries,
        where: filters.isEmpty ? null : filters.join(" AND "),
        orderBy: orderBy);

    // print("listColorsMap: ${listColorsMap.toList().toString()}");

    if (listDiaryMap.length < 1) {
      return [];
    }

    var listDiaryModel = listDiaryMap
        .map((diaryMap) => DiaryModel.fromSQLLiteMap(diaryMap))
        .toList();

    // print ("ColorController::getAllColors() - listEntity: ${listEntity.last.formulaModel?.toMap()}");
    return listDiaryModel;
  }

  Future<DiaryModel> getDiaryById(int diaryId) async {
    String whereClause = "id = $diaryId";
    var listOfMaps = await _dataRepository
        .getAllDataFromTable(TableNames.diaries, where: whereClause);
    return DiaryModel.fromSQLLiteMap(listOfMaps.first);
  }

  void updateDiariesData() async {
    // print("updateColorsData() - calling getAllColors()");
    var dataModelList = await getAllDiaries();
    streamController.add(dataModelList);
  }

  StreamSubscription<SyncState> listenSyncState() {
    return DataSyncService.instance.stateStream.listen((state) {
      updateDiariesData();
      _setState();
    });
  }

  _setState() {
    notifyListeners();
  }

  setState() {
    _setState();
  }
}
