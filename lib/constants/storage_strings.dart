import 'package:bla_flutter_app/constants/api_strings.dart';

class StorageStringsConstants {
  static var userDataKey = "${APIStrings.env}_user_data";
  static var topUserDataKey = "${APIStrings.env}_top_user_data";
  static var accessStagingFlag = "${APIStrings.env}_access_staging_flag";
  static var bUserCustomerIDsModified =
      "${APIStrings.env}_user_customer_ids_modified";

  // Phase 2 (v9 security) - the long-lived refresh token paired with the
  // now-24h-expiring accessToken, stored per-username alongside the
  // cached password (SecureStorageService.read(key: username)).
  static String refreshTokenKey(String username) =>
      "${APIStrings.env}_refresh_token_$username";
}

class Spectro1Constants {
  static const String dongleDir = "lib/libraries/cp210x";
  static const String dongleCmd = "variable_dongle_server.exe";
  static const String donglePath = "$dongleDir/$dongleCmd";
  static const String donleHost = "127.0.0.1";
  static const int donglePort = 52835;
}

enum ColorFormulaChangeTypes { reset, saved, instrumentChanges }
