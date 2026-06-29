import 'dart:convert';

Map<String, Object?>? decodePersistedJsonMap(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }
    return Map<String, Object?>.from(decoded);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

List<Object?>? decodePersistedJsonList(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return null;
    }
    return List<Object?>.from(decoded);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
