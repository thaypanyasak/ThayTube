import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final DownloadItem downloadItem;

  const VideoPlayerScreen({super.key, required this.downloadItem});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    
    // Pause any playing audio first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AudioService>(context, listen: false).stop();
    });

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.downloadItem.localFilePath);
      if (!file.existsSync()) {
        setState(() {
          _hasError = true;
        });
        return;
      }

      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        allowPlaybackSpeedChanging: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        showControlsOnInitialize: true,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        // Stylize Chewie
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFF2A5F),
          handleColor: const Color(0xFFFF2A5F),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    // Force portrait mode on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.downloadItem.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('video_play_error'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              )
            : (_chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('loading_video'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
      ),
    );
  }
}
