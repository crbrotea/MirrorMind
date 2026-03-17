import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages a persistent anonymous user ID for the current device.
///
/// The ID is stored in [SharedPreferences] and persists across app launches.
/// A new UUID v4 is generated on first use.
class UserIdService {
  static const String _key = 'mirrormind_user_id';
  static const Uuid _uuid = Uuid();

  /// Returns the stored user ID, or generates and persists a new one.
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newId = _uuid.v4();
    await prefs.setString(_key, newId);
    return newId;
  }
}
