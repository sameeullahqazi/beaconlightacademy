import 'package:bla_flutter_app/models/base_model.dart';

class ClassModel extends BaseModel {
  final String id;
  final String className;
  final int? year;

  // ✅ ADD THIS: Dummy field to satisfy the generic sync function
  String modifiedDate;

  ClassModel({
    required this.id,
    required this.className,
    this.year,
    this.modifiedDate = "",
  });

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'].toString(),
      className: map['className'] ?? map['name'] ?? 'Unknown Class',
      year: map['year'] != null ? int.tryParse(map['year'].toString()) : null,
      modifiedDate: map['modifiedDate'] ?? '',
    );
  }

  factory ClassModel.fromSQLLiteMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'].toString(),
      className: map['className'] ?? 'Unknown Class',
      year: map['year'] as int?,
      modifiedDate: map['modifiedDate'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'className': className,
      'year': year,
      'modifiedDate': modifiedDate,
    };
  }

  @override
  Map<String, dynamic> toSQLLiteMap() {
    return {
      'id': id,
      'className': className,
      'year': year,
      'is_deleted': 0,
      'bLocal': 0,
    };
  }

  @override
  String get modelId => id;

  @override
  DateTime get modDate => DateTime.now();
}
