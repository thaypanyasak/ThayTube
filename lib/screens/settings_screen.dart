import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../services/language_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context);
    final currentLang = Provider.of<LanguageService>(context).currentLanguage;

    // Calculate total stats
    final totalDownloads = downloadService.downloadedItems.length;
    final totalSize = downloadService.downloadedItems.fold<int>(0, (sum, item) => sum + item.fileSize);
    
    // File size string conversion
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
              // Storage Stats Card
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
              const SizedBox(height: 32),

              // Menu Settings
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
            ],
          ),
        ),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
