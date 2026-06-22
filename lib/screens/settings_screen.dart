import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/download_service.dart';
import '../services/language_service.dart';
import '../services/user_profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getLanguageName(String code) {
    switch (code) {
      case 'vi':
        return 'Tiếng Việt';
      case 'th':
        return 'ไทย';
      case 'lo':
        return 'ລາວ';
      case 'en':
      default:
        return 'English';
    }
  }

  // ── Language picker ───────────────────────────────────────────────────────

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final langService = Provider.of<LanguageService>(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    context.tr('select_language'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                _buildLanguageTile(context, langService, 'en', 'English', '🇺🇸'),
                _buildLanguageTile(context, langService, 'vi', 'Tiếng Việt', '🇻🇳'),
                _buildLanguageTile(context, langService, 'th', 'ไทย', '🇹🇭'),
                _buildLanguageTile(context, langService, 'lo', 'ລາວ', '🇱🇦'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    LanguageService langService,
    String code,
    String name,
    String flag,
  ) {
    final isSelected = langService.currentLanguage == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFF2A5F) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFFFF2A5F)) : null,
      onTap: () {
        langService.changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  // ── Profile edit dialog ───────────────────────────────────────────────────

  void _showEditProfileDialog(BuildContext context, UserProfileService profileService) {
    final controller = TextEditingController(text: profileService.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chỉnh sửa tên', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nhập tên của bạn',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF2A5F)),
            ),
            filled: true,
            fillColor: const Color(0xFF0F0F1A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              profileService.updateName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu', style: TextStyle(color: Color(0xFFFF2A5F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(UserProfileService profileService) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      await profileService.updateAvatar(picked.path);
    }
  }

  // ── Backup / Restore ─────────────────────────────────────────────────────

  Future<void> _doExport(BuildContext context) async {
    final error = await BackupService.exportBackup();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _doImport(BuildContext context) async {
    // Ask user to pick a file using text-field path (simple approach without file_picker)
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Khôi phục Backup', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dán đường dẫn đến file thaytube_backup.json:',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '/path/to/thaytube_backup.json',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF2A5F)),
                ),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Ứng dụng sẽ cần khởi động lại để dữ liệu có hiệu lực.',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục', style: TextStyle(color: Color(0xFFFF2A5F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final error = await BackupService.importBackup(controller.text.trim());
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Khôi phục thành công! Vui lòng khởi động lại ứng dụng.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context);
    final currentLang = Provider.of<LanguageService>(context).currentLanguage;
    final profileService = Provider.of<UserProfileService>(context);

    // Storage stats
    final totalDownloads = downloadService.downloadedItems.length;
    final totalSize = downloadService.downloadedItems.fold<int>(0, (sum, item) => sum + item.fileSize);

    String totalSizeString = '0 B';
    if (totalSize > 0) {
      double size = totalSize.toDouble();
      const suffixes = ['B', 'KB', 'MB', 'GB'];
      var i = 0;
      while (size >= 1024 && i < suffixes.length - 1) {
        size /= 1024;
        i++;
      }
      totalSizeString = '${size.toStringAsFixed(1)} ${suffixes[i]}';
    }

    final filesUnit = context.tr('files');

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('settings'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Card ──────────────────────────────────────────────
              _buildProfileCard(context, profileService),

              const SizedBox(height: 28),

              // ── Storage Stats Card ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, color: Color(0xFFFF2A5F)),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('storage_stats'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(context.tr('download'), '$totalDownloads $filesUnit', Icons.cloud_download),
                        Container(width: 1, height: 40, color: Colors.white10),
                        _buildStatItem(context.tr('total_size'), totalSizeString, Icons.storage),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── General Settings ──────────────────────────────────────────
              _buildSectionLabel('Cài đặt chung'),
              const SizedBox(height: 12),
              _buildMenuTile(
                icon: Icons.language_rounded,
                title: context.tr('language'),
                subtitle: _getLanguageName(currentLang),
                onTap: () => _showLanguageSelector(context),
              ),
              _buildMenuTile(
                icon: Icons.favorite_border_rounded,
                title: context.tr('favorite_list'),
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.history_rounded,
                title: context.tr('play_history'),
                onTap: () {},
              ),

              const SizedBox(height: 28),

              // ── Backup / Restore ──────────────────────────────────────────
              _buildSectionLabel('Dữ liệu & Sao lưu'),
              const SizedBox(height: 12),
              _buildMenuTile(
                icon: Icons.upload_rounded,
                title: 'Xuất Backup',
                subtitle: 'Lưu danh sách tải, playlist ra file',
                onTap: () => _doExport(context),
                iconColor: const Color(0xFF4FC3F7),
              ),
              _buildMenuTile(
                icon: Icons.download_rounded,
                title: 'Khôi phục Backup',
                subtitle: 'Nhập file backup để khôi phục dữ liệu',
                onTap: () => _doImport(context),
                iconColor: const Color(0xFF81C784),
              ),

              const SizedBox(height: 24),

              // ── Data safety note ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withOpacity(0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Khi cài đặt phiên bản mới đè lên, hãy xuất Backup trước để tránh mất dữ liệu. Sau khi cài xong, dùng chức năng Khôi phục để lấy lại.',
                        style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile card widget ───────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context, UserProfileService profileService) {
    final avatarPath = profileService.avatarPath;
    final hasCustomAvatar = avatarPath != null && File(avatarPath).existsSync();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E2E), Color(0xFF161622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2A5F).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: () => _pickAvatar(profileService),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A5F), Color(0xFFFF7E40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A5F).withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasCustomAvatar
                        ? Image.file(
                            File(avatarPath),
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          )
                        : Image.asset(
                            'lib/assets/img/profile.png',
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          ),
                  ),
                ),
              ),
              // Camera edit badge
              GestureDetector(
                onTap: () => _pickAvatar(profileService),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2A5F),
                    border: Border.all(color: const Color(0xFF0F0F1A), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A5F).withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          GestureDetector(
            onTap: () => _showEditProfileDialog(context, profileService),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profileService.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, color: Color(0xFFFF2A5F), size: 16),
              ],
            ),
          ),

          const SizedBox(height: 4),
          const Text(
            'Nhấn vào tên hoặc ảnh để chỉnh sửa',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Shared small widgets ──────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
