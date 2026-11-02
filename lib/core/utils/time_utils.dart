import 'package:intl/intl.dart';

class TimeUtils {
  static DateTime toIst(DateTime dt) {
    return dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  static String formatIst(DateTime dt, {String pattern = 'MMM d, h:mm a'}) {
    final ist = toIst(dt);
    return '${DateFormat(pattern).format(ist)} IST';
  }

  static String formatIstTime(DateTime dt) {
    final ist = toIst(dt);
    return '${DateFormat('h:mm:ss a').format(ist)} IST';
  }
}
