import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helpers for reading loosely-typed Firestore data safely.

DateTime? parseDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int parseInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return fallback;
}

String parseString(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

bool parseBool(Object? value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

T parseEnum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
