import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import '../models/download_item.dart';
import './youtube_service.dart';
import './audio_handler.dart';

class AudioService extends ChangeNotifier {
  // ── Core players ─────────────────────────────────────────────────────────
  final ThayTubeAudioHandler _handler;

  /// Convenience getter: the underlying just_audio player inside the handler.
  AudioPlayer get _player => _handler.player;

  final YoutubeService _youtubeService = YoutubeService();
  VideoPlayerController? _videoController;

  // ── State ─────────────────────────────────────────────────────────────────
  DownloadItem? _currentTrack;
  List<DownloadItem> _playlist = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleModeEnabled = false;
  bool _isLoading = false;
  String? _lastCompletedTrackId;

  // ── Getters ───────────────────────────────────────────────────────────────
  DownloadItem? get currentTrack => _currentTrack;
  List<DownloadItem> get playlist => _playlist;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  LoopMode get loopMode => _loopMode;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  bool get isLoading => _isLoading;
  VideoPlayerController? get videoController => _videoController;

  AudioService(this._handler) {
    _init();
  }

  void _init() {
    _initAudioSession();

    // Listen to OS "next/previous" commands forwarded via customEvent
    _handler.customEvent.listen((event) {
      if (event == 'next') next();
      if (event == 'previous') previous();
    });

    // Listen to player state (Always drive UI from _player)
    _player.playerStateStream.listen((state) {
      if (_currentTrack != null) {
        _isPlaying = state.playing;

        // Keep video player in sync with main audio player play/pause state
        if (_videoController != null && _videoController!.value.isInitialized) {
          if (state.playing && !_videoController!.value.isPlaying) {
            _videoController!.play();
          } else if (!state.playing && _videoController!.value.isPlaying) {
            _videoController!.pause();
          }
        }

        if (state.processingState == ProcessingState.completed) {
          _handleTrackCompleted();
        }
        notifyListeners();
      }
    });

    DateTime lastVideoSync = DateTime.now();

    // Listen to position (Sync video controller drift if needed)
    _player.positionStream.listen((pos) {
      if (_currentTrack != null) {
        _position = pos;

        if (_videoController != null && 
            _videoController!.value.isInitialized && 
            !_videoController!.value.isBuffering) {
          final now = DateTime.now();
          if (now.difference(lastVideoSync).inSeconds >= 3) {
            final diff = (pos - _videoController!.value.position).inMilliseconds.abs();
            if (diff > 1500) {
              lastVideoSync = now;
              _videoController!.seekTo(pos);
            }
          }
        }
      }
    });

    // Listen to duration
    _player.durationStream.listen((dur) {
      if (_currentTrack != null) {
        _duration = dur ?? Duration.zero;
        notifyListeners();
      }
    });

    // Listen to buffered position
    _player.bufferedPositionStream.listen((buf) {
      if (_currentTrack != null) {
        _bufferedPosition = buf;
        notifyListeners();
      }
    });
  }

