class BaseModel {
  // Convert a Dog into a Map. The keys must correspond to the names of the
  // columns in the database.
  // final String tableName;

  BaseModel(
      // {required this.tableName}
      );

  String get modelId => "";
  DateTime get modDate => DateTime.now();

  Map<String, dynamic> toMap() {
    return {};
  }


  Map<String, dynamic> toSQLLiteMap() {
    return {};
  }

  // Implement toString to make it easier to see information about
  // each dog when using the print statement.
  @override
  String toString() {
    return '';
  }

  static BaseModel fromMap(Map<String,dynamic> map){
    return BaseModel();
  }

  static BaseModel fromSQLLiteMap(Map<String,dynamic> map){
    return BaseModel();
  }

}
