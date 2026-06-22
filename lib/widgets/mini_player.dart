import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioService>(context);
    final track = audioService.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final isLocal = File(track.localThumbnailPath).existsSync();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (context) => const PlayerScreen(),
        );
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF161622).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Info & Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Cover Art
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                                  child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Title and Author
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.author,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Controls
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                      onPressed: audioService.previous,
                    ),
                    audioService.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              audioService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: audioService.togglePlay,
                          ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                      onPressed: audioService.next,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: audioService.stop,
                    ),
                  ],
                ),
              ),

              // Bottom Progress Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 3,
                  child: StreamBuilder<Duration>(
                    stream: audioService.positionStream,
                    initialData: audioService.position,
                    builder: (context, snapshot) {
                      final currentPosition = snapshot.data ?? Duration.zero;
                      final totalDuration = audioService.duration;
                      final progress = totalDuration.inMilliseconds > 0
                          ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