  Future<void> _stopControllers({bool stopAudio = true}) async {
    if (stopAudio && _player.playing) {
      await _player.stop();
    }
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoControllerUpdate);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    if (stopAudio) {
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _bufferedPosition = Duration.zero;
    }
  }

  void _onVideoControllerUpdate() {
    if (_videoController == null) return;
    
    // If the video controller is playing but audio isn't, pause it.
    if (_videoController!.value.isPlaying && !_player.playing) {
      _videoController!.pause();
    }
  }

  // ── Play a track ──────────────────────────────────────────────────────────
  Future<void> playTrack(DownloadItem track, {List<DownloadItem>? contextPlaylist}) async {
    if (_currentTrack?.id == track.id) {
      if (contextPlaylist != null) {
        _playlist = List.from(contextPlaylist);
        _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
        if (_currentIndex == -1) {
          _playlist.insert(0, track);
          _currentIndex = 0;
        }
      }
      if (!_isPlaying) {
        _player.play();
        if (_videoController != null) {
          _videoController!.play();
        }
        _isPlaying = true;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    _lastCompletedTrackId = null; // Reset completed status for the new track
    await _stopControllers(stopAudio: false);
    _currentTrack = track;
    notifyListeners();

    // Record to watch history
    try {
      YoutubeService.recordWatchHistory(track.id, track.title, track.author);
    } catch (e) {
      debugPrint('Error recording watch history: $e');
    }

    try {
      if (contextPlaylist != null) {
        _playlist = List.from(contextPlaylist);
        _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
      } else {
        _playlist = [track];
        _currentIndex = 0;
      }
      if (_currentIndex == -1) {
        _playlist.insert(0, track);
        _currentIndex = 0;
      }

      // Resolve file path first
      File file = File(track.localFilePath);
      if (!file.existsSync() && track.localFilePath.isNotEmpty) {
        final lastDot = track.localFilePath.lastIndexOf('.');
        if (lastDot != -1) {
          final pathWithoutExt = track.localFilePath.substring(0, lastDot);
          final altPath = track.localFilePath.endsWith('.m4a')
              ? '$pathWithoutExt.mp4'
              : '$pathWithoutExt.m4a';
          final altFile = File(altPath);
          if (altFile.existsSync()) {
            file = altFile;
          }
        }
      }

      final playsAsVideo =
          track.isVideo || (file.existsSync() && file.path.endsWith('.mp4'));

      StreamManifest? manifest;

      // 1. Play the Audio stream/file via just_audio (_player) for background capability
      if (file.existsSync()) {
        await _player.setAudioSource(AudioSource.file(file.path), initialPosition: Duration.zero);
      } else {
        manifest = await _youtubeService.getStreamManifest(track.id);
        
        final AudioStreamInfo selectedAudioStream;
        if (Platform.isIOS) {
          // iOS AVPlayer does not support Opus/WebM natively. Select highest quality AAC (M4A) stream.
          final aacStreams = manifest.audioOnly
              .where((s) => s.container.name == 'm4a' || s.container.name == 'mp4' || s.audioCodec.contains('mp4a'))
              .toList();
          if (aacStreams.isNotEmpty) {
            aacStreams.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
            selectedAudioStream = aacStreams.first;
          } else {
            selectedAudioStream = manifest.audioOnly.withHighestBitrate();
          }
        } else {
          // Android (ExoPlayer natively plays Opus/WebM at peak quality)
          selectedAudioStream = manifest.audioOnly.withHighestBitrate();
        }
        
        await _player.setAudioSource(AudioSource.uri(selectedAudioStream.url), initialPosition: Duration.zero);
      }

      // Start main audio playback immediately
      _player.play(); // DO NOT await play() as it blocks until playback finishes or pauses
      _isPlaying = true;

      // Update lock screen / Control Center metadata
      _handler.updateNowPlayingInfo(
        id: track.id,
        title: track.title,
        artist: track.author,
        artUri: track.thumbnailUrl,
        duration: Duration(milliseconds: track.durationMs),
      );

      // 2. If it has a video track, load the video feed via VideoPlayerController (MUTED) asynchronously
      if (playsAsVideo) {
        final VideoPlayerController controller;
        if (file.existsSync()) {
          controller = VideoPlayerController.file(
            file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          manifest ??= await _youtubeService.getStreamManifest(track.id);
          
          VideoStreamInfo? videoStream;
          if (manifest.video.isNotEmpty) {
            videoStream = manifest.video.withHighestBitrate();
          } else if (manifest.muxed.isNotEmpty) {
            videoStream = manifest.muxed.withHighestBitrate();
          }
          
          if (videoStream == null) {
            throw Exception('No video streams found in manifest');
          }

          controller = VideoPlayerController.networkUrl(
            videoStream.url,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }

        _videoController = controller;

        // Initialize asynchronously in the background so it doesn't block the start of audio play
        controller.initialize().then((_) async {
          if (_videoController == controller) {
            await controller.setVolume(0.0);
            controller.addListener(_onVideoControllerUpdate);
            
            // Sync current audio position
            final currentAudioPos = _player.position;
            await controller.seekTo(currentAudioPos);

            if (_player.playing) {
              await controller.play();
            }
            notifyListeners();
          }
        }).catchError((e) {
          debugPrint('Error initializing video controller: $e');
        });
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Play / Pause toggle ───────────────────────────────────────────────────
  Future<void> togglePlay() async {
    if (_currentTrack == null) return;

    if (_isPlaying) {
      await _player.pause();
      if (_videoController != null) {
        await _videoController!.pause();
      }
    } else {
      _player.play();
      if (_videoController != null) {
        _videoController!.play();
      }
    }
  }

  // ── Seek ──────────────────────────────────────────────────────────────────
  Future<void> seek(Duration position) async {
    if (_currentTrack == null) return;
    await _player.seek(position);
    if (_videoController != null) {
      await _videoController!.seekTo(position);
    }
  }

  // ── Stop ──────────────────────────────────────────────────────────────────
  Future<void> stop() async {
    await _stopControllers();
    _currentTrack = null;
    _playlist.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  // ── Next / Previous ───────────────────────────────────────────────────────
  Future<void> next() async {
    if (_playlist.isEmpty || _currentIndex == -1) return;

    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) {
      if (_loopMode == LoopMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }

    _currentIndex = nextIndex;
    await playTrack(_playlist[_currentIndex]);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty || _currentIndex == -1) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      if (_loopMode == LoopMode.all) {
        prevIndex = _playlist.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    _currentIndex = prevIndex;
    await playTrack(_playlist[_currentIndex]);
  }

  // ── Loop / Shuffle ────────────────────────────────────────────────────────
  void toggleLoopMode() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.one;
      _player.setLoopMode(LoopMode.one);
    } else if (_loopMode == LoopMode.one) {
      _loopMode = LoopMode.all;
      _player.setLoopMode(LoopMode.all);
    } else {
      _loopMode = LoopMode.off;
      _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleModeEnabled = !_shuffleModeEnabled;
    _player.setShuffleModeEnabled(_shuffleModeEnabled);
    notifyListeners();
  }

  void _handleTrackCompleted() {
    if (_currentTrack == null || _isLoading) return;

    // Prevent duplicate completion events for the same track
    if (_lastCompletedTrackId == _currentTrack!.id) {
      return;
    }
    _lastCompletedTrackId = _currentTrack!.id;

    if (_loopMode == LoopMode.one) {
      // handled by just_audio itself
    } else {
      next();
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
