import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/download_item.dart';
import '../services/playlist_service.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import './player_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final playlistService = Provider.of<PlaylistService>(context);
    final downloadService = Provider.of<DownloadService>(context);
    final audioService = Provider.of<AudioService>(context);

    // Get the updated playlist from service in case it changed (added/deleted songs)
    final currentPlaylist = playlistService.playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );

    // Resolve downloaded items that are in this playlist
    final List<DownloadItem> playlistTracks = [];
    for (final trackId in currentPlaylist.trackIds) {
      final track = downloadService.downloadedItems.firstWhere(
        (t) => t.id == trackId,
        orElse: () => DownloadItem(
          id: '', title: '', author: '', durationMs: 0, thumbnailUrl: '', localFilePath: '', localThumbnailPath: '', fileSize: 0, downloadedAt: DateTime.now(), isVideo: true
        ),
      );
      if (track.id.isNotEmpty) {
        playlistTracks.add(track);
      }
    }

    String? coverPath;
    if (playlistTracks.isNotEmpty && File(playlistTracks.first.localThumbnailPath).existsSync()) {
      coverPath = playlistTracks.first.localThumbnailPath;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          // Spotify-style collapsing Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF161622),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                currentPlaylist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverPath != null
                      ? Image.file(
                          File(coverPath),
                          fit: BoxFit.cover,
                        )
                      : Container(
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
                          child: const Icon(Icons.music_note, color: Colors.white, size: 80),
                        ),
                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Playlist Info & Play Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentPlaylist.description.isNotEmpty) ...[
                    Text(
                      currentPlaylist.description,
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${playlistTracks.length} ${context.tr('songs')}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      if (playlistTracks.isNotEmpty)
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFFFF2A5F),
                          child: const Icon(Icons.play_arrow, color: Colors.white),
                          onPressed: () {
                            audioService.playTrack(playlistTracks.first, contextPlaylist: playlistTracks);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const PlayerScreen(),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (playlistTracks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          context.tr('empty_playlist_hint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Playlist Tracks list
          if (playlistTracks.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = playlistTracks[index];
                  final thumbFile = File(track.localThumbnailPath);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumbFile.existsSync()
                            ? Image.file(
                                thumbFile,
                                width: 72,
                                height: 44,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 72,
                                height: 44,
                                color: Colors.grey[900],
                                child: const Icon(Icons.video_collection, color: Colors.white24),
                              ),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.author,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                        onPressed: () async {
                          await playlistService.removeTrackFromPlaylist(currentPlaylist.id, track.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${context.tr('removed_from_playlist')} ${currentPlaylist.name}')),
                            );
                          }
                        },
                      ),
                      onTap: () {
                        downloadService.markAsWatched(track.id);
                        audioService.playTrack(track, contextPlaylist: playlistTracks);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const PlayerScreen(),
                        );
                      },
                    ),
                  );
                },
                childCount: playlistTracks.length,
              ),
            ),
        ],
      ),
    );
  }
}
