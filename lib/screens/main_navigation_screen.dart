import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/download_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/custom_toast.dart';
import './downloads_screen.dart';
import './home_screen.dart';
import './settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // IDs that have already been toasted — loaded from AND saved to
  // SharedPreferences so they persist across widget rebuilds AND app restarts.
  final Set<String> _toastedIds = {};
  bool _toastedIdsLoaded = false;

  DownloadService? _downloadService;

  @override
  void initState() {
    super.initState();
    _loadToastedIds();
  }

  /// Load previously toasted IDs from disk so we never re-toast on app relaunch.
  Future<void> _loadToastedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('toasted_download_ids') ?? [];
    if (mounted) {
      setState(() {
        _toastedIds.addAll(saved);
        _toastedIdsLoaded = true;
      });
    }
  }

  Future<void> _saveToastedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('toasted_download_ids', _toastedIds.toList());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ds = Provider.of<DownloadService>(context, listen: false);
    if (_downloadService != ds) {
      _downloadService?.removeListener(_onDownloadsChanged);
      _downloadService = ds;
      ds.addListener(_onDownloadsChanged);
    }
  }

  @override
  void dispose() {
    _downloadService?.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  void _onDownloadsChanged() {
    // Wait until we've loaded the persisted IDs from disk before showing
    // any toasts — prevents false positives during the async startup load.
    if (!mounted || _downloadService == null || !_toastedIdsLoaded) return;

    final ds = _downloadService!;
    bool anyNew = false;
    final successMsg = Provider.of<LanguageService>(context, listen: false).translate('download_success');

    for (final item in ds.downloadedItems) {
      if (!_toastedIds.contains(item.id)) {
        _toastedIds.add(item.id);
        anyNew = true;
        // Show toast exactly once per completed download.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          CustomToast.show(
            context,
            '${item.title} - $successMsg',
            icon: Icons.check_circle_rounded,
            color: Colors.greenAccent,
          );
        });
      }
    }
    if (anyNew) _saveToastedIds();
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final downloadService = Provider.of<DownloadService>(context);

    final badgeCount = downloadService.downloadingItems.length +
        downloadService.unwatchedIds.length;

    if (!authService.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF2A5F),
          ),
        ),
      );
    }

    final List<Widget> pages = [
      HomeScreen(onNavigateToTab: _navigateToTab),
      DownloadsScreen(onNavigateToTab: _navigateToTab),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Current Tab View
          IndexedStack(index: _currentIndex, children: pages),

          // Floating Mini Player (anchored right on top of the bottom navigation bar)
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          backgroundColor: const Color(0xFF0F0F1A),
          selectedItemColor: const Color(0xFFFF2A5F),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: context.tr('home'),
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                child: const Icon(Icons.cloud_download_outlined),
              ),
              activeIcon: const Icon(Icons.cloud_download_rounded),
              label: context.tr('library'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings_rounded),
              label: context.tr('settings'),
            ),
          ],
        ),
      ),
    );
  }
}
