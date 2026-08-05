import 'package:bla_flutter_app/models/base_model.dart';

class ContactModel implements BaseModel {
  String id;
  String username;
  String fullName;
  String role;
  String? classId;
  String? studentId;

  // ✅ ADD THIS: Dummy field to satisfy the generic sync function
  String modifiedDate;

  ContactModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.classId,
    this.studentId,
    this.modifiedDate = "", // Default to empty
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'].toString(),
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? '',
      classId: map['classId'], // Optional, can be null
      studentId: map['studentId'], // Optional, can be null
      // ✅ Safely handle if API sends it or not
      modifiedDate: map['modifiedDate'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role,
      'classId': classId,
      'studentId': studentId,
      // Note: We don't necessarily need to save this to DB if the column doesn't exist,
      // but keeping it in the map is usually harmless unless SQLite is strict about extra keys.
      // If your 'contacts' table DOES NOT have a modifiedDate column, remove this line below:
      // 'modifiedDate': modifiedDate,
    };
  }

  @override
  Map<String, dynamic> toSQLLiteMap() {
    // ⚠️ IMPORTANT: Only return keys that actually exist in your SQLite 'contacts' table!
    // Since we created the table with only (id, username, fullName, role),
    // DO NOT include modifiedDate here.
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role,
      'classId': classId,
      'studentId': studentId,
    };
  }

  @override
  factory ContactModel.fromSQLLiteMap(Map<String, dynamic> map) =>
      ContactModel.fromMap(map);

  @override
  String get modelId => id;

  @override
  DateTime get modDate => DateTime.now();
}
