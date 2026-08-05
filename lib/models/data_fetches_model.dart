import 'package:bla_flutter_app/models/base_model.dart';

class DataFetchesModel extends BaseModel {
  final String username;
  final FetchAction action; // Use the Action enum here
  final String serverTimestamp;
  final int numRowsFetched;
  final String lastID;

  DataFetchesModel(
      {required this.username,
      required this.action,
      required this.serverTimestamp,
      required this.numRowsFetched,
      required this.lastID});

  // Convert DataFetchesModel to a map
  @override
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'action': action.name, // Convert enum value to string
      // 'serverTimestamp': serverTimestamp.toIso8601String(),
      'serverTimestamp':
          serverTimestamp, // .toString().replaceAll(RegExp(r'Z'), ''),
      'numRowsFetched': numRowsFetched,
      "lastID": lastID
    };
  }

  // Create a DataFetchesModel instance from a map
  factory DataFetchesModel.fromMap(Map<String, dynamic> map) {
    return DataFetchesModel(
      username: map['username'],
      action: FetchAction.values.firstWhere(
          (e) => e.name == map['action']), // Convert string to enum value
      serverTimestamp:
          map['serverTimestamp'], // DateTime.parse(map['serverTimestamp']),
      numRowsFetched: map['numRowsFetched'],
      lastID: map["lastID"],
    );
  }

  @override
  String toString() {
    return 'DataFetchesModel(username: $username, action: $action, serverTimestamp: $serverTimestamp, numRowsFetched: $numRowsFetched)';
  }

  static String getEndpointName(FetchAction action) {
    switch (action.name) {
      case 'colors':
        return "customerColorsList";
      case 'reads':
        return "customerColorReadsList";
      case 'formulas':
        return "customerFormulasList";
      case 'formulaReads':
        return "customerFormulaReadsList";
      case 'changes':
        return "customerColorChangesList";
      case 'formulaChanges':
        return "customerFormulaChangesList";
      case 'salesOrders':
        return "incompleteSalesOrders";
      case 'jobs':
        return "jobsList";
      case 'jobColors':
        return "jobColorsList";
      case 'jobChanges':
        return "customerJobChangesList";
      default:
        return "id";
    }
  }

  static String getEndpointPath(String action) {
    switch (action) {
      case 'colors':
        return "colors/customerColorsList";
      case 'reads':
        return "colors/customerColorReadsList";
      case 'formulas':
        return "formulas/customerFormulasList";
      case 'formulaReads':
        return "formulas/customerFormulaReadsList";
      case 'changes':
        return "colors/customerColorChangesList";
      case 'formulaChanges':
        return "formulas/customerFormulaChangesList";
      case 'salesOrders':
        return "salesorders/incompleteSalesOrders/list";
      case 'jobs':
        return "jobs/list";
      case 'jobColors':
        return "jobs/colors";
      case 'jobChanges':
        return "jobs/customerJobChangesList";
      default:
        return "id";
    }
  }
}

enum FetchAction {
  login,
  diaries,
  diariesComments,
  correspondences,
  correspondencesMessages,
  users,
  contacts,
  classes,
}
