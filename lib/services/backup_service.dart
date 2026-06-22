import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys stored in SharedPreferences that we want to back up & restore.
const _backupKeys = [
  'downloaded_items',
  'unwatched_download_ids',
  'user_playlists',
  'user_profile_name',
  'user_profile_avatar_path',
  'toasted_download_ids',
  'app_language',
];

class BackupService {
  /// Export: writes a JSON backup file and shares it via the system share sheet.
  static Future<String?> exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};
      for (final key in _backupKeys) {
        final value = prefs.get(key);
        if (value != null) data[key] = value;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/thaytube_backup.json');
      await file.writeAsString(jsonEncode(data));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: 'ThayTube Backup',
          subject: 'thaytube_backup.json',
        ),
      );
      return null; // success
    } catch (e) {
      debugPrint('Backup export error: $e');
      return 'Lỗi khi xuất backup: $e';
    }
  }

  /// Import: reads a JSON backup file from disk and restores all keys.
  static Future<String?> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return 'Không tìm thấy file backup.';

      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;
        if (!_backupKeys.contains(key)) continue; // safety: only restore known keys
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }
      return null; // success
    } catch (e) {
      debugPrint('Backup import error: $e');
      return 'Lỗi khi khôi phục backup: $e';
    }
  }
}
