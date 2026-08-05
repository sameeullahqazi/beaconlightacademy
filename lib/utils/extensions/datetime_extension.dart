import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String toyMdHmsFormattedString() {
    DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(this);
  }

  String toMMddYYYYFormattedString() {
    DateFormat formatter = DateFormat('MM/dd/yyyy');
    return formatter.format(this);
  }

  String toMMddYYYYhMsAFormattedString() {
    DateFormat formatter = DateFormat('MM/dd/yyyy hh:mm a');
    return formatter.format(this);
  }
}