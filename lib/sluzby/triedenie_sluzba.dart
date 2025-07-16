import 'package:shared_preferences/shared_preferences.dart';

class TriedenieSluzba {
  static const _key = 'typTriedenia';
  static const _keySmer = 'smerTriedenia';

  static Future<void> uloz(String typ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, typ);
  }

  static Future<String> nacitaj() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'termin';
  }

  static Future<void> ulozSmer(bool vzostupne) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmer, vzostupne);
  }

  static Future<bool> nacitajSmer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySmer) ?? true;
  }
}
