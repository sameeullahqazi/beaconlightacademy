import 'package:bla_flutter_app/db/database.dart';
import 'package:bla_flutter_app/models/base_model.dart';
import 'package:bla_flutter_app/constants/api_strings.dart';
import 'package:bla_flutter_app/utils/logger_manager.dart';

import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SQLiteDB extends BaseDB {
  // Convert a Dog into a Map. The keys must correspond to the names of the
  // columns in the database.

  static const classLogName = "SQLiteDB:";

  static Future<bool> databaseExists(String dbName) async {
    // databaseFactory = databaseFactoryFfi;
    // var databasesPath = await getDatabasesPath();
    // String path = join(databasesPath, "$dbName.db");
    // Future<bool> exists = databaseFactory.databaseExists(path);
    // print("databaseExists - path: $path, exists: $exists");
    Directory appDocDir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationCacheDirectory();
    String databasePath = join(
      '${appDocDir.path}/${APIStrings.env}',
      '$dbName.db',
    );
    // print("databaseExists() - databasePath: $databasePath");
    return await File(databasePath).exists();
    // return exists;
  }

  static Future<String> deleteDBFileIfExists(String dbName) async {
    Directory appDocDir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationCacheDirectory();
    String databasePath = join(
      '${appDocDir.path}/${APIStrings.env}',
      '$dbName.db',
    );

    var bFileExists = await File(databasePath).exists();
    // print("deleteDBFileIfExists() - databasePath: $databasePath, bFileExists: $bFileExists");
    if (bFileExists) {
      await File(databasePath).delete();
    }
    return "$databasePath - bFileExists: $bFileExists";
  }

  static Future<void> deleteDatabase(String dbName) async {
    // FIX: Initialize FFI for Desktop support inside this static method
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    var appDocDir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationCacheDirectory();

    String path = join(
      '${appDocDir.path}/${APIStrings.env}',
      '$dbName.db',
    );

    // print("databaseDeleted - path: $path");
    // FIX: Await the deletion
    await databaseFactory.deleteDatabase(path);
  }

  SQLiteDB(pDbName) {
    dbName = pDbName;
    // open();
  }

  @override
  Future<bool> open({bool shouldCreateSchema = true}) async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        // Initialize FFI
        sqfliteFfiInit();
        // ✅ MOVED: Tell Windows/Linux to use the FFI factory
        databaseFactory = databaseFactoryFfi;
      }

      // // Construct a file path to copy database to
      // Directory documentsDirectory = await getApplicationDocumentsDirectory();
      // String path = join(documentsDirectory.path, '$dbName.db');
      //
      // // Only copy if the database doesn't exist
      // if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound){
      //   // Load database from asset and copy
      //   ByteData data = await rootBundle.load(join('assets', 'database.db'));
      //   List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      //
      //   // Save copied asset to documents
      //   await File(path).writeAsBytes(bytes);
      // }

      // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
      // this step, it will use the sqlite version available on the system.
      // print("dbName: $dbName");

      Directory appDocDir = Platform.isIOS
          ? await getLibraryDirectory()
          : Platform.isIOS
              ? await getLibraryDirectory()
              : await getApplicationCacheDirectory();
      if (!await appDocDir.exists()) {
        await appDocDir.create(recursive: true);
      }
      String databasePath = join(
        '${appDocDir.path}/${APIStrings.env}',
        '$dbName.db',
      );

      // Directory appDocDir = await getApplicationDocumentsDirectory();
      // String databasePath = join(appDocDir.path, '$dbName.db');

      database = await openDatabase(
        // Set the path to the database. Note: Using the `join` function from the
        // `path` package is best practice to ensure the path is correctly
        // constructed for each platform.
        databasePath,
        // join(await getDatabasesPath(), '$dbName.db'),
        // When the database is first created, create a table to store dogs.
        onCreate: (db, version) async {
          // Run the CREATE TABLE statement on the database.
          // await createDb();
        },
        onOpen: (db) {
          // print("SQLLite: Db is opened with name: $dbName");
        },
        // Set the version. This executes the onCreate function and provides a
        // path to perform database upgrades and downgrades.
        version: 3,
        onUpgrade: (db, oldVersion, newVersion) async {
          // idx_diaries_optimized (is_deleted, bRead, studentId, classId,
          // diaryType, diaryId DESC) doesn't cover createdDate, so
          // getDiaries()'s "is_deleted = 0 AND createdDate >= ?" academic-year
          // cutoff filter was a near-full-table-scan once an account's local
          // diaries table grew into the tens of thousands of rows (observed:
          // multi-second spinner opening the Diary screen / switching tabs
          // for a coordinator role). This must run via onUpgrade, not just
          // added to schema.sql, since real installed users already have a
          // local DB and won't get a fresh schema.sql run on update.
          if (oldVersion < 2) {
            await db.execute(
                "CREATE INDEX IF NOT EXISTS idx_diaries_date ON diaries(is_deleted, createdDate, diaryId DESC);");
          }

          // The diaries table has never had a primary key or unique
          // constraint, so insertOrUpdate()/executeTransaction()'s
          // ConflictAlgorithm.replace never actually triggers - every sync
          // and every push just keeps adding new rows for the same diary
          // forever (observed on a real account: 19,293 rows for only
          // 14,601 distinct diaryIds). Separately, the push-notification
          // insert path never set `id` at all, unlike bulk sync (which gets
          // "{diaryId}-{classId}" directly from the backend's own "Unique
          // ID trick" - see API.class.php's getAPIDiaryList()), so
          // push-inserted rows accumulated with a blank id and also showed
          // up with incomplete fields (e.g. missing className) compared to
          // their bulk-synced counterpart for the same diary. Now that the
          // push path constructs a matching id (see push_notification_
          // service.dart's _saveDiaryLocally()), backfill any existing rows
          // still missing one, collapse exact-id duplicates down to the
          // most recently-inserted copy, then add the unique index so
          // REPLACE actually works going forward.
          if (oldVersion < 3) {
            await db.execute('''
              UPDATE diaries
              SET id = CAST(diaryId AS TEXT) || '-' || (
                CASE
                  WHEN studentId IS NOT NULL AND CAST(studentId AS TEXT) NOT IN ('', 'null')
                    THEN CAST(studentId AS TEXT)
                  WHEN classId IS NULL OR CAST(classId AS TEXT) IN ('', 'null')
                    THEN '0'
                  ELSE CAST(classId AS TEXT)
                END
              )
              WHERE id IS NULL OR CAST(id AS TEXT) = '';
            ''');
            await db.execute('''
              DELETE FROM diaries
              WHERE rowid NOT IN (SELECT MAX(rowid) FROM diaries GROUP BY id);
            ''');
            await db.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_diaries_unique_id ON diaries(id);");
          }
        },
        onConfigure: (Database db) async {
          // ✅ Add this line! It allows simultaneous reads and writes.
          // ToDo - disable this for testing purposes to see if it fixes the "database is locked" error
          await db.rawQuery('PRAGMA journal_mode = WAL;');
        },
      );

      if (shouldCreateSchema) {
        await createDb();
      }

      return true;
    } catch (e, s) {
      LoggerManager()
          .log(Logger.level, "Error in ${runtimeType.toString()}: $e\n$s");
      return false;
    }
  }

  @override
  close() async {
    Database db = database;
    await db.close();
  }

  createDb() async {
    final db = database;
    try {
      // print("SQLite::createDb() - Loading schema...");

      // 1. Load asset directly as String (Much faster than writing to file)
      String schemaContent =
          await rootBundle.loadString("assets/db/schema.sql");

      // Remove SQL comments to prevent parser breakage
      schemaContent =
          schemaContent.replaceAll(RegExp(r'--.*', multiLine: true), '');

      // 2. Split by semicolon to separate commands
      //    (This handles multi-line SQL statements correctly)
      List<String> commands = schemaContent.split(';');

      for (String command in commands) {
        String finalCommand = command.trim();

        // 3. Skip empty lines or just comments
        if (finalCommand.isEmpty || finalCommand.startsWith('--')) continue;

        // 4. Execute the command
        // print("Executing SQL: ${finalCommand.substring(0, 20)}...");
        await db.execute(finalCommand);
      }

      // print("✅ SQLite::createDb() - Schema initialized successfully");
    } catch (e) {
      print("❌ SQLite::createDb() Error: $e");
      // Helpful tip for the specific error you saw
      if (e.toString().contains("Unable to load asset")) {
        // print("⚠️ HINT: Did you add 'assets/db/schema.sql' to your pubspec.yaml?");
      }
    }
  }

  @override
  execute(String sql) async {
    final db = database;
    db.execute(sql);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql) async {
    final db = database;

    final List<Map<String, dynamic>> list = await db.rawQuery(sql);
    return list;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String tableName,
    String columnName,
    dynamic whereArg, {
    String? orderBy,
  }) async {
    final db = database;
    final List<Map<String, dynamic>> list = await db.query(
      tableName,
      where: columnName,
      whereArgs: whereArg,
      orderBy: orderBy,
    );
    return list;
  }

  @override
  Future<int> insertOrUpdate(String tableName, Map<String, dynamic> row) async {
    final db = database;
    // Insert the row into the correct table. You might also specify the
    // `conflictAlgorithm` to use in case the same row is inserted twice.
    //
    // In this case, replace any previous data.
    return (await db.insert(
      tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    ));
  }

  @override
  Future<int> insert(String tableName, Map<String, dynamic> row) async {
    final db = database;
    // Insert the row into the correct table. You might also specify the
    // `conflictAlgorithm` to use in case the same row is inserted twice.
    //
    // In this case, replace any previous data.
    return (await db.insert(
      tableName,
      row,
    ));
  }

  @override
  Future<int> rawInsert(String sql, List<String> args) async {
    final db = database;
    return await db.rawInsert(sql, args);
  }

  @override
  Future<int> rawUpdate(String sql, List<String> args) async {
    final db = database;
    return await db.rawUpdate(sql, args);
  }

  @override
  createViaModel(String tableName, BaseModel model) {
    insertOrUpdate(tableName, model.toMap());
  }

  @override
  update(String tableName, Map<String, dynamic> row, String where,
      List<String> whereArgs) async {
    // Get a reference to the database.
    final db = database;
    // Update the given row.
    await db.update(
      tableName,
      row,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  updateViaModel(
      String tableName, BaseModel model, String where, List<String> whereArgs) {
    update(tableName, model.toMap(), where, whereArgs);
  }

  Stream<List<Map<String, dynamic>>> listenTableChanges(String rawQueryStr) {
    return database
        .rawQuery(rawQueryStr)
        .asStream()
        .map((rows) => rows.toList());
  }

  @override
  Future<int> delete(
      String tableName, String where, List<dynamic> whereArgs) async {
    // Get a reference to the database.
    final db = database;

    // Remove the row from the database.
    return await db.delete(
      tableName,
      // Use a `where` clause to delete a specific row.
      where: where,
      // Pass the row's id as a whereArg to prevent SQL injection.
      whereArgs: whereArgs,
    );
  }
}
