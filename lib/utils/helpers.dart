import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bla_flutter_app/constants/storage_strings.dart';
import 'package:bla_flutter_app/services/sercure_storage_service.dart';
import 'package:bla_flutter_app/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> checkInternetAvailability() async {
  var listOfConnections = await Connectivity().checkConnectivity();
  var checkInternet = listOfConnections.contains(ConnectivityResult.ethernet) ||
      listOfConnections.contains(ConnectivityResult.wifi) ||
      listOfConnections.contains(ConnectivityResult.mobile);
  return checkInternet;
}

bool isJsonDecodable(String jsonString) {
  try {
    jsonDecode(jsonString);
    return true;
  } catch (e) {
    return false;
  }
}

//If true returns the same string
String? tryJsonDecode(String? jsonString) {
  try {
    if (jsonString == null) {
      return null;
    }
    jsonDecode(jsonString);
    return jsonString;
  } catch (e) {
    // print("tryJsonDecode() - exception: ${e.toString()}, jsonString: $jsonString");
    if (jsonString != null && jsonString.isNotEmpty) {
      var arrData = jsonString.split(" ");
      var strData = arrData
          .map((entry) {
            var row = "";
            if (entry.contains(":")) {
              var keyValue = entry.split(":");
              if (keyValue.length == 2) {
                // row = '"${keyValue[0].trim()}": "${keyValue[1].trim()}",';
                row =
                    '{"wavelength": ${keyValue[0].trim()}, "reading": ${keyValue[1].trim()}}';
              } else {
                row = '"${keyValue[0].trim()}": "",';
              }
            } else {
              row = '"$entry": "",';
            }
            return row;
          })
          .toList()
          .toString();
      // print("tryJsonDecode() - strData: $strData");
      return strData;
    }
    return null;
  }
}

