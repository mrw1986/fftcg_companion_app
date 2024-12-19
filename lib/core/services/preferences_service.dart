// lib/core/services/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static Future<bool> setValue<T>(String key, T value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is String) {
        return await prefs.setString(key, value);
      } else if (value is int) {
        return await prefs.setInt(key, value);
      } else if (value is bool) {
        return await prefs.setBool(key, value);
      } else if (value is double) {
        return await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        return await prefs.setStringList(key, value);
      }
      return false;
    } catch (e) {
      // Log error and return false
      return false;
    }
  }

  static Future<T?> getValue<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.get(key) as T?;
    } catch (e) {
      // Log error and return null
      return null;
    }
  }
}
