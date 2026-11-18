import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('EEE d MMM, h:mm a').format(date);

/// "1 team" / "3 teams".
String pluralize(int count, String singular, [String? plural]) {
  final word = count == 1 ? singular : (plural ?? '${singular}s');
  return '$count $word';
}
