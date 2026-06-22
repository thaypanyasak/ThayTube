import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Initializes and returns a [ThayTubeAudioHandler] registered with the
/// system via [AudioService.init]. Must be called before [runApp].
Future<ThayTubeAudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => ThayTubeAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.thayz.thaytube.audio',
      androidNotificationChannelName: 'ThayTube Music',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      // iOS-specific: keeps audio running in background
      preloadArtwork: true,
    ),
  );
}

/// Wraps [AudioPlayer] in an [AudioHandler] so the OS knows this app is
/// playing audio in the background. This enables:
///   - iOS: lock-screen controls, Control Center playback widget
///   - Android: persistent notification with media controls
///   - Both: audio continues when screen locks or app is backgrounded
class ThayTubeAudioHandler extends BaseAudioHandler with SeekHandler {
  late final AudioPlayer player;
  late final AndroidEqualizer? equalizer;
  late final AndroidLoudnessEnhancer? loudnessEnhancer;

  ThayTubeAudioHandler() {
    if (Platform.isAndroid) {
      final eq = AndroidEqualizer();
      final le = AndroidLoudnessEnhancer();
      equalizer = eq;
      loudnessEnhancer = le;
      player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [eq, le],
        ),
      );
      _setupPremiumAudioEffects();
    } else {
      equalizer = null;
      loudnessEnhancer = null;
      player = AudioPlayer();
    }

    // Broadcast state changes (play/pause/position) to the OS
    player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        // Swallow stream errors — AudioService will log them
      },
    );

    // When just_audio completes a track, tell the OS we stopped
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ));
      }
    });
  }

  Future<void> _setupPremiumAudioEffects() async {
    try {
      if (equalizer != null) {
        await equalizer!.setEnabled(true);
        final parameters = await equalizer!.parameters;
        final bands = parameters.bands;
        
        if (bands.isNotEmpty) {
          final maxDb = parameters.maxDecibels;
          final minDb = parameters.minDecibels;
          
          // Boost bass bands (0 and 1) by 35% of max dB (~+5.25 dB boost)
          final bassBoost = maxDb * 0.35;
          // Cut lower-mid range band (2) slightly to maintain clear vocals (~-1.5 dB cut)
          final midCut = minDb * 0.1;
          
          if (bands.isNotEmpty) {
            await bands[0].setGain(bassBoost);
          }
          if (bands.length > 1) {
            await bands[1].setGain(bassBoost * 0.8);
          }
          if (bands.length > 2) {
            await bands[2].setGain(midCut);
          }
        }
      }
      
      if (loudnessEnhancer != null) {
        await loudnessEnhancer!.setEnabled(true);
        // Boost target gain by 0.3 (translates to 300 millibels / +3.0 dB boost)
        await loudnessEnhancer!.setTargetGain(0.3);
      }
    } catch (e) {
      // Fail silently
    }
  }

  // ── Playback controls (called by OS media buttons & lock screen) ──────────

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Delegate to AudioService — it calls next() on our ChangeNotifier
    // via the customEvent channel set up in AudioService._init()
    customEvent.add('next');
  }

  @override
  Future<void> skipToPrevious() async {
    customEvent.add('previous');
  }

  // ── Helper: update the OS about current playback state ───────────────────

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      // Which 3 buttons show in the Android compact notification
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  /// Push new track artwork + metadata to the lock screen / Control Center.
  void updateNowPlayingInfo({
    required String id,
    required String title,
    required String artist,
    required String artUri,
    required Duration duration,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      duration: duration,
      artUri: artUri.isNotEmpty ? Uri.parse(artUri) : null,
    ));
  }
}
