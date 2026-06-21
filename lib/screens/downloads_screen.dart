import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../services/playlist_service.dart';
import '../services/language_service.dart';
import '../widgets/playlist_helper.dart';
import './playlist_detail_screen.dart';
import './player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;
  const DownloadsScreen({super.key, required this.onNavigateToTab});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showCreatePlaylistDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context);
    final audioService = Provider.of<AudioService>(context);
    final playlistService = Provider.of<PlaylistService>(context);

    final allDownloads = [
      ...downloadService.downloadingItems,
      ...downloadService.downloadedItems
    ]..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

    // Filter list based on search query
    final filteredDownloads = allDownloads.where((item) {
      final titleMatch = item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final authorMatch = item.author.toLowerCase().contains(_searchQuery.toLowerCase());
      return titleMatch || authorMatch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: context.tr('search_downloads_placeholder'),
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                context.tr('offline_lib_btn'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (_isSearching) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _searchFocusNode.requestFocus();
                  });
                } else {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white),
              onPressed: () => _showCreatePlaylistDialog(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF2A5F),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          dividerColor: Colors.white10,
          tabs: [
            Tab(
              icon: const Icon(Icons.all_inclusive),
              text: context.tr('all'),
            ),
            Tab(
              icon: const Icon(Icons.playlist_play),
              text: context.tr('playlists'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. All Downloads Tab
          _buildDownloadsList(
            items: filteredDownloads,
            emptyMessage: _searchQuery.isNotEmpty 
                ? context.tr('no_matching_downloads') 
                : context.tr('no_downloads_hint'),
            onPlay: (item) {
              downloadService.markAsWatched(item.id);
              audioService.playTrack(item, contextPlaylist: filteredDownloads);
              if (item.isVideo) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black54,
                  builder: (context) => const PlayerScreen(),
                );
              }
            },
            onDelete: (item) => _confirmDelete(context, downloadService, item),
          ),

          // 2. Playlists Tab (Spotify style)
          _buildPlaylistsTab(playlistService, downloadService, audioService),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab(PlaylistService playlistService, DownloadService downloadService, AudioService audioService) {
    if (playlistService.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add, size: 80, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              context.tr('no_playlists'),
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('create_playlist_hint'),
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(context.tr('create_playlist'), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2A5F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Filter playlists by name if search is active
    final filteredPlaylists = playlistService.playlists.where((playlist) =>
      playlist.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    if (filteredPlaylists.isEmpty) {
      return Center(
        child: Text(context.tr('no_matching_playlists'), style: const TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filteredPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = filteredPlaylists[index];
        
        // Find the first track's thumbnail for the playlist cover, or use a default gradient
        String? coverPath;
        if (playlist.trackIds.isNotEmpty) {
          final firstTrack = downloadService.downloadedItems.firstWhere(
            (t) => t.id == playlist.trackIds.first,
            orElse: () => DownloadItem(
              id: '', title: '', author: '', durationMs: 0, thumbnailUrl: '', localFilePath: '', localThumbnailPath: '', fileSize: 0, downloadedAt: DateTime.now(), isVideo: true
            ),
          );
          if (firstTrack.id.isNotEmpty && File(firstTrack.localThumbnailPath).existsSync()) {
            coverPath = firstTrack.localThumbnailPath;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverPath != null
                  ? Image.file(
                      File(coverPath),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF2A5F),
                            Color(0xFFFF7E40),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white, size: 28),
                    ),
            ),
            title: Text(
              playlist.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${playlist.trackIds.length} ${context.tr('songs')}${playlist.description.isNotEmpty ? ' • ${playlist.description}' : ''}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1F1F35),
                    title: Text(context.tr('delete_playlist'), style: const TextStyle(color: Colors.white)),
                    content: Text('${context.tr('delete_playlist_confirm')} "${playlist.name}"?', style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.white38)),
                      ),
                      TextButton(
                        onPressed: () {
                          playlistService.deletePlaylist(playlist.id);
                          Navigator.pop(context);
                        },
                        child: Text(context.tr('delete'), style: const TextStyle(color: const Color(0xFFFF2A5F))),
                      ),
                    ],
                  ),
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaylistDetailScreen(playlist: playlist),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDownloadsList({
    required List<DownloadItem> items,
    required String emptyMessage,
    required Function(DownloadItem) onPlay,
    required Function(DownloadItem) onDelete,
  }) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final progress = downloadService.getProgress(item.id);
        final status = downloadService.getStatus(item.id);
        final isDownloading = progress != null;
        final isUnwatched = downloadService.unwatchedIds.contains(item.id);

        final thumbFile = File(item.localThumbnailPath);
        final fileExists = File(item.localFilePath).existsSync();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: thumbFile.existsSync()
                      ? Image.file(
                          thumbFile,
                          width: 80,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : item.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              item.thumbnailUrl,
                              width: 80,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 48,
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.video_collection,
                                  color: Colors.white24,
                                ),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 48,
                              color: Colors.grey[900],
                              child: const Icon(
                                  Icons.video_collection,
                                  color: Colors.white24,
                                ),
                            ),
                ),
                if (isUnwatched)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2A5F),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF161622), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A5F).withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.author,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (isDownloading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(status ?? 'downloading'),
                          style: const TextStyle(color: Color(0xFFFF2A5F), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        item.durationString,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.fileSizeString,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      if (!fileExists) ...[
                        const SizedBox(width: 8),
                        Text(
                          context.tr('file_error'),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ]
                    ],
                  ),
                ],
              ],
            ),
            trailing: isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.playlist_add, color: Colors.white70),
                        onPressed: () => showPlaylistSelectionBottomSheet(context, item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38),
                        onPressed: () => onDelete(item),
                      ),
                    ],
                  ),
            onTap: isDownloading ? null : (fileExists ? () => onPlay(item) : null),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, DownloadService downloadService, DownloadItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F35),
        title: Text(context.tr('remove_download'), style: const TextStyle(color: Colors.white)),
        content: Text(
          '${context.tr('remove_download_confirm')} \n\n"${item.title}"',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              downloadService.deleteDownload(item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${context.tr('deleted')}: ${item.title}')),
              );
            },
            child: Text(context.tr('delete'), style: const TextStyle(color: const Color(0xFFFF2A5F))),
          ),
        ],
      ),
    );
  }
}
