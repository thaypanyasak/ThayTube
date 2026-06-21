import 'dart:convert';

class DownloadItem {
  final String id;
  final String title;
  final String author;
  final int durationMs;
  final String thumbnailUrl;
  final String localFilePath;
  final String localThumbnailPath;
  final int fileSize;
  final DateTime downloadedAt;
  final bool isVideo;

  DownloadItem({
    required this.id,
    required this.title,
    required this.author,
    required this.durationMs,
    required this.thumbnailUrl,
    required this.localFilePath,
    required this.localThumbnailPath,
    required this.fileSize,
    required this.downloadedAt,
    required this.isVideo,
  });

  String get durationString {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeString {
    if (fileSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'durationMs': durationMs,
      'thumbnailUrl': thumbnailUrl,
      'localFilePath': localFilePath,
      'localThumbnailPath': localThumbnailPath,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
      'isVideo': isVideo,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      durationMs: map['durationMs'] ?? 0,
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      localFilePath: map['localFilePath'] ?? '',
      localThumbnailPath: map['localThumbnailPath'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      downloadedAt: DateTime.parse(map['downloadedAt'] ?? DateTime.now().toIso8601String()),
      isVideo: map['isVideo'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory DownloadItem.fromJson(String source) => DownloadItem.fromMap(json.decode(source));
}
