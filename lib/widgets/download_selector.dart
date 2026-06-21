import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';
import '../services/language_service.dart';
import 'custom_toast.dart';

void showDownloadQualitySelector(BuildContext context, Video video, {bool isVideoOnly = true}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF161622),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StreamQualitySelector(video: video, isVideoOnly: isVideoOnly);
    },
  );
}

class StreamQualitySelector extends StatefulWidget {
  final Video video;
  final bool isVideoOnly;

  const StreamQualitySelector({
    super.key,
    required this.video,
    required this.isVideoOnly,
  });

  @override
  State<StreamQualitySelector> createState() => _StreamQualitySelectorState();
}

class _StreamQualitySelectorState extends State<StreamQualitySelector> {
  final YoutubeService _youtubeService = YoutubeService();
  bool _isLoading = true;
  String? _errorMessage;
  StreamManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _fetchManifest();
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }

  Future<void> _fetchManifest() async {
    try {
      final manifest = await _youtubeService.getStreamManifest(widget.video.id.value);
      if (mounted) {
        setState(() {
          _manifest = manifest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              widget.isVideoOnly ? context.tr('select_video_quality') : context.tr('select_audio_quality'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const Divider(color: Colors.white10),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    '${context.tr('error_get_quality')}: $_errorMessage',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            _buildOptionsList(downloadService),
        ],
      ),
    );
  }

  Widget _buildOptionsList(DownloadService downloadService) {
    final List<StreamInfo> streams = [];
    if (widget.isVideoOnly) {
      streams.addAll(_manifest?.muxed ?? []);
    } else {
      streams.addAll(_manifest?.audioOnly ?? []);
    }

    if (streams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(context.tr('no_quality_options'), style: const TextStyle(color: Colors.white54)),
        ),
      );
    }

    // Sort streams: Video by resolution (highest first), Audio by bitrate (highest first)
    if (widget.isVideoOnly) {
      streams.sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
    } else {
      streams.sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
    }

    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: streams.length,
        itemBuilder: (context, index) {
          final stream = streams[index];
          String title = '';
          String subtitle = '';
          IconData icon = Icons.download_rounded;
          Color iconColor = Colors.grey;

          if (stream is MuxedStreamInfo) {
            final quality = stream.videoQuality.qualityString;
            title = '${context.tr('video')} $quality';
            subtitle = '${context.tr('format')}: ${stream.container.name.toUpperCase()}';
            icon = Icons.video_library_rounded;
            iconColor = const Color(0xFF2A8FFF);
          } else if (stream is AudioOnlyStreamInfo) {
            final kbps = (stream.bitrate.bitsPerSecond / 1000).round();
            title = '${context.tr('audio')} $kbps kbps';
            subtitle = '${context.tr('format')}: ${stream.container.name.toUpperCase()}';
            icon = Icons.audiotrack_rounded;
            iconColor = const Color(0xFFFF2A5F);
          }

          final sizeStr = _formatBytes(stream.size.totalBytes);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            trailing: Text(
              sizeStr,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              downloadService.downloadVideo(
                widget.video,
                isVideoOnly: widget.isVideoOnly,
                selectedStream: stream,
              );
              CustomToast.show(
                context,
                '${context.tr('download_started')}: ${widget.video.title}',
                icon: Icons.downloading_rounded,
                color: const Color(0xFFFF2A5F),
              );
            },
          );
        },
      ),
    );
  }
}
