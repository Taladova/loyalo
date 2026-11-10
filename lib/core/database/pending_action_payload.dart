import 'dart:convert';

abstract final class PendingActionPayload {
  static String encode(Map<String, Object?> payload) => jsonEncode(payload);

  static Map<String, Object?> decode(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'PendingAction payload must be a JSON object.',
      );
    }
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
}
