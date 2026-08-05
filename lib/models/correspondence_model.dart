import 'package:bla_flutter_app/models/base_model.dart';

class CorrespondenceModel implements BaseModel {
  String id;
  String studentId;
  String? subject;
  String? message; // Preview message
  String? date; // Display date
  String? dateEnded;
  String? senderName;
  String? contactName;
  String? studentName;
  int? numUnreadMessages;
  int bRead;
  String modifiedDate;
  int isDeleted;
  int bLocal;

  CorrespondenceModel({
    required this.id,
    required this.studentId,
    this.subject,
    this.message,
    this.date,
    this.dateEnded,
    this.senderName,
    this.contactName,
    this.studentName,
    this.numUnreadMessages,
    required this.bRead,
    required this.modifiedDate,
    this.isDeleted = 0,
    this.bLocal = 0,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'subject': subject,
      'message': message,
      'date': date,
      'dateEnded': dateEnded,
      'senderName': senderName,
      'contactName': contactName,
      'studentName': studentName,
      'numUnreadMessages': numUnreadMessages,
      'bRead': bRead,
      'modifiedDate': modifiedDate,
      'is_deleted': isDeleted,
      'bLocal': bLocal,
    };
  }

  @override
  Map<String, dynamic> toSQLLiteMap() {
    return toMap();
  }

  factory CorrespondenceModel.fromMap(Map<String, dynamic> map) {
    return CorrespondenceModel(
      id: map['id'].toString(),
      studentId: map['studentId'].toString(),
      subject: map['subject'],
      message: map['message'],
      date: map['date'],
      dateEnded: map['dateEnded'],
      senderName: map['senderName'],
      contactName: map['contactName'],
      studentName: map['studentName'],
      numUnreadMessages: map['numUnreadMessages'] != null
          ? int.tryParse(map['numUnreadMessages'].toString()) ?? 0
          : 0,
      bRead: int.tryParse(map['bRead'].toString()) ?? 0,
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] ?? 0,
      bLocal: map['bLocal'] ?? 0,
    );
  }

  @override
  factory CorrespondenceModel.fromSQLLiteMap(Map<String, dynamic> map) {
    return CorrespondenceModel(
      id: map['id'].toString(),
      studentId: map['studentId'].toString(),
      subject: map['subject'],
      message: map['message'],
      date: map['date'],
      dateEnded: map['dateEnded'],
      senderName: map['senderName'],
      contactName: map['contactName'],
      studentName: map['studentName'],
      // ✅ THE FIX: Safely parse the new subquery count
      numUnreadMessages: map['numUnreadMessages'] != null
          ? int.tryParse(map['numUnreadMessages'].toString()) ?? 0
          : 0,
      // ✅ Safely parse ints even if SQLite returns a raw int or a string
      bRead:
          map['bRead'] != null ? int.tryParse(map['bRead'].toString()) ?? 0 : 0,
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] != null
          ? int.parse(map['is_deleted'].toString())
          : 0,
      bLocal: map['bLocal'] != null ? int.parse(map['bLocal'].toString()) : 0,
    );
  }

  bool get isClosed => dateEnded != null;

  @override
  String get modelId => id;

  @override
  DateTime get modDate => DateTime.tryParse(modifiedDate) ?? DateTime.now();
}
