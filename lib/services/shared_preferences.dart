import '../data/db_helper.dart';

/// Un wrapper simple que simula SharedPreferences usando la tabla 'settings'
/// de SQLite, evitando dependencias nativas de compilación C++ en Windows.
class SharedPreferences {
  static SharedPreferences? _instance;
  final Map<String, dynamic> _data;

  SharedPreferences._(this._data);

  static Future<SharedPreferences> getInstance() async {
    if (_instance == null) {
      final data = await DBHelper.instance.getSettings();
      _instance = SharedPreferences._(data);
    }
    return _instance!;
  }

  static void setMockInitialValues(Map<String, dynamic> values) {
    _instance = SharedPreferences._(Map<String, dynamic>.from(values));
  }

  bool? getBool(String key) {
    return _data[key] as bool?;
  }

  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    await DBHelper.instance.saveSetting(key, value ? 1 : 0);
    return true;
  }
}
