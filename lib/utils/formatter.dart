// lib/utils/formatter.dart

import 'package:intl/intl.dart';

class Formatter {
  Formatter._();

  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _date     = DateFormat('dd/MM/yyyy');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _time     = DateFormat('hh:mm a');

  static String currency(double v) => _currency.format(v);
  static String date(DateTime d)   => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String time(DateTime d)   => _time.format(d);
}

// extra helpers
extension FormatterExt on Formatter {
  static String currencyFmt(double v) => Formatter.currency(v);
}
