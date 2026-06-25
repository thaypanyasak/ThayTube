import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';
import './youtube_service.dart';

class DownloadService extends ChangeNotifier {
  final YoutubeService _youtubeService = YoutubeService();
  final List<DownloadItem> _downloadedItems = [];
  final List<DownloadItem> _downloadingItems = [];
  final List<String> _unwatchedIds = [];
  final List<Map<String, dynamic>> _downloadQueue = [];
  bool _isProcessingQueue = false;
  final Map<String, double> _downloadProgress = {}; // videoId -> progress (0.0 to 1.0)
  final Map<String, String> _downloadStatus = {}; // videoId -> status message (e.g. 'Downloading...', 'Converting...')

  List<DownloadItem> get downloadedItems => _downloadedItems;
  List<DownloadItem> get downloadingItems => _downloadingItems;
  List<String> get unwatchedIds => _unwatchedIds;
  Map<String, double> get downloadProgress => _downloadProgress;
  Map<String, String> get downloadStatus => _downloadStatus;

  DownloadService() {
    _loadDownloadedItems();
  }

  // Load downloads from local storage
  Future<void> _loadDownloadedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? unwatchedJson = prefs.getString('unwatched_download_ids');
      if (unwatchedJson != null) {
        final List<dynamic> decodedList = json.decode(unwatchedJson);
        _unwatchedIds.clear();
        _unwatchedIds.addAll(decodedList.cast<String>());
      }

      final String? jsonString = prefs.getString('downloaded_items');
      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        _downloadedItems.clear();
        
        final appDir = await getApplicationDocumentsDirectory();
        final mediaDirPath = '${appDir.path}/media';
        final thumbnailDirPath = '${appDir.path}/thumbnails';
        
        bool migrated = false;
        
        for (var itemMap in decoded) {
          var item = DownloadItem.fromMap(itemMap);
          
          // Reconstruct paths to adapt to iOS/Android dynamic sandbox UUID prefixes on update/reinstall
          if (item.localFilePath.isNotEmpty) {
            final mediaFileName = item.localFilePath.replaceAll('\\', '/').split('/').last;
            final thumbnailFileName = item.localThumbnailPath.replaceAll('\\', '/').split('/').last;
            
            final reconstructedFilePath = '$mediaDirPath/$mediaFileName';
            final reconstructedThumbnailPath = '$thumbnailDirPath/$thumbnailFileName';
            
            item = DownloadItem(
              id: item.id,
              title: item.title,
              author: item.author,
              durationMs: item.durationMs,
              thumbnailUrl: item.thumbnailUrl,
              localFilePath: reconstructedFilePath,
              localThumbnailPath: reconstructedThumbnailPath,
              fileSize: item.fileSize,
              downloadedAt: item.downloadedAt,
              isVideo: item.isVideo,
            );
          }
          
          // Verify file exists, otherwise try alternative extension (.m4a <-> .mp4)
          File file = File(item.localFilePath);
          if (!file.existsSync() && item.localFilePath.isNotEmpty) {
            final lastDot = item.localFilePath.lastIndexOf('.');
            if (lastDot != -1) {
              final pathWithoutExt = item.localFilePath.substring(0, lastDot);
              final altPath = item.localFilePath.endsWith('.m4a') ? '$pathWithoutExt.mp4' : '$pathWithoutExt.m4a';
              final altFile = File(altPath);
              if (altFile.existsSync()) {
                item = DownloadItem(
                  id: item.id,
                  title: item.title,
                  author: item.author,
                  durationMs: item.durationMs,
                  thumbnailUrl: item.thumbnailUrl,
                  localFilePath: altPath,
                  localThumbnailPath: item.localThumbnailPath,
                  fileSize: item.fileSize,
                  downloadedAt: item.downloadedAt,
                  isVideo: item.isVideo,
                );
                migrated = true;
                file = altFile;
              }
            }
          }
          
          if (file.existsSync()) {
            _downloadedItems.add(item);
          }
        }
        
