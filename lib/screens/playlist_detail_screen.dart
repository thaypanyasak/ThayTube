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
                              enableDrag: false,
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
                  final isPlayingTrack = audioService.currentTrack?.id == track.id;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPlayingTrack ? const Color(0xFF1E1E30) : const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlayingTrack 
                            ? const Color(0xFFFF2A5F).withValues(alpha: 0.35) 
                            : Colors.transparent,
                        width: isPlayingTrack ? 1.5 : 1.0,
                      ),
                      boxShadow: isPlayingTrack ? [
                        BoxShadow(
                          color: const Color(0xFFFF2A5F).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          if (isPlayingTrack)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF2A5F),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFF2A5F),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ListTile(
                            contentPadding: EdgeInsets.only(
                              left: isPlayingTrack ? 16 : 12,
                              right: 12,
                              top: 4,
                              bottom: 4,
                            ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            thumbFile.existsSync()
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
                            if (isPlayingTrack)
                              Container(
                                width: 72,
                                height: 44,
                                color: Colors.black.withValues(alpha: 0.65),
                                child: Center(
                                  child: audioService.isPlaying
                                      ? const MiniEqualizer()
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          color: isPlayingTrack ? const Color(0xFFFF5281) : Colors.white,
                          fontWeight: isPlayingTrack ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.author,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
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
                          enableDrag: false,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const PlayerScreen(),
                        );
                      },
                    ),
                  ],
                ),
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

class MiniEqualizer extends StatefulWidget {
  const MiniEqualizer({super.key});

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animations = List.generate(3, (index) {
      final begin = 0.2 + (index * 0.25);
      return Tween<double>(begin: begin, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(index * 0.2, 1.0, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 3.0,
              height: 14 * _animations[index].value,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2A5F),
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2A5F).withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
