import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<List<Map<String, dynamic>>> loadLevels() async {
  final jsonStr = await rootBundle.loadString('levels/levels.jsonc');
  final List<dynamic> data = json.decode(jsonStr);
  return data.cast<Map<String, dynamic>>();
}
