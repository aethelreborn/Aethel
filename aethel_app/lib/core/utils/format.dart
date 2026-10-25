import 'package:intl/intl.dart';

String formatMoney(double value) {
  final decimals = value == value.roundToDouble() ? 0 : 2;
  return NumberFormat.simpleCurrency(decimalDigits: decimals).format(value);
}

String formatDate(DateTime value) => DateFormat('d MMM yyyy').format(value);

String formatShortDate(DateTime value) => DateFormat('d MMM').format(value);