        if (migrated) {
          final String updatedJsonString = json.encode(_downloadedItems.map((e) => e.toMap()).toList());
          await prefs.setString('downloaded_items', updatedJsonString);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  // Save downloads database to SharedPreferences
  Future<void> _saveDownloadedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_downloadedItems.map((e) => e.toMap()).toList());
      await prefs.setString('downloaded_items', jsonString);
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  Future<void> _saveUnwatchedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unwatched_download_ids', json.encode(_unwatchedIds));
    } catch (e) {
      debugPrint('Error saving unwatched ids: $e');
    }
  }

  Future<void> markAsWatched(String videoId) async {
    if (_unwatchedIds.contains(videoId)) {
      _unwatchedIds.remove(videoId);
      await _saveUnwatchedIds();
      notifyListeners();
    }
  }

  bool isDownloaded(String videoId) {
    return _downloadedItems.any((item) => item.id == videoId);
  }

  DownloadItem? getDownloadItem(String videoId) {
    try {
      return _downloadedItems.firstWhere((item) => item.id == videoId);
    } catch (_) {
      return null;
    }
  }

  double? getProgress(String videoId) {
    return _downloadProgress[videoId];
  }

  String? getStatus(String videoId) {
    return _downloadStatus[videoId];
  }

  // Start downloading a video/audio (Appends to queue)
  Future<void> downloadVideo(Video video, {required bool isVideoOnly, StreamInfo? selectedStream}) async {
    final videoId = video.id.value;
    if (isDownloaded(videoId)) return;

    // Check if already in queue or downloading
    if (_downloadingItems.any((item) => item.id == videoId)) return;

    // Add placeholder to downloading items
    final placeholder = DownloadItem(
      id: videoId,
      title: video.title,
      author: video.author,
      durationMs: video.duration?.inMilliseconds ?? 0,
      thumbnailUrl: video.thumbnails.mediumResUrl,
      localFilePath: '', // Empty indicates active/queued download
      localThumbnailPath: '',
      fileSize: 0,
      downloadedAt: DateTime.now(),
      isVideo: isVideoOnly,
    );

    _downloadingItems.add(placeholder);
    _downloadProgress[videoId] = 0.0;
    _downloadStatus[videoId] = 'waiting_queue'; // Translation key for 'Waiting in queue...'
    notifyListeners();

    // Add to task queue
    _downloadQueue.add({
      'video': video,
      'isVideoOnly': isVideoOnly,
      'selectedStream': selectedStream,
    });

    // Process the queue asynchronously
    _processQueue();
  }

  // Sequentially processes the download queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_downloadQueue.isNotEmpty) {
      final task = _downloadQueue.first;
      final video = task['video'] as Video;
      final isVideoOnly = task['isVideoOnly'] as bool;
      final selectedStream = task['selectedStream'] as StreamInfo?;

      try {
        await _executeDownload(video, isVideoOnly: isVideoOnly, selectedStream: selectedStream);
      } catch (e) {
        debugPrint('DownloadService: Queue item failed: $e');
      }

      // Remove the finished task and notify
      if (_downloadQueue.isNotEmpty) {
        _downloadQueue.removeAt(0);
      }
      notifyListeners();
    }

    _isProcessingQueue = false;
  }

  // The actual download worker method
  Future<void> _executeDownload(Video video, {required bool isVideoOnly, StreamInfo? selectedStream}) async {
    final videoId = video.id.value;
    
    // Double check that it wasn't cancelled/deleted while in queue
    if (!_downloadingItems.any((item) => item.id == videoId)) return;

    _downloadProgress[videoId] = 0.0;
    _downloadStatus[videoId] = 'preparing'; // Translation key
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      
      // Create directories
      final mediaDir = Directory('${appDir.path}/media');
      final thumbnailDir = Directory('${appDir.path}/thumbnails');
      if (!mediaDir.existsSync()) mediaDir.createSync(recursive: true);
      if (!thumbnailDir.existsSync()) thumbnailDir.createSync(recursive: true);

      // 1. Get YouTube stream info
      _downloadStatus[videoId] = 'fetching_streams'; // Translation key
      notifyListeners();
      
      final manifest = await _youtubeService.getStreamManifest(videoId);
      
      StreamInfo streamInfo;
      String fileExt;
      
      if (selectedStream != null) {
        streamInfo = selectedStream;
        fileExt = selectedStream is MuxedStreamInfo ? '.mp4' : '.m4a';
      } else {
        if (isVideoOnly) {
          // Find best quality muxed stream (video + audio)
          if (manifest.muxed.isEmpty) {
            throw Exception("No video streams available.");
          }
          final sortedMuxed = List<MuxedStreamInfo>.from(manifest.muxed)
            ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
          streamInfo = sortedMuxed.first;
          fileExt = '.mp4';
        } else {
          // Find highest quality audio stream, prioritizing M4A (AAC) for native iOS decoding
          if (manifest.audioOnly.isEmpty) {
            throw Exception("No audio streams available.");
          }
          final aacStreams = manifest.audioOnly
              .where((s) => s.container.name == 'm4a' || s.container.name == 'mp4')
              .toList();
          final sortedAudio = aacStreams.isNotEmpty ? aacStreams : manifest.audioOnly.toList();
          sortedAudio.sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
          streamInfo = sortedAudio.first;
          fileExt = streamInfo.container.name == 'm4a' ? '.m4a' : '.webm';
        }
      }

      // 2. Download media stream
      String localFilePath = '${mediaDir.path}/$videoId$fileExt';
      _downloadStatus[videoId] = 'downloading_media'; // Translation key
      notifyListeners();

      try {
        await _downloadStream(streamInfo, localFilePath, videoId);
      } catch (e) {
        debugPrint('DownloadService: First download attempt failed for $videoId: $e');
        if (!isVideoOnly && fileExt == '.m4a') {
          debugPrint('DownloadService: Audio stream 403 or failed. Retrying with fallback muxed stream...');
          if (manifest.muxed.isNotEmpty) {
            final sortedMuxed = List<MuxedStreamInfo>.from(manifest.muxed)
              ..sort((a, b) => a.size.totalBytes.compareTo(b.size.totalBytes));
            streamInfo = sortedMuxed.first;
            fileExt = '.mp4';
            localFilePath = '${mediaDir.path}/$videoId$fileExt';
            
            _downloadStatus[videoId] = 'retrying_fallback'; // Translation key
            notifyListeners();
            
            await _downloadStream(streamInfo, localFilePath, videoId);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // 3. Download thumbnail locally for offline visualization
      _downloadStatus[videoId] = 'saving_artwork'; // Translation key
      notifyListeners();
      
      final localThumbnailPath = '${thumbnailDir.path}/$videoId.jpg';
      try {
        final imageUrl = video.thumbnails.maxResUrl.isNotEmpty
            ? video.thumbnails.maxResUrl
            : (video.thumbnails.highResUrl.isNotEmpty
                ? video.thumbnails.highResUrl
                : video.thumbnails.mediumResUrl);
        final response = await http.get(Uri.parse(imageUrl));
        final thumbnailFile = File(localThumbnailPath);
        await thumbnailFile.writeAsBytes(response.bodyBytes);
      } catch (e) {
        debugPrint('Failed to download thumbnail: $e');
      }

      // 4. Register download item
      final downloadItem = DownloadItem(
        id: videoId,
        title: video.title,
        author: video.author,
        durationMs: video.duration?.inMilliseconds ?? 0,
        thumbnailUrl: video.thumbnails.mediumResUrl,
        localFilePath: localFilePath,
        localThumbnailPath: localThumbnailPath,
        fileSize: streamInfo.size.totalBytes,
        downloadedAt: DateTime.now(),
        isVideo: isVideoOnly,
      );

      _downloadingItems.removeWhere((item) => item.id == videoId);
      _downloadedItems.add(downloadItem);
      _unwatchedIds.add(videoId);
      await _saveDownloadedItems();
      await _saveUnwatchedIds();

      // Clean up progress variables
      _downloadProgress.remove(videoId);
      _downloadStatus.remove(videoId);
      notifyListeners();

    } catch (e) {
      debugPrint('Download error for $videoId: $e');
      _downloadingItems.removeWhere((item) => item.id == videoId);
      _downloadStatus[videoId] = 'Failed: $e';
      _downloadProgress.remove(videoId);
      notifyListeners();
      
      // Clean up failed files
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localThumbnailPath = '${appDir.path}/thumbnails/$videoId.jpg';
        
        final mFileM4a = File('${appDir.path}/media/$videoId.m4a');
        if (mFileM4a.existsSync()) mFileM4a.deleteSync();
        
        final mFileMp4 = File('${appDir.path}/media/$videoId.mp4');
        if (mFileMp4.existsSync()) mFileMp4.deleteSync();
        
        final tFile = File(localThumbnailPath);
        if (tFile.existsSync()) tFile.deleteSync();
      } catch (_) {}
    }
  }

  // Remove a download
  Future<void> deleteDownload(String videoId) async {
    try {
      final index = _downloadedItems.indexWhere((item) => item.id == videoId);
      if (index != -1) {
        final item = _downloadedItems[index];
        
        // Delete media file
        final mediaFile = File(item.localFilePath);
        if (mediaFile.existsSync()) {
          mediaFile.deleteSync();
        }

        // Delete thumbnail file
        final thumbFile = File(item.localThumbnailPath);
        if (thumbFile.existsSync()) {
          thumbFile.deleteSync();
        }

        _downloadedItems.removeAt(index);
        _unwatchedIds.remove(videoId);
        await _saveDownloadedItems();
        await _saveUnwatchedIds();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  Future<void> _downloadStream(StreamInfo streamInfo, String filePath, String videoId) async {
    final client = UserAgentClient.instance;
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    final totalSize = streamInfo.size.totalBytes;
    int downloadedBytes = 0;
    int retryCount = 0;
    const maxRetries = 5;

    while (downloadedBytes < totalSize && retryCount < maxRetries) {
      IOSink? fileStream;
      try {
        final request = http.Request('GET', streamInfo.url);
        // Request remaining bytes from the server
        request.headers['Range'] = 'bytes=$downloadedBytes-${totalSize - 1}';

        final response = await client.send(request).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          downloadedBytes = 0;
          fileStream = file.openWrite(mode: FileMode.write);
        } else {
          fileStream = file.openWrite(
            mode: downloadedBytes > 0 ? FileMode.writeOnlyAppend : FileMode.write,
          );
        }

        double lastNotifiedProgress = -1.0;
        DateTime lastNotifiedTime = DateTime.now();

        await for (final chunk in response.stream) {
          downloadedBytes += chunk.length;
          fileStream.add(chunk);
          
          final currentProgress = downloadedBytes / totalSize;
          final now = DateTime.now();

          if (currentProgress - lastNotifiedProgress >= 0.01 || 
              now.difference(lastNotifiedTime).inMilliseconds >= 300 || 
              currentProgress >= 1.0) {
            _downloadProgress[videoId] = currentProgress;
            _downloadStatus[videoId] = 'Downloading (${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB / ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB)';
            notifyListeners();
            lastNotifiedProgress = currentProgress;
            lastNotifiedTime = now;
          }
        }
        
        await fileStream.flush();
        await fileStream.close();
        fileStream = null;
        
        if (downloadedBytes >= totalSize) {
          break;
        }
      } catch (e) {
        retryCount++;
        debugPrint('DownloadService: Connection error for $videoId (Retry $retryCount/$maxRetries): $e');
        
        if (fileStream != null) {
          try {
            await fileStream.flush();
            await fileStream.close();
          } catch (_) {}
        }

        if (retryCount >= maxRetries) {
          rethrow;
        }
        // Wait exponentially longer before retrying
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }

    if (downloadedBytes == 0 || !file.existsSync() || file.lengthSync() == 0) {
      throw Exception("Downloaded file is empty or incomplete.");
    }
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}
