import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class DeviceId {
  static const _key = 'device_id';
  static String? _cachedId;

  static Future<String> getId() async {
    if (_cachedId != null) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();
    _cachedId = prefs.getString(_key);

    if (_cachedId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedId = iosInfo.identifierForVendor;
      }
      
      _cachedId ??= DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_key, _cachedId!);
    }

    return _cachedId!;
  }
} 