//Takes all the reads list and return single map with average values
Map<String, dynamic> calculateAverageRead(List<Map<String, dynamic>> dataList) {
  if (dataList.isEmpty) {
    return {};
  }

  // Initialize sums and counts for numeric fields
  Map<String, num> sums = {};
  Map<String, int> counts = {};

  // Iterate over each map in the list
  for (var data in dataList) {
    // Iterate over each key-value pair in the map
    data.forEach((key, value) {
      // Check if the value is numeric
      if (value is num) {
        // Add the value to the sum and increment the count for this key
        sums[key] = (sums[key] ?? 0) + value;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    });
  }

  // Initialize the result map with the values from the first map in the list
  Map<String, dynamic> result = Map.from(dataList.first);

  // Calculate averages for numeric fields
  sums.forEach((key, value) {
    result[key] = value / counts[key]!;
  });

  // If a numeric field is missing from some maps, use the value from the first map
  dataList.first.forEach((key, value) {
    if (!sums.containsKey(key)) {
      result[key] = value;
    }
  });

  return result;
}

void removeLoggedInUser() async {
  await SecureStorageService.instance
      .delete(key: StorageStringsConstants.userDataKey);
}

void removeLoggedInTopUser() async {
  await SecureStorageService.instance
      .delete(key: StorageStringsConstants.topUserDataKey);
}

void removeUserStorageData(String userName) async {
  await SecureStorageService.instance.delete(key: userName);
}

void removeStorageData() async {
  await SecureStorageService.instance.deleteAll();
}

Future<UserModel> getLoggedInTopUser() async {
  return UserModel.fromJson(json.decode((await SecureStorageService.instance
      .read(key: StorageStringsConstants.topUserDataKey))!));
}

Future<String> getAccessStagingFlag() async {
  var accessStagingFlag = (await SecureStorageService.instance
          .read(key: StorageStringsConstants.accessStagingFlag)) ??
      "".toString();
  return accessStagingFlag;
}

Future<bool> bUserCustomerIDsModified() async {
  return (await SecureStorageService.instance
          .read(key: StorageStringsConstants.bUserCustomerIDsModified)) !=
      null;
}

Future<void> setUserCustomerIDsModified() async {
  await SecureStorageService.instance.write(
      key: StorageStringsConstants.bUserCustomerIDsModified,
      value: true.toString());
}

Future<void> resetUserCustomerIDsModified() async {
  await SecureStorageService.instance
      .delete(key: StorageStringsConstants.bUserCustomerIDsModified);
}

Future<void> setLoggedInTopUser(UserModel user) async {
  await SecureStorageService.instance.write(
      key: StorageStringsConstants.topUserDataKey,
      value: jsonEncode(user.toMap()));
}

Future<void> setLoggedInUser(UserModel user) async {
  await SecureStorageService.instance.write(
      key: StorageStringsConstants.userDataKey,
      value: jsonEncode(user.toMap()));
}

Future<void> openMyInkIQReport(String reportURL) async {
  var url = Uri.parse(reportURL);
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}

List<Point<double>> convertDataToPoints(String? encodedData) {
  try {
    // print("convertDataToPoints() - encodedData: $encodedData");
    List<dynamic> data = jsonDecode(encodedData ?? "[]");
    // print("convertDataToPoints() - data: ${data.toList().toString()}");

    Map<int, double> ddata = {
      for (var v in data)
        int.tryParse(v['wavelength'].toString()) ?? 400:
            double.tryParse(v['reading'].toString()) ?? 0.0
    };
    // print("convertDataToPoints() - ddata: ${ddata.toString()}");
    var values = ddata.values.toList();
    // print("convertDataToPoints() - values: ${values.toList().toString()}");
    double sumValues = 0.0;
    int numValues = values.length;
    for (var i = 0; i < numValues; i++) {
      sumValues += values[i];
    }
    ;
    // print("sumValues: $sumValues, numValues: $numValues");

    // var avg = values.reduce((value, element) => (value + element)) / values.length;
    if (numValues > 0) {
      var avg = sumValues / numValues;
      if (avg > 2.0) {
        ddata = {
          for (var v in data)
            int.tryParse(v['wavelength'].toString()) ?? 400:
                (double.tryParse(v['reading'].toString()) ?? 0.0) / 100.0
        };
      }
    }

    // Iterate through each pair and create a Point<double> object
    List<Point<double>> points = ddata.entries
        .map((entry) => Point(double.parse(entry.key.toString()),
            double.parse(entry.value.toString())))
        .toList();
    points.sort((a, b) => a.x.compareTo(b.x));
    return points;
  } catch (e, s) {
    print(
        "convertDataToPoints() outer exception: ${e.toString()} ${s.toString()}");
    if (encodedData == null) {
      return <Point<double>>[];
    }

    String bracketedData = encodedData; // "[$encodedData]";
    // Remove unnecessary characters and split the input string into pairs
    try {
      var cleanData = bracketedData; // .replaceAll('r', '"r');

      print(cleanData);

      List<dynamic> data = jsonDecode(cleanData);
      print(
          "convertDataToPoints() - exception : data: ${data.toList().toString()}");

      // Iterate through each pair and create a Point<double> object
      List<Point<double>> points = []; //data
      // .map((entry) => Point(entry['wavelength'], entry['reading'])
      // .toList();
      for (var i = 0; i < data.length; i++) {
        var elem = data[i];
        points.add(Point(double.tryParse(elem['wavelength'].toString())!,
            double.tryParse(elem['reading'].toString())!));
      }
      return points;
    } catch (e, s) {
      print(
          "convertDataToPoints() inner exception: ${e.toString()} ${s.toString()}");
      return [];
    }
  }
}

//
String customDecode(String str) {
  String res = "";
  Codec<String, String> stringToBase64 = utf8.fuse(base64);
  str = stringToBase64.decode(str);
  int numChars = str.length;
  for (int i = 0; i < numChars; i++) {
    int charCode = str.codeUnitAt(i);
    if (charCode == 32) {
      charCode = 126;
    } else {
      charCode--;
    }
    res += String.fromCharCode(charCode);
  }

  // String encoded = stringToBase64.encode(res);
  // print("customDecode() - res: $res, encoded: $encoded");
  return res;
}

String customEncode(String str) {
  String encodedStr = "";
  int numChars = str.length;
  for (int i = 0; i < numChars; i++) {
    int ch = str.codeUnitAt(i);
    if (ch == 126) {
      ch = 32;
    } else {
      ch++;
    }
    encodedStr += String.fromCharCode(ch);
  }

  Codec<String, String> stringToBase64 = utf8.fuse(base64);
  encodedStr = stringToBase64.encode(encodedStr);
  // print("customEncode() - str: $str, encodedStr: $encodedStr");
  return encodedStr;
}

Future<String> getAppDirPath() async {
  Directory appDocDir = Platform.isIOS
      ? await getLibraryDirectory()
      : await getApplicationCacheDirectory();
  if (!await appDocDir.exists()) {
    await appDocDir.create(recursive: true);
  }
  String dirPath = join(appDocDir.path, '');
  print("getAppDirPath() - dirPath: $dirPath");
  return dirPath;
}

bool is64BitPlatform() {
  if (Platform.isWindows) {
    return (Platform.version.contains("windows_x64"));
  } else if (Platform.isLinux) {
    return (Platform.version.contains("x86_64"));
  } else if (Platform.isMacOS) {
    return (Platform.version.contains("x86_64"));
  } else {
    return false;
  }
}

String getPrettyJSONString(String jsonString) {
  JsonDecoder decoder = JsonDecoder();
  var jsonObject = decoder.convert(jsonString);
  var encoder = JsonEncoder.withIndent("");
  return encoder.convert(jsonObject);
}

void showWarningDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text("Warning"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

String getInitials(String fullName) {
  List<String> names = fullName.split(" ");
  String initials = "";
  for (var name in names) {
    if (name.isNotEmpty) {
      initials += name[0].toUpperCase();
    }
  }
  return initials;
}

// ✅ Helper to convert UTC payload strings to Local Time
String utcToLocal(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr == 'NULL') return '';
  try {
    // Append 'Z' so Dart knows it's UTC, then convert to device's local timezone
    DateTime parsed = DateTime.parse("${dateStr.trim()}Z").toLocal();
    // Format it back to standard SQL format
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);
  } catch (e) {
    return dateStr; // Fallback if parsing fails
  }
}

