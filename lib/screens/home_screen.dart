import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../services/youtube_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../models/download_item.dart';
import '../widgets/download_selector.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;
  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YoutubeService _youtubeService = YoutubeService();
  late final WebViewController _webController;
  
  bool _isOffline = false;
  double _webProgress = 0.0;
  bool _isWebInitialized = false;
  bool _canGoBack = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _initWebController();
    _checkConnectivityAndInit();
    
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final offline = results.contains(ConnectivityResult.none);
      if (offline != _isOffline) {
        setState(() {
          _isOffline = offline;
        });
        if (!_isOffline && _isWebInitialized) {
          _webController.reload();
        }
      }
    });
  }

  Future<void> _checkConnectivityAndInit() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none) || results.isEmpty;
    setState(() {
      _isOffline = offline;
    });
  }

  void _initWebController() {
    late final PlatformWebViewControllerCreationParams params;

    if (Platform.isIOS && WebViewPlatform.instance is WebKitWebViewPlatform) {
      // KEY FIX: allowsInlineMediaPlayback=true prevents iOS from forcing
      // videos into native fullscreen automatically when the page loads.
      // mediaTypesRequiringUserAction={} means user must explicitly tap to play.
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setUserAgent(Platform.isIOS
          ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
          : 'Mozilla/5.0 (Linux; Android 15; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F1A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _webProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _webProgress = 0.0;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final canGo = await _webController.canGoBack();
              setState(() {
                _webProgress = 1.0;
                _currentUrl = url;
                _canGoBack = canGo;
              });
              // [ignoring loop detection]
              // Inject JS: add playsinline to all video elements and inject dark theme CSS variables
              await _webController.runJavaScript('''
                (function() {
                  try {
                    var htmlEl = document.documentElement;
                    if (htmlEl) {
                      htmlEl.setAttribute('dark', 'true');
                      htmlEl.setAttribute('theme', 'DARK');
                    }
                    var target = document.head || document.documentElement || document.body;
                    if (target) {
                      var style = document.getElementById('yt-dark-mode-style');
                      if (!style) {
                        style = document.createElement('style');
                        style.id = 'yt-dark-mode-style';
                        style.type = 'text/css';
                        style.innerHTML = 'html, body, ytm-topbar, .ytm-topbar, ytm-pivot-bar, .pivot-bar, .topbar, ytm-single-column-watch-next-results-renderer, ytm-item-section-renderer, ytm-media-item, .media-item, .item, .card { background-color: #0f0f0f !important; color: #ffffff !important; } :root { --yt-spec-brand-background-solid: #0f0f0f !important; --yt-spec-general-background-a: #0f0f0f !important; --yt-spec-general-background-b: #1f1f1f !important; --yt-spec-general-background-c: #2f2f2f !important; --yt-spec-text-primary: #ffffff !important; --yt-spec-text-secondary: #aaaaaa !important; --yt-spec-icon-active-other: #ffffff !important; --yt-spec-icon-inactive: #aaaaaa !important; --yt-spec-brand-background-primary: #0f0f0f !important; --yt-spec-brand-background-secondary: #0f0f0f !important; } input, ytm-searchbox, .searchbox, .search-box-container { background-color: #1f1f1f !important; color: #ffffff !important; } ytm-companion-ad-renderer, ytm-promoted-item-renderer, ytm-promoted-sparkles-web-renderer, ytm-install-app-promo, ytm-install-app-promo-renderer, ytm-mealbar-promo-renderer, .m-upsell-developer-promo, yt-install-app-promo-renderer, ytm-smart-app-banner, .ytm-app-promo, [aria-label="Install YouTube app"], ytm-unlimited-offer-page-renderer, .ad-container, .ad-image, .header-ad { display: none !important; }';
                        target.appendChild(style);
                      }
                    }
                    document.querySelectorAll('video').forEach(function(v) {
                      v.setAttribute('playsinline', '');
                      v.setAttribute('webkit-playsinline', '');
                      v.removeAttribute('autoplay');
                    });
                    var observer = new MutationObserver(function(mutations) {
                      mutations.forEach(function(m) {
                        m.addedNodes.forEach(function(node) {
                          if (node.tagName === 'VIDEO') {
                            node.setAttribute('playsinline', '');
                            node.setAttribute('webkit-playsinline', '');
                            node.removeAttribute('autoplay');
                          }
                          if (node.querySelectorAll) {
                            node.querySelectorAll('video').forEach(function(v) {
                              v.setAttribute('playsinline', '');
                              v.setAttribute('webkit-playsinline', '');
                              v.removeAttribute('autoplay');
                            });
                          }
                        });
                      });
                    });
                    observer.observe(document.body, { childList: true, subtree: true });
                  } catch (e) {}
                })();
              ''');
            }
          },
          onUrlChange: (UrlChange change) async {
            final url = change.url;
            if (url != null && mounted) {
              final canGo = await _webController.canGoBack();
              setState(() {
                _currentUrl = url;
                _canGoBack = canGo;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _webController = controller;
    _isWebInitialized = true;
    _loadModernYoutube();
  }

  Future<void> _loadModernYoutube() async {
    try {
      final cookieManager = WebViewCookieManager();
      // Clear cookies once to force clean slate without old layout settings
      await cookieManager.clearCookies();
    } catch (e) {
      debugPrint('Error clearing cookies: $e');
    }
    await _webController.loadRequest(Uri.parse('https://m.youtube.com'));
  }

  bool _showDownloadButton() {
    if (_currentUrl == null) return false;
    final uri = Uri.parse(_currentUrl!);
    return _currentUrl!.contains('watch?v=') || 
           (uri.host.contains('youtube.com') && uri.queryParameters.containsKey('v')) ||
           _currentUrl!.contains('youtu.be/');
  }

  String? _getVideoIdFromCurrentUrl() {
    if (_currentUrl == null) return null;
    final uri = Uri.parse(_currentUrl!);
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    final match = RegExp(r'[?&]v=([^&#]+)').firstMatch(_currentUrl!);
    if (match != null) {
      return match.group(1);
    }
    if (_currentUrl!.contains('youtu.be/')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.first;
      }
    }
    return null;
  }

  Future<void> _handleYoutubeVideoIntercept(BuildContext context, String videoId) async {
    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('fetching_video_details'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final results = await Future.wait([
        _youtubeService.getVideoDetails(videoId),
        _youtubeService.getStreamManifest(videoId),
      ]);
      final video = results[0] as yt.Video;

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        _showOptionsBottomSheet(context, video);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $e')),
        );
      }
    }
  }

  void _showOptionsBottomSheet(BuildContext context, yt.Video video) {
    final audioService = Provider.of<AudioService>(context, listen: false);
    final videoId = video.id.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video Details Header in Bottom Sheet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          video.thumbnails.mediumResUrl,
                          width: 80,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              video.author,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),

                // Option 1: Stream Audio Online
                ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
                  title: Text(context.tr('audio_stream_online'), style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    final tempDownloadItem = DownloadItem(
                      id: videoId,
                      title: video.title,
                      author: video.author,
                      durationMs: video.duration?.inMilliseconds ?? 0,
                      thumbnailUrl: video.thumbnails.mediumResUrl,
                      localFilePath: '', // Empty means online stream
                      localThumbnailPath: '',
                      fileSize: 0,
                      downloadedAt: DateTime.now(),
                      isVideo: false,
                    );
                    audioService.playTrack(tempDownloadItem);
                  },
                ),

                // Option 2: Download Video Offline
                ListTile(
                  leading: const Icon(Icons.video_library_outlined, color: Colors.blueAccent),
                  title: Text(context.tr('download_video_offline'), style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    showDownloadQualitySelector(context, video, isVideoOnly: true);
                  },
                ),

                // Option 4: Close
                ListTile(
                  leading: const Icon(Icons.close_rounded, color: Colors.white38),
                  title: Text(context.tr('cancel'), style: const TextStyle(color: Colors.white38)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('no_internet'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('offline_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigateToTab(1), // Go to downloads tab
                  icon: const Icon(Icons.download_rounded),
                  label: Text(context.tr('offline_lib_btn')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isWebInitialized && await _webController.canGoBack()) {
          await _webController.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: SafeArea(
          child: Stack(
            children: [
              // WebView component
              WebViewWidget(controller: _webController),
              
              // Custom top loading progress bar
              if (_webProgress > 0.0 && _webProgress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: LinearProgressIndicator(
                    value: _webProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A5F)),
                  ),
                ),

              // Floating Back Button (visible only when WebView can go back)
              if (_canGoBack)
                Positioned(
                  top: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.6),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          if (await _webController.canGoBack()) {
                            await _webController.goBack();
                          }
                        },
                      ),
                    ),
                  ),
                ),

              // Floating Download Button (visible only when watching a video)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                bottom: _showDownloadButton() ? 24 : -80,
                right: 24,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A5F), Color(0xFFFF5E62)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A5F).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: RawMaterialButton(
                    shape: const CircleBorder(),
                    onPressed: () {
                      final videoId = _getVideoIdFromCurrentUrl();
                      if (videoId != null) {
                        _handleYoutubeVideoIntercept(context, videoId);
                      }
                    },
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
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
