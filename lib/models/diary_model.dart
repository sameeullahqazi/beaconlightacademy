import 'package:bla_flutter_app/models/base_model.dart';

class DiaryModel implements BaseModel {
  String id;
  String diaryId;
  String studentId;
  final String? classId;
  String? title;
  String? subject;
  String? diaryType;
  String? details;
  String? className;
  String? dateDue;
  String? attachment;
  String? attachment2;
  String? dateSubmitted;
  int bRead;
  String createdDate;
  String modifiedDate;
  int isDeleted;
  int bLocal;

  DiaryModel({
    required this.id,
    required this.diaryId,
    required this.studentId,
    this.classId,
    this.title,
    this.subject,
    this.diaryType,
    this.details,
    this.className,
    this.dateDue,
    this.attachment,
    this.attachment2,
    this.dateSubmitted,
    required this.bRead,
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
      'studentId': studentId,
      'classId': classId,
      'title': title,
      'subject': subject,
      'diaryType': diaryType,
      'details': details,
      'className': className,
      'dateDue': dateDue,
      'attachment': attachment,
      'attachment2': attachment2,
      'dateSubmitted': dateSubmitted,
      'bRead': bRead,
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

  factory DiaryModel.fromMap(Map<String, dynamic> map) {
    return DiaryModel(
      id: map['id'].toString(),
      diaryId: map['diaryId'].toString(),
      studentId: map['studentId'].toString(),
      classId: map['classId'].toString(),
      title: map['title'],
      subject: map['subject'],
      diaryType: map['diaryType'],
      details: map['details'],
      className: map['className'],
      dateDue: map['dateDue'],
      attachment: map['attachment'],
      attachment2: map['attachment2'],
      dateSubmitted: map['dateSubmitted'],
      bRead: int.tryParse(map['bRead'].toString()) ?? 0,
      createdDate: map['createdDate'] ?? '',
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] ?? 0,
      bLocal: map['bLocal'] ?? 0,
    );
  }

  @override
  factory DiaryModel.fromSQLLiteMap(Map<String, dynamic> map) {
    return DiaryModel(
      id: map['id'].toString(),
      diaryId: map['diaryId'].toString(),
      studentId: map['studentId'].toString(),
      classId: map['classId'] != null ? map['classId'].toString() : '0',
      title: map['title'],
      subject: map['subject'],
      diaryType: map['diaryType'],
      details: map['details'],
      className: map['className'],
      dateDue: map['dateDue'],
      attachment: map['attachment'],
      attachment2: map['attachment2'],
      dateSubmitted: map['dateSubmitted'],
      // Safety: Handle if DB returns string "1" or int 1
      bRead: map['bRead'] != null ? int.parse(map['bRead'].toString()) : 0,
      createdDate: map['createdDate'] ?? '',
      modifiedDate: map['modifiedDate'] ?? '',
      isDeleted: map['is_deleted'] != null
          ? int.parse(map['is_deleted'].toString())
          : 0,
      bLocal: map['bLocal'] != null ? int.parse(map['bLocal'].toString()) : 0,
    );
  }

  // Helper to check if read
  bool get isRead => bRead == 1;

  @override
  String get modelId => id;

  // Helper to parse date if needed
  @override
  DateTime get modDate => DateTime.tryParse(modifiedDate) ?? DateTime.now();
}
