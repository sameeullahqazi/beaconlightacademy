import 'package:bla_flutter_app/models/base_model.dart';

class DiaryCommentModel implements BaseModel {
  String id;
  String diaryId;
  String senderId;
  String senderName;
  String message;
  String createdDate;
  String modifiedDate;
  int isDeleted;
  int bLocal;

  DiaryCommentModel({
    required this.id,
    required this.diaryId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdDate,
    required this.modifiedDate,
    this.isDeleted = 0,
    this.bLocal = 0,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diaryId': diaryId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'createdDate': createdDate,
      'modifiedDate': modifiedDate,
      'is_deleted': isDeleted,
      'bLocal': bLocal,
    };
  }

  @override
  Map<String, dynamic> toSQLLiteMap() {
    return toMap();
  }

  factory DiaryCommentModel.fromMap(Map<String, dynamic> map) {
    return DiaryCommentModel(
      id: map['id'].toString(),
      diaryId: map['diaryId'].toString(),
      senderId: map['senderId'].toString(),
      senderName: map['senderName'] != null ? map['senderName'].toString() : '',
      message: map['message'] != null ? map['message'].toString() : '',
      createdDate: map['createdDate'] ?? '',
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] ?? 0,
      bLocal: map['bLocal'] ?? 0,
    );
  }

  @override
  factory DiaryCommentModel.fromSQLLiteMap(Map<String, dynamic> map) {
    return DiaryCommentModel(
      id: map['id'].toString(),
      diaryId: map['diaryId'].toString(),
      senderId: map['senderId'].toString(),
      senderName: map['senderName'] != null ? map['senderName'].toString() : '',
      message: map['message'] != null ? map['message'].toString() : '',
      createdDate: map['createdDate'] ?? '',
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] != null
          ? int.parse(map['is_deleted'].toString())
          : 0,
      bLocal: map['bLocal'] != null ? int.parse(map['bLocal'].toString()) : 0,
    );
  }

  @override
  String get modelId => id;

  @override
  DateTime get modDate => DateTime.tryParse(modifiedDate) ?? DateTime.now();
}
