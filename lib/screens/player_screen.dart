import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../services/audio_service.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';
import '../services/language_service.dart';
import '../widgets/download_selector.dart';
import '../widgets/playlist_helper.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getLoopIcon(LoopMode mode) {
    switch (mode) {
      case LoopMode.one:
        return Icons.repeat_one;
      case LoopMode.all:
        return Icons.repeat;
      case LoopMode.off:
      default:
        return Icons.repeat;
    }
  }

  Widget _buildThumbnailView(dynamic track, bool isLocal) {
    return RepaintBoundary(
      child: isLocal
          ? Image.file(
              File(track.localThumbnailPath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Image.network(
              track.thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
              ),
            ),
    );
  }

  Widget _buildVideoView(AudioService audioService) {
    if (audioService.videoController != null && audioService.videoController!.value.isInitialized) {
      return RepaintBoundary(
        child: Center(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: audioService.videoController!.value.size.width > 0
                    ? audioService.videoController!.value.size.width
                    : 16,
                height: audioService.videoController!.value.size.height > 0
                    ? audioService.videoController!.value.size.height
                    : 9,
                child: VideoPlayer(audioService.videoController!),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioService>(context);
    final downloadService = Provider.of<DownloadService>(context);
    
    final track = audioService.currentTrack;
    if (track == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text(context.tr('no_track_playing'), style: const TextStyle(color: Colors.white))),
      );
    }

    final isLocal = File(track.localThumbnailPath).existsSync();
    final file = File(track.localFilePath);
    final isMp4 = file.existsSync() && file.path.endsWith('.mp4');
    final hasVideo = track.isVideo || isMp4 || (audioService.videoController != null && audioService.videoController!.value.isInitialized);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // 1. Zoomed & Blurred Background (Video or Image)
          Positioned.fill(
            child: ClipRect(
              child: _currentPage == 1 && track.isVideo && audioService.videoController != null && audioService.videoController!.value.isInitialized
                  ? Transform.scale(
                      scale: 3.5,
                      child: Opacity(
                        opacity: 0.35,
                        child: VideoPlayer(audioService.videoController!),
                      ),
                    )
                  : Transform.scale(
                      scale: 1.8,
                      child: Opacity(
                        opacity: 0.35,
                        child: isLocal
                            ? Image.file(
                                File(track.localThumbnailPath),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                track.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                                ),
                              ),
                      ),
                    ),
            ),
          ),
          
          // 2. Translucent overlay to darken and blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: const Color(0xFF0F0F1A).withOpacity(0.65),
              ),
            ),
          ),

          // 3. Main Player UI Content
          SafeArea(
            child: Column(
              children: [
                // Top controls bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          Text(
                            context.tr('now_playing'),
                            style: const TextStyle(
                              color: Color(0xFFFF2A5F),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ThayTube Premium',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (downloadService.isDownloaded(track.id))
                            IconButton(
                              icon: const Icon(Icons.playlist_add, color: Colors.white70),
                              onPressed: () => showPlaylistSelectionBottomSheet(context, track),
                            ),
                          IconButton(
                            icon: Icon(
                              downloadService.isDownloaded(track.id)
                                  ? Icons.download_done_rounded
                                  : Icons.download_for_offline_outlined,
                              color: downloadService.isDownloaded(track.id)
                                  ? const Color(0xFFFF2A5F)
                                  : Colors.white70,
                            ),
                            onPressed: () async {
                              if (downloadService.isDownloaded(track.id)) {
                                // Option to delete
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1F1F35),
                                    title: Text(context.tr('remove_download'), style: const TextStyle(color: Colors.white)),
                                    content: Text('${context.tr('remove_download_confirm')} \n\n"${track.title}"', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.white38)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          downloadService.deleteDownload(track.id);
                                          Navigator.pop(context);
                                        },
                                        child: Text(context.tr('delete'), style: const TextStyle(color: const Color(0xFFFF2A5F))),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                try {
                                  final ytService = YoutubeService();
                                  final video = await ytService.getVideoDetails(track.id);
                                  ytService.dispose();
                                  if (context.mounted) {
                                    showDownloadQualitySelector(context, video);
                                  }
                                } catch (e) {
                                  debugPrint('Error downloading inside player: $e');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Media Album Art Container
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A5F).withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: hasVideo
                        ? GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity == null) return;
                              if (details.primaryVelocity! < -200 && _currentPage == 0) {
                                setState(() => _currentPage = 1);
                              } else if (details.primaryVelocity! > 200 && _currentPage == 1) {
                                setState(() => _currentPage = 0);
                              }
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: _currentPage == 0
                                  ? KeyedSubtree(
                                      key: const ValueKey('thumb'),
                                      child: _buildThumbnailView(track, isLocal),
                                    )
                                  : KeyedSubtree(
                                      key: const ValueKey('video'),
                                      child: _buildVideoView(audioService),
                                    ),
                            ),
                          )
                        : _buildThumbnailView(track, isLocal),
                  ),
                ),

                if (hasVideo) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _currentPage == 0 ? Icons.image_rounded : Icons.image_outlined,
                        size: 16,
                        color: _currentPage == 0 ? const Color(0xFFFF2A5F) : Colors.white38,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage == 1 ? Icons.videocam_rounded : Icons.videocam_outlined,
                        size: 16,
                        color: _currentPage == 1 ? const Color(0xFFFF2A5F) : Colors.white38,
                      ),
                    ],
                  ),
                ],

                const Spacer(),

                // Song Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.author,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progress Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF2A5F),
                          inactiveTrackColor: Colors.white12,
                          trackHeight: 4.0,
                          thumbColor: const Color(0xFFFF2A5F),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayColor: const Color(0xFFFF2A5F).withAlpha(32),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: audioService.duration.inMilliseconds.toDouble(),
                          value: audioService.position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, audioService.duration.inMilliseconds.toDouble()),
                          onChanged: (value) {
                            audioService.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(audioService.position),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(audioService.duration),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: audioService.shuffleModeEnabled
                              ? const Color(0xFFFF2A5F)
                              : Colors.white38,
                        ),
                        onPressed: audioService.toggleShuffle,
                      ),
                      
                      // Previous
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                        onPressed: audioService.previous,
                      ),

                      // Play / Pause with glowing circular structure
                      GestureDetector(
                        onTap: audioService.togglePlay,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF2A5F),
                                Color(0xFFFF7E40),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2A5F).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: audioService.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Icon(
                                    audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                          ),
                        ),
                      ),

                      // Next
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                        onPressed: audioService.next,
                      ),

                      // Repeat
                      IconButton(
                        icon: Icon(
                          _getLoopIcon(audioService.loopMode),
                          color: audioService.loopMode != LoopMode.off
                              ? const Color(0xFFFF2A5F)
                              : Colors.white38,
                        ),
                        onPressed: audioService.toggleLoopMode,
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