// Reformats an already-converted local ISO-ish timestamp (utcToLocal()'s
// own output, "yyyy-MM-dd HH:mm:ss") into the human-readable style the UI
// displays, matching the backend's own DATETIME_FORMAT ('%a, %d/%m/%Y %r'
// -> "Sat, 03/10/2026 05:33:16 AM"). Needed because the backend's push
// payload separately sends a *pre-formatted* copy of this same moment in
// that human-readable style, which utcToLocal() can't parse (DateTime.parse
// requires an ISO-ish string) - it silently fell back to returning that
// string unconverted, so displayed times stayed in UTC (observed: 5 hours
// behind Pakistan local time) even though the ISO-format copy converted
// correctly. Deriving the display string from the one that's guaranteed to
// parse keeps both representations of the same moment in sync.
String formatLocalDisplayDate(String? localIsoDateStr) {
  if (localIsoDateStr == null || localIsoDateStr.isEmpty) return '';
  try {
    DateTime parsed = DateTime.parse(localIsoDateStr.trim());
    return DateFormat('EEE, dd/MM/yyyy hh:mm:ss a').format(parsed);
  } catch (e) {
    return localIsoDateStr;
  }
}
/*
// Samee - Custom Image Widget that checks if the image is present locally, otherwise fetches it from the server
class UtilImage extends StatefulWidget {
  String? localURL;
  String? networkURL;
  dynamic cookies;
  BuildContext context;
  String? folder;

  UtilImage({
    required this.context,
    this.localURL,
    this.networkURL,
    this.cookies,
    this.folder,
  });

  @override
  State<UtilImage> createState() => _UtilImageState();
}

class _UtilImageState extends State<UtilImage> {
  String filePath = '';
  bool bLocalFileExists = false;
  String contentType = 'application/json';
  bool dontshow = false;
  dynamic image = SizedBox(
    width: 0,
    height: 0,
  );

  @override
  void initState() {
    super.initState();
    _asyncMethod();
  }

  _asyncMethod() async {
    String userName = (await getLoggedInTopUser()).username!;
    Directory appDocDir = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationCacheDirectory();

    var tmpfilePath = join(
      appDocDir.path,
      APIStrings.env,
      userName,
    );
    if (widget.folder != null) {
      tmpfilePath = join(tmpfilePath, widget.folder!);
    }
    tmpfilePath = join(tmpfilePath, widget.localURL ?? "");
    // print("UtilImage::_asyncMethod() - tmpfilePath: $tmpfilePath");
    var tmpfile;
    bool tmpbLocalFileExists = false;
    var tmpfileBytes;
    try {
      tmpfile = File(tmpfilePath);
      tmpbLocalFileExists = (await tmpfile.exists());

      tmpfileBytes = await tmpfile.readAsBytes();
    } catch (e, s) {
      // print("file exception: ${e.toString()}, trace: ${s.toString()}");
      tmpbLocalFileExists = false;
      tmpfileBytes = 0;
    } finally {
      if (!tmpbLocalFileExists) {
        final response = await http.get(Uri.parse(widget.networkURL ?? ""));

        // print("response.statusCode: ${response.statusCode}");
        // print("widget.networkURL: ${widget.networkURL}");

        if (response.statusCode != 200 && mounted) {
          setState(() {
            dontshow = true;
            widget.networkURL = "";
          });
        } else if (response.body.isNotEmpty) {
          image = Image.network(
            widget.networkURL!,
            headers: <String, String>{
              'Content-Type': contentType,
              'Cookie': widget.cookies,
            },
            errorBuilder: (context, _, __) => SizedBox(),
          );
        }
      } else {
        tmpfileBytes = await tmpfile.readAsBytes();
        if (tmpfileBytes.length <= 0) {
          setState(() {
            dontshow = true;
          });
        } else {
          image = Image.file(
            tmpfile,
          );
        }
      }

      if (mounted) {
        setState(() {
          filePath = tmpfilePath;
          bLocalFileExists = tmpbLocalFileExists && tmpfileBytes.isNotEmpty;
        });
      }
    }
    // print("UtilImage::_asyncMethod() - tmpfilePath: $tmpfilePath, tmpbLocalFileExists: $tmpbLocalFileExists",);
  }

  @override
  Widget build(BuildContext context) {
    // print("build() - bLocalFileExists: $bLocalFileExists");

    if (!dontshow) {
      return SizedBox(
          height: 225.0,
          child: IconButton(
              onPressed: () {
                showImagePreviewDialog(context);
              },
              padding: EdgeInsets.all(0.0),
              icon: image));
    } else {
      return Text("");
    }
    // TODO: implement build
    throw UnimplementedError();
  }

  Future<void> showImagePreviewDialog(BuildContext context) async {
    ColorScheme cc2Colors = Theme.of(context).colorScheme;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return GradientAlert(
          width: 1200,
          child: Builder(builder: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "",
                  style: cc2Heading3(context),
                ),
                SizedBox(
                  height: 8,
                ),
                image,
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cc2Colors.errorContainer,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        textStyle: buttonText(
                          context,
                          color: cc2Colors.onErrorContainer,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "X",
                        style: TextStyle(
                          color: cc2Colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );
  }
  
}
*/
