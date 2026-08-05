import 'package:bla_flutter_app/constants/api_strings.dart';

class StorageStringsConstants {
  static var userDataKey = "${APIStrings.env}_user_data";
  static var topUserDataKey = "${APIStrings.env}_top_user_data";
  static var accessStagingFlag = "${APIStrings.env}_access_staging_flag";
  static var bUserCustomerIDsModified =
      "${APIStrings.env}_user_customer_ids_modified";
}

class Spectro1Constants {
  static const String dongleDir = "lib/libraries/cp210x";
  static const String dongleCmd = "variable_dongle_server.exe";
  static const String donglePath = "$dongleDir/$dongleCmd";
  static const String donleHost = "127.0.0.1";
  static const int donglePort = 52835;
}

enum ColorFormulaChangeTypes { reset, saved, instrumentChanges }
