import 'package:bla_flutter_app/models/base_model.dart';
import 'package:sqflite_common/sqlite_api.dart';

class BaseDB {
  // Convert a Dog into a Map. The keys must correspond to the names of the
  // columns in the database.
  late Database database;
  late String dbName;

  Future<bool> open({bool shouldCreateSchema = true}) async {
    return true;
  }

  close() {}

  execute(String sql) {}

  dynamic rawQuery(String sql) {
    return 0;
  }

  setDbName(String pDbName) {
    dbName = pDbName;
  }

  insertOrUpdate(String tableName, Map<String, dynamic> row) {}

  insert(String tableName, Map<String, dynamic> row) {}

  rawInsert(String sql, List<String> args) {}

  rawUpdate(String sql, List<String> args) {}

  createViaModel(String tableName, BaseModel model) {}

  update(String tableName, Map<String, dynamic> row, String where,
      List<String> whereArgs) {}

  updateViaModel(String tableName, BaseModel model, String where,
      List<String> whereArgs) {}

  delete(String tableName, String where, List<String> whereArgs) {}

  Future<List<Map<String, dynamic>>> query(
      String tableName, String columnName, dynamic whereArg) async {
    return [];
  }

  String getInsertSQL(String tableName, Map<String, dynamic> data) {
    String insertSQL = '';
    String fields = '', values = '';
    fields = data.keys.toList().map((e) => '`$e`').join(', ');
    values = data.values.toList().map((e) => getDataVal(e)).join(', ');

    insertSQL = 'insert into $tableName ($fields) values ($values)';
    return insertSQL;
  }

  String getUpdateSQL(
      String tableName, Map<String, dynamic> data, String where) {
    String updateSQL = '';
    String values = '';
    if (where.isNotEmpty) where = " where $where";

    values = data.keys
        .toList()
        .map((e) => '`$e` = ${getDataVal(data[e])}')
        .join(', ');

    updateSQL = 'update $tableName set $values $where';
    return updateSQL;
  }

  String getDataVal(dynamic e) {
    String val = e.toString();
    return (val == 'now()' || val == 'null' || double.tryParse(val) != null)
        ? val
        : "'$val'";
  }

  Future<void> executeTransaction(String tableName, List<dynamic> dataList,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    Database db = database;
    await db.transaction((txn) async {
      for (var data in dataList) {
        await txn.insert(tableName, data, conflictAlgorithm: conflictAlgorithm);
      }
    });
    // print("SQLLite: Execution of Transaction: $result");
  }
}
