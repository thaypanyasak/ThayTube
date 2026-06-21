import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  List<String> _previouslyDownloadedIds = [];
  bool _isFirstLoad = true;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final downloadService = Provider.of<DownloadService>(context);

    final currentIds = downloadService.downloadedItems.map((item) => item.id).toList();

    if (_isFirstLoad) {
      _previouslyDownloadedIds = currentIds;
      _isFirstLoad = false;
    } else {
      // Find new downloads
      for (final id in currentIds) {
        if (!_previouslyDownloadedIds.contains(id)) {
          final newItem = downloadService.downloadedItems.firstWhere((item) => item.id == id);
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CustomToast.show(
              context,
              '${newItem.title} - ${context.tr('download_success')}',
              icon: Icons.check_circle_rounded,
              color: Colors.greenAccent,
            );
          });
        }
      }
      _previouslyDownloadedIds = currentIds;
    }

    final badgeCount = downloadService.downloadingItems.length + downloadService.unwatchedIds.length;

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
            top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.0),
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
