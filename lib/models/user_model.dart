import 'dart:convert'; // <--- 1. Import this for jsonEncode/jsonDecode
import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/models/student_model.dart';

class UserModel implements BaseModel {
  String id;
  String? role;
  String? prefix;
  String? username;
  String? firstname;
  String? lastname;
  String? email;
  String? phone;
  String? profession;
  String? address;
  String createdDate;
  String modifiedDate;
  String? class_teacher_of;
  String? campus_head_of;
  String? nic;
  String? employee_id;
  String? status;
  DateTime? date_employed;
  DateTime? date_quit;
  double? basic_salary;
  double? gross_salary;
  String? campus_id;
  String? account_number;
  String? account_title;
  String? accessToken;
  int? isFeeDefaulter; // ✅ ADD THIS (Using int for easy SQLite 1/0 storage)

  // 2. Change type from String? to List<dynamic>?
  List<dynamic>? students;

  int isDeleted;
  int bLocal;

  UserModel({
    required this.id,
    this.role,
    this.prefix,
    this.username,
    this.firstname,
    this.lastname,
    this.email,
    this.phone,
    this.profession,
    this.address,
    required this.createdDate,
    required this.modifiedDate,
    this.class_teacher_of,
    this.campus_head_of,
    this.nic,
    this.employee_id,
    this.status,
    this.date_employed,
    this.date_quit,
    this.basic_salary,
    this.gross_salary,
    this.campus_id,
    this.account_number,
    this.account_title,
    this.accessToken,
    this.students,
    this.isFeeDefaulter = 0, // ✅ ADD THIS
    this.isDeleted = 0,
    this.bLocal = 0,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'prefix': prefix,
      'username': username,
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'phone': phone,
      'profession': profession,
      'address': address,
      'createdDate': createdDate,
      'modifiedDate': modifiedDate,
      'class_teacher_of': class_teacher_of,
      'campus_head_of': campus_head_of,
      'nic': nic,
      'employee_id': employee_id,
      'status': status,
      'date_employed': date_employed?.millisecondsSinceEpoch,
      'date_quit': date_quit?.millisecondsSinceEpoch,
      'basic_salary': basic_salary,
      'gross_salary': gross_salary,
      'campus_id': campus_id,
      'account_number': account_number,
      'account_title': account_title,
      'accessToken': accessToken,

      // 3. Encode List to String for Storage
      'students': students != null ? jsonEncode(students) : null,
      'isFeeDefaulter': isFeeDefaulter, // ✅ ADD THIS
      'is_deleted': isDeleted,
      'bLocal': bLocal,
    };
  }

  @override
  Map<String, dynamic> toSQLLiteMap() {
    return toMap();
  }

  @override
  factory UserModel.fromSQLiteMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'].toString(),
      role: map['role'],
      prefix: map['prefix'],
      username: map['username'],
      firstname: map['firstname'],
      lastname: map['lastname'],
      email: map['email'],
      phone: map['phone'],
      profession: map['profession'],
      address: map['address'],
      createdDate: map['createdDate'] ?? '',
      modifiedDate: map['modifiedDate'] ?? '',
      class_teacher_of: map['class_teacher_of']?.toString(),
      campus_head_of: map['campus_head_of'],
      nic: map['nic'],
      employee_id: map['employee_id']?.toString(),
      status: map['status'],
      date_employed: map['date_employed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(map['date_employed'].toString()) ?? 0)
          : null,
      date_quit: map['date_quit'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(map['date_quit'].toString()) ?? 0)
          : null,
      basic_salary: map['basic_salary'] != null
          ? double.tryParse(map['basic_salary'].toString())
          : null,
      gross_salary: map['gross_salary'] != null
          ? double.tryParse(map['gross_salary'].toString())
          : null,
      campus_id: map['campus_id']?.toString(),
      account_number: map['account_number']?.toString(),
      account_title: map['account_title']?.toString(),
      accessToken: map['accessToken'],

      // 4. Decode String back to List from Storage
      students: map['students'] != null ? jsonDecode(map['students']) : [],
      isFeeDefaulter:
          map['isFeeDefaulter'] == true || map['isFeeDefaulter'] == 1
              ? 1
              : 0, // ✅ ADD THIS

      isDeleted: map['is_deleted'] != null
          ? int.parse(map['is_deleted'].toString())
          : 0,
      bLocal: map['bLocal'] != null ? int.parse(map['bLocal'].toString()) : 0,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      role: json['role'],
      prefix: json['prefix'],
      username: json['username'],
      firstname: json['firstname'],
      lastname: json['lastname'],
      email: json['email'],
      phone: json['phone'],
      profession: json['profession'],
      address: json['address'],
      createdDate: json['createdDate'] ?? json['created'].toString(),
      modifiedDate: json['modifiedDate'] ?? json['modified'].toString(),
      class_teacher_of: json['class_teacher_of'],
      campus_head_of: json['campus_head_of'],
      nic: json['nic'],
      employee_id: json['employee_id'],
      status: json['status'],
      date_employed: json['date_employed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['date_employed'])
          : null,
      date_quit: json['date_quit'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['date_quit'])
          : null,
      basic_salary:
          json['basic_salary'] != null ? json['basic_salary'].toDouble() : null,
      gross_salary:
          json['gross_salary'] != null ? json['gross_salary'].toDouble() : null,
      campus_id: json['campus_id'],
      account_number: json['account_number'],
      account_title: json['account_title'],
      accessToken: json['accessToken'],

      // 5. Accept List directly from API
      students: json['students'] ?? [],
      isFeeDefaulter:
          json['isFeeDefaulter'] == true || json['isFeeDefaulter'] == 1
              ? 1
              : 0, // ✅ ADD THIS
    );
  }

  @override
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel.fromSQLiteMap(map);
  }

  // ... rest of the file (toString, getters)
  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, createdDate: $createdDate, modifiedDate: $modifiedDate)';
  }

  List<StudentModel> get studentList {
    if (students == null) return [];
    return students!.map((s) => StudentModel.fromMap(s)).toList();
  }

  @override
  String get modelId => id;

  @override
  DateTime get modDate => DateTime.tryParse(modifiedDate) ?? DateTime.now();
}
