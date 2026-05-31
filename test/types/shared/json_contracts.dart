import 'dart:convert';

Map<String, dynamic> decodeJsonObject(String raw) {
  return (jsonDecode(raw) as Map).cast<String, dynamic>();
}
