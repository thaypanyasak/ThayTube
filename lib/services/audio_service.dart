import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import '../models/download_item.dart';
import './youtube_service.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _youtubeService = YoutubeService();
  VideoPlayerController? _videoController;

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

  // Getters
  DownloadItem? get currentTrack => _currentTrack;
  List<DownloadItem> get playlist => _playlist;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  LoopMode get loopMode => _loopMode;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  bool get isLoading => _isLoading;
  VideoPlayerController? get videoController => _videoController;

  AudioService() {
    _init();
  }

  void _init() {
    _initAudioSession();

    // Listen to player state
    _player.playerStateStream.listen((state) {
      if (_currentTrack != null && _videoController == null) {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _handleTrackCompleted();
        }
        notifyListeners();
      }
    });

    // Listen to position
    _player.positionStream.listen((pos) {
      if (_currentTrack != null && _videoController == null) {
        _position = pos;
        notifyListeners();
      }
    });

    // Listen to duration
    _player.durationStream.listen((dur) {
      if (_currentTrack != null && _videoController == null) {
        _duration = dur ?? Duration.zero;
        notifyListeners();
      }
    });

    // Listen to buffered position
    _player.bufferedPositionStream.listen((buf) {
      if (_currentTrack != null && _videoController == null) {
        _bufferedPosition = buf;
        notifyListeners();
      }
    });
  }

  Future<void> _stopControllers() async {
    if (_player.playing) {
      await _player.stop();
    }
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoControllerUpdate);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _bufferedPosition = Duration.zero;
  }

  void _onVideoControllerUpdate() {
    if (_videoController == null) return;
    _position = _videoController!.value.position;
    _duration = _videoController!.value.duration;
    _isPlaying = _videoController!.value.isPlaying;
    
    if (_videoController!.value.buffered.isNotEmpty) {
      _bufferedPosition = _videoController!.value.buffered.last.end;
    } else {
      _bufferedPosition = Duration.zero;
    }
    
    // Auto advance when video ends
    if (_videoController!.value.isInitialized &&
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero &&
        !_videoController!.value.isPlaying) {
      _handleTrackCompleted();
    }
    notifyListeners();
  }

  // Play a track and set up playlist context
  Future<void> playTrack(DownloadItem track, {List<DownloadItem>? contextPlaylist}) async {
    _isLoading = true;
    await _stopControllers();
    _currentTrack = track;
    notifyListeners();

    // Record to watch history for local recommendation matching (Implicit Feedback)
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

      // Resolve file path first
      File file = File(track.localFilePath);
      if (!file.existsSync() && track.localFilePath.isNotEmpty) {
        final lastDot = track.localFilePath.lastIndexOf('.');
        if (lastDot != -1) {
          final pathWithoutExt = track.localFilePath.substring(0, lastDot);
          final altPath = track.localFilePath.endsWith('.m4a') ? '$pathWithoutExt.mp4' : '$pathWithoutExt.m4a';
          final altFile = File(altPath);
          if (altFile.existsSync()) {
            file = altFile;
          }
        }
      }

      final playsAsVideo = track.isVideo || (file.existsSync() && file.path.endsWith('.mp4'));

      if (playsAsVideo) {
        if (file.existsSync()) {
          _videoController = VideoPlayerController.file(file);
        } else {
          // Play online stream URL as video
          final manifest = await _youtubeService.getStreamManifest(track.id);
          final videoStream = manifest.muxed.withHighestBitrate();
          _videoController = VideoPlayerController.network(videoStream.url.toString());
        }

        await _videoController!.initialize();
        _videoController!.addListener(_onVideoControllerUpdate);
        await _videoController!.play();
        _isPlaying = true;
      } else {
        if (file.existsSync()) {
          // Play local offline file
          await _player.setAudioSource(AudioSource.file(file.path));
        } else {
          // Play online stream url
          final manifest = await _youtubeService.getStreamManifest(track.id);
          if (manifest.audioOnly.isEmpty) {
            throw Exception("No audio streams available.");
          }
          final sortedAudio = List<AudioOnlyStreamInfo>.from(manifest.audioOnly)
            ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
          final audioStream = sortedAudio.first;
          await _player.setAudioSource(AudioSource.uri(audioStream.url));
        }
        await _player.play();
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Play / Pause toggle
  Future<void> togglePlay() async {
    if (_currentTrack == null) return;
    
    if (_currentTrack!.isVideo) {
      if (_videoController != null) {
        if (_videoController!.value.isPlaying) {
          await _videoController!.pause();
          _isPlaying = false;
        } else {
          await _videoController!.play();
          _isPlaying = true;
        }
        notifyListeners();
      }
    } else {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    }
  }

  // Seek to position
  Future<void> seek(Duration position) async {
    if (_currentTrack == null) return;

    if (_currentTrack!.isVideo) {
      if (_videoController != null) {
        await _videoController!.seekTo(position);
      }
    } else {
      await _player.seek(position);
    }
  }

  // Stop playback
  Future<void> stop() async {
    await _stopControllers();
    _currentTrack = null;
    _playlist.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  // Next track
  Future<void> next() async {
    if (_playlist.isEmpty || _currentIndex == -1) return;
    
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) {
      if (_loopMode == LoopMode.all) {
        nextIndex = 0;
      } else {
        return; // No next track
      }
    }
    
    _currentIndex = nextIndex;
    await playTrack(_playlist[_currentIndex]);
  }

  // Previous track
  Future<void> previous() async {
    if (_playlist.isEmpty || _currentIndex == -1) return;

    // If we've played for more than 3 seconds, restart the song
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

  // Cycle loop modes
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

  // Toggle shuffle
  void toggleShuffle() {
    _shuffleModeEnabled = !_shuffleModeEnabled;
    _player.setShuffleModeEnabled(_shuffleModeEnabled);
    notifyListeners();
  }

  // Handle auto-advancing when track completes
  void _handleTrackCompleted() {
    if (_loopMode == LoopMode.one) {
      // Handled by player itself
    } else {
      next();
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
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
