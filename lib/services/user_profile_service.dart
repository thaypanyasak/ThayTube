import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService extends ChangeNotifier {
  static const _keyName = 'user_profile_name';
  static const _keyAvatar = 'user_profile_avatar_path';

  String _displayName = 'ThayTube User';
  String? _avatarPath; // null = use default asset

  String get displayName => _displayName;
  String? get avatarPath => _avatarPath;

  UserProfileService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString(_keyName) ?? 'ThayTube User';
    _avatarPath = prefs.getString(_keyAvatar);
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    _displayName = name.trim().isEmpty ? 'ThayTube User' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, _displayName);
    notifyListeners();
  }

  Future<void> updateAvatar(String path) async {
    _avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatar, path);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    _avatarPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAvatar);
    notifyListeners();
  }
}
