import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/utils/helpers.dart';

class CorrespondenceMessageModel implements BaseModel {
  String id;
  String correspondenceId;
  String senderId;
  String senderName;
  String message;
  String date; // Display date
  String createdDate;
  String modifiedDate;
  int isDeleted;
  int bLocal;

  CorrespondenceMessageModel({
    required this.id,
    required this.correspondenceId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.date,
    required this.createdDate,
    required this.modifiedDate,
    this.isDeleted = 0,
    this.bLocal = 0,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'correspondenceId': correspondenceId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'date': date,
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

  factory CorrespondenceMessageModel.fromMap(Map<String, dynamic> map) {
    return CorrespondenceMessageModel(
      id: map['id'].toString(),
      correspondenceId: map['correspondenceId'].toString(),
      senderId: map['senderId'].toString(),
      senderName: map['senderName'] != null ? map['senderName'].toString() : '',
      message: map['message'] != null ? map['message'].toString() : '',
      date: map['date'] != null ? map['date'].toString() : '',
      createdDate: map['createdDate'] ?? '',
      modifiedDate:
          map['modifiedDate'] != null ? utcToLocal(map['modifiedDate']) : '',
      isDeleted: map['is_deleted'] ?? 0,
      bLocal: map['bLocal'] ?? 0,
    );
  }

  @override
  factory CorrespondenceMessageModel.fromSQLLiteMap(Map<String, dynamic> map) {
    return CorrespondenceMessageModel(
      id: map['id'].toString(),
      correspondenceId: map['correspondenceId'].toString(),
      senderId: map['senderId'].toString(),
      senderName: map['senderName'] != null ? map['senderName'].toString() : '',
      message: map['message'] != null ? map['message'].toString() : '',
      date: map['date'] != null ? map['date'].toString() : '',
      createdDate: map['createdDate'] ?? '',
      modifiedDate:
          map['modifiedDate'] != null ? utcToLocal(map['modifiedDate']) : '',
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
