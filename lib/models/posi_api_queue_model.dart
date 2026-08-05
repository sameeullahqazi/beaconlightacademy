import 'package:bla_flutter_app/constants/table_names_strings.dart';
import 'package:bla_flutter_app/utils/extensions/bool_extension.dart';

class PostAPIQueueModel {
  static const requestSeparator = "#";

  int? id;
  PostAPIEntityNames entity;
  PostAPIActions action;
  String? urlPlaceholder;
  String request;
  int localEntityId;
  int? serverEntityId;
  bool bCompleted;
  String? uploadFilename;
  String? method;

  PostAPIQueueModel({
    this.id,
    required this.entity,
    required this.action,
    required this.urlPlaceholder,
    required this.request,
    required this.localEntityId,
    required this.serverEntityId,
    required this.bCompleted,
    this.uploadFilename,
    this.method,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity': entity.name,
      'action': action.name,
      'url': urlPlaceholder,
      "request": request,
      'localEntityId': localEntityId,
      'serverEntityId': serverEntityId,
      'bCompleted': bCompleted.toInt(),
      'uploadFilename': uploadFilename,
      'method': method,
    };
  }

  factory PostAPIQueueModel.fromMap(Map<String, dynamic> map) {
    return PostAPIQueueModel(
      id: map['id'],
      entity: map['entity'].toString().toPostAPIEntityName(),
      action: PostAPIActionsExtension.fromString(map['action'])!,
      urlPlaceholder: map['url'],
      request: map["request"],
      localEntityId: map['localEntityId'],
      serverEntityId: map['serverEntityId'],
      bCompleted: map['bCompleted'] == 1 ? true : false,
      uploadFilename: map['uploadFilename'],
      method: map['method'],
    );
  }

  static String getIdTag(PostAPIEntityNames entityName) {
    switch (entityName) {
      case PostAPIEntityNames.diary:
        return "id";
      case PostAPIEntityNames.diaryComment:
        return "id";
      case PostAPIEntityNames.correspondence:
        return "id";
      case PostAPIEntityNames.correspondenceMessage:
        return "id"; // colorimetryId
      case PostAPIEntityNames.notification:
        return "id";
      case PostAPIEntityNames.user:
        return "id";

      default:
        return "id";
    }
  }

  static String getTableIdTag(PostAPIEntityNames entityName) {
    switch (entityName) {
      case PostAPIEntityNames.diary:
        return "id";
      case PostAPIEntityNames.diaryComment:
        return "id";
      case PostAPIEntityNames.correspondence:
        return "id";
      case PostAPIEntityNames.correspondenceMessage:
        return "id"; // colorimetryId
      case PostAPIEntityNames.notification:
        return "id";
      case PostAPIEntityNames.user:
        return "id";

      default:
        return "id";
    }
  }

  static String getTableName(PostAPIEntityNames entityName) {
    switch (entityName) {
      case PostAPIEntityNames.diary:
        return TableNames.diaries;
      case PostAPIEntityNames.diaryComment:
        return TableNames.diariesComments;
      case PostAPIEntityNames.correspondence:
        return TableNames.correspondences;
      case PostAPIEntityNames.correspondenceMessage:
        return TableNames.correspondencesMessages;
      case PostAPIEntityNames.notification:
        return "notifications";
      case PostAPIEntityNames.user:
        return TableNames.users;
      default:
        return "";
    }
  }

  static String getTableEntityColumn(PostAPIEntityNames entityName) {
    switch (entityName) {
      case PostAPIEntityNames.diary:
        return "id";
      case PostAPIEntityNames.diaryComment:
        return "id";
      case PostAPIEntityNames.correspondence:
        return "id";
      case PostAPIEntityNames.correspondenceMessage:
        return "id";
      case PostAPIEntityNames.notification:
        return "id";
      case PostAPIEntityNames.user:
        return "id";
      default:
        return "id";
    }
  }

  static String getEntityTableName(PostAPIActions action) {
    switch (action) {
      case PostAPIActions.saveCorrespondence:
        return TableNames.correspondences;
      case PostAPIActions.saveCorrespondenceMessage:
        return TableNames.correspondencesMessages;
      case PostAPIActions.readNotification:
        return "notifications";
      case PostAPIActions.saveUser:
        return "users";
      case PostAPIActions.create:
        return "create";
      case PostAPIActions.update:
        return "update";
      default:
        return "";
    }
  }
}

enum PostAPIActions {
  saveCorrespondence,
  saveCorrespondenceMessage,
  readNotification,
  saveUser,
  create,
  update,
  unknown
}

enum PostAPIEntityNames {
  diary,
  correspondence,
  correspondenceMessage,
  notification,
  user,
  unknown,
  diaryComment,
}

extension PostAPIActionsExtension on PostAPIActions {
  static PostAPIActions? fromString(String? value) {
    switch (value) {
      case 'saveCorrespondence':
        return PostAPIActions.saveCorrespondence;
      case 'saveCorrespondenceMessage':
        return PostAPIActions.saveCorrespondenceMessage;
      case 'readNotification':
        return PostAPIActions.readNotification;
      case 'saveUser':
        return PostAPIActions.saveUser;
      case 'create':
        return PostAPIActions.create;
      case 'update':
        return PostAPIActions.update;
      default:
        return PostAPIActions.unknown;
    }
  }
}

extension StringToPostAPIEntityNames on String {
  PostAPIEntityNames toPostAPIEntityName() {
    switch (this) {
      case 'diary':
        return PostAPIEntityNames.diary;
      case 'diaryComment':
        return PostAPIEntityNames.diaryComment;
      case 'correspondence':
        return PostAPIEntityNames.correspondence;
      case 'correspondenceMessage':
        return PostAPIEntityNames.correspondenceMessage;
      case 'notification':
        return PostAPIEntityNames.notification;
      default:
        return PostAPIEntityNames.unknown;
    }
  }
}
