import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

export 'package:logger/logger.dart';

class LoggerManager {
  static final LoggerManager _instance = LoggerManager._internal();
  late Logger _logger;

  factory LoggerManager() {
    return _instance;
  }

  LoggerManager._internal() {
    _logger = Logger(
      printer: PrettyPrinter(),
      output: FileOutput(),
      level: Logger.level,
    );
  }

  void log(Level level, String message) async {
    _logger.log(level, message);
    print("LogManager: $message");
  }
}

class FileOutput extends LogOutput {
  late File file;
  IOSink? _sink;

  FileOutput() {
    // _initFile().then((_) {
    //
    // });
  }

  Future<void> _initFile() async {
    final directory = Platform.isIOS
        ? await getLibraryDirectory()
        : await getApplicationCacheDirectory();
    file = File('${directory.path}/log.txt');

    if (!(await file.exists())) {
      file = await file.create(recursive: true);
    }

    _sink = file.openWrite(mode: FileMode.append);
  }

  @override
  void output(OutputEvent event) async {
    if (_sink == null) {
      await _initFile();
    }
    for (var line in event.lines) {
      _sink!.writeln(
          '${event.level.name} at ${DateTime.now()}: $line \n Stacktrace:');
    }
    _sink!.writeln('Stacktrace: ${event.origin.stackTrace?.toString()}');
  }

  @override
  Future<void> destroy() async {
    _sink?.close();
  }
}
