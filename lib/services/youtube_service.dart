import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserAgentClient extends http.BaseClient {
  static final UserAgentClient instance = UserAgentClient._internal();
  final http.Client _inner = http.Client();
  final Map<String, String> _cookies = {};

  UserAgentClient._internal() {
    _warmUpCookies();
  }

  Future<void> _warmUpCookies() async {
    try {
      final response = await _inner.get(Uri.parse('https://www.youtube.com/'), headers: {
        'User-Agent': _randomUserAgent(),
        'Accept-Language': 'en-US,en;q=0.9',
      });
      _updateCookies(response.headers);
    } catch (_) {}
  }

  String _randomUserAgent() {
    final versions = ['120.0.0.0', '121.0.0.0', '122.0.0.0', '123.0.0.0', '124.0.0.0', '125.0.0.0'];
    final index = DateTime.now().millisecond % versions.length;
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${versions[index]} Safari/537.36';
  }

  void _updateCookies(Map<String, String> headers) {
    final rawCookie = headers['set-cookie'];
    if (rawCookie != null) {
      final parts = rawCookie.split(',');
      for (final part in parts) {
        final cookie = part.split(';').first.trim();
        if (cookie.isNotEmpty) {
          final kv = cookie.split('=');
          if (kv.length >= 2) {
            _cookies[kv[0]] = kv[1];
          }
        }
      }
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['User-Agent'] = _randomUserAgent();
    request.headers['Accept-Language'] = 'en-US,en;q=0.9';
    request.headers['Referer'] = 'https://www.youtube.com/';
    
    if (_cookies.isNotEmpty) {
      final cookieString = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      request.headers['cookie'] = cookieString;
    } else {
      request.headers['cookie'] = 'CONSENT=YES+cb';
    }

    final response = await _inner.send(request);
    _updateCookies(response.headers);
    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class YoutubeService {
  static final YoutubeService _instance = YoutubeService._internal();
  factory YoutubeService() => _instance;
  
  late final YoutubeExplode _yt;
  final Map<String, StreamManifest> _manifestCache = {};
  final Map<String, Video> _videoCache = {};

  YoutubeService._internal() {
    _yt = YoutubeExplode(httpClient: YoutubeHttpClient(UserAgentClient.instance));
  }

  YoutubeExplode get client => _yt;

  // Fetch home/trending music videos by default
  Future<List<Video>> getRecommendedVideos() async {
    try {
      print("YoutubeService: Bắt đầu gọi getRecommendedVideos()...");
      final searchResult = await _yt.search
          .search("Thai Music Hits", filter: TypeFilters.video)
          .timeout(const Duration(seconds: 8));
      final list = searchResult.toList();
      print("YoutubeService: Tải đề xuất thành công, số lượng: ${list.length} videos.");
      return list;
    } catch (e) {
      print("YoutubeService: Lỗi getRecommendedVideos: $e");
      return [];
    }
  }

  // Fetch personalized videos using Google Account access token, local watch history, or fallback search
  Future<List<Video>> getPersonalizedVideos({String? displayName, String? accessToken}) async {
    final Map<String, Video> videoMap = {};

    // Step 1: Query local watch history keywords (Implicit Feedback & Watch History) in parallel
    try {
      final historyQueries = await getSearchQueriesFromHistory();
      if (historyQueries.isNotEmpty) {
        print("YoutubeService: Phát hiện lịch sử xem, gợi ý từ khóa: $historyQueries");
        final historyFutures = historyQueries.take(3).map((query) async {
          try {
            final searchResult = await _yt.search
                .search(query, filter: TypeFilters.video)
                .timeout(const Duration(seconds: 4));
            return searchResult.toList();
          } catch (_) {
            return <Video>[];
          }
        });
        final results = await Future.wait(historyFutures);
        for (final list in results) {
          for (final video in list.take(4)) {
            videoMap[video.id.value] = video;
          }
        }
      }
    } catch (e) {
      print('YoutubeService: Lỗi phân tích gợi ý từ lịch sử: $e');
    }

    // Step 2: Get subscribed channels of the logged in user (if logged in with Google)
    if (accessToken != null) {
      try {
        print("YoutubeService: Bắt đầu lấy danh sách kênh đăng ký (Subscriptions)...");
        final subResponse = await http.get(
          Uri.parse('https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true&maxResults=10'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (subResponse.statusCode == 200) {
          final subData = json.decode(subResponse.body);
          final items = subData['items'] ?? [];
          if (items.isNotEmpty) {
            final List<String> channelIds = [];
            for (var item in items) {
              final channelId = item['snippet']?['resourceId']?['channelId'];
              if (channelId is String) {
                channelIds.add(channelId);
              }
            }

            // Fetch latest 4 videos from the first 3 subscribed channels in parallel
            final channelFutures = channelIds.take(3).map((channelId) async {
              try {
                final searchResponse = await http.get(
                  Uri.parse('https://www.googleapis.com/youtube/v3/search?part=id&channelId=$channelId&order=date&type=video&maxResults=4'),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Accept': 'application/json',
                  },
                ).timeout(const Duration(seconds: 4));

                if (searchResponse.statusCode == 200) {
                  final searchData = json.decode(searchResponse.body);
                  final List<String> ids = [];
                  for (var item in searchData['items'] ?? []) {
                    final videoId = item['id']?['videoId'];
                    if (videoId is String) {
                      ids.add(videoId);
                    }
                  }
                  return ids;
                }
              } catch (_) {}
              return <String>[];
            });

            final channelVideoIdLists = await Future.wait(channelFutures);
            final List<String> googleVideoIds = [];
            for (final list in channelVideoIdLists) {
              googleVideoIds.addAll(list);
            }

            // Fetch video details in parallel for these Google video IDs
            final List<String> idsToFetch = googleVideoIds.where((id) => !videoMap.containsKey(id)).toList();
            if (idsToFetch.isNotEmpty) {
              final List<Future<void>> fetchFutures = idsToFetch.take(12).map((id) async {
                try {
                  final video = await _yt.videos.get(VideoId(id)).timeout(const Duration(seconds: 4));
                  videoMap[id] = video;
                } catch (_) {}
              }).toList();
              await Future.wait(fetchFutures);
            }
          }
        }
      } catch (e) {
        print('YoutubeService: Lỗi lấy danh sách Subscriptions: $e');
      }
    }

    // Step 3: Fallback search if we have no personalized videos yet (or fewer than 5)
    if (videoMap.length < 5) {
      try {
        print("YoutubeService: Không đủ video gợi ý cá nhân, lấy thêm danh sách nhạc thịnh hành qua YoutubeExplode...");
        final searchResult = await _yt.search
            .search("Thai Music Hits", filter: TypeFilters.video)
            .timeout(const Duration(seconds: 5));
        for (final video in searchResult.toList()) {
          videoMap[video.id.value] = video;
        }
      } catch (e) {
        print('YoutubeService: Lỗi lấy danh sách nhạc thịnh hành: $e');
      }
    }

    // Ultimate Fallback
    if (videoMap.isEmpty) {
      return await searchVideos("Thai Music Hits");
    }

    return videoMap.values.take(30).toList();
  }

  // Save video play event to SharedPreferences for local recommendation matching
  static Future<void> recordWatchHistory(String videoId, String title, String author) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('watch_history_records') ?? [];
      
      final record = json.encode({
        'id': videoId,
        'title': title,
        'author': author,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      historyJson.removeWhere((item) {
        try {
          final decoded = json.decode(item);
          return decoded['id'] == videoId;
        } catch (_) {
          return false;
        }
      });
      
      historyJson.insert(0, record);
      
      if (historyJson.length > 30) {
        historyJson.removeRange(30, historyJson.length);
      }
      
      await prefs.setStringList('watch_history_records', historyJson);
    } catch (e) {
      print('YoutubeService: Lỗi lưu lịch sử xem: $e');
    }
  }

  // Save search query event for local recommendation matching
  static Future<void> recordSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('watch_history_records') ?? [];
      
      final record = json.encode({
        'id': 'search_${DateTime.now().millisecondsSinceEpoch}',
        'title': query,
        'author': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      historyJson.insert(0, record);
      
      if (historyJson.length > 30) {
        historyJson.removeRange(30, historyJson.length);
      }
      await prefs.setStringList('watch_history_records', historyJson);
    } catch (_) {}
  }

  // Extract recommended search queries from watch history
  static Future<List<String>> getSearchQueriesFromHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('watch_history_records') ?? [];
      if (historyJson.isEmpty) return [];

      final Map<String, int> authorScores = {};
      final Map<String, int> keywordScores = {};

      final stopWords = {
        'mv', 'official', 'music', 'video', 'audio', 'lyrics', 'karaoke',
        'live', 'session', 'cover', 'full', 'hd', 'ft', 'feat', 'việt',
        'nam', 'nhạc', 'trẻ', 'bài', 'hát', 'ca', 'sĩ', 'chính', 'thức',
        'hay', 'nhất', 'playlist', 'album', 'remix', 'tik', 'tok', 'hot',
        '1080p', 'prod', 'by', 'with', 'and', 'the', 'of', 'in', 'on', 'at'
      };

      for (int i = 0; i < historyJson.length; i++) {
        try {
          final data = json.decode(historyJson[i]);
          final author = data['author'] as String;
          final title = data['title'] as String;
          final weight = 30 - i;

          if (author.isNotEmpty) {
            authorScores[author] = (authorScores[author] ?? 0) + (weight * 2);
          }

          final cleanedTitle = title.toLowerCase()
              .replaceAll(RegExp(r'[^\w\s\d]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ');
          final words = cleanedTitle.split(' ');
          for (final word in words) {
            if (word.length > 2 && !stopWords.contains(word) && !RegExp(r'^\d+$').hasMatch(word)) {
              keywordScores[word] = (keywordScores[word] ?? 0) + weight;
            }
          }
        } catch (_) {}
      }

      final sortedAuthors = authorScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedKeywords = keywordScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<String> queries = [];
      
      for (final entry in sortedAuthors.take(2)) {
        queries.add(entry.key);
      }

      if (sortedAuthors.isNotEmpty && sortedKeywords.isNotEmpty) {
        queries.add('${sortedAuthors.first.key} ${sortedKeywords.first.key}');
      }

      for (final entry in sortedKeywords.take(2)) {
        queries.add(entry.key);
      }

      final Set<String> uniqueQueries = {};
      for (final q in queries) {
        if (q.trim().isNotEmpty) {
          uniqueQueries.add(q.trim());
        }
      }
      return uniqueQueries.toList();
    } catch (_) {
      return [];
    }
  }

  // Search videos based on user query
  Future<List<Video>> searchVideos(String query) async {
    try {
      print("YoutubeService: Bắt đầu tìm kiếm với từ khóa: '$query'...");
      final searchResult = await _yt.search
          .search(query, filter: TypeFilters.video)
          .timeout(const Duration(seconds: 10));
      final list = searchResult.toList();
      print("YoutubeService: Tìm kiếm thành công, tìm thấy: ${list.length} videos.");
      return list;
    } catch (e) {
      print("YoutubeService: Lỗi searchVideos cho từ khóa '$query': $e");
      return [];
    }
  }

  // Get stream manifest for a video
  Future<StreamManifest> getStreamManifest(String videoId) async {
    if (_manifestCache.containsKey(videoId)) {
      return _manifestCache[videoId]!;
    }
    final manifest = await _yt.videos.streamsClient.getManifest(VideoId(videoId));
    _manifestCache[videoId] = manifest;
    return manifest;
  }

  // Get single video details
  Future<Video> getVideoDetails(String videoId) async {
    if (_videoCache.containsKey(videoId)) {
      return _videoCache[videoId]!;
    }
    final video = await _yt.videos.get(VideoId(videoId));
    _videoCache[videoId] = video;
    return video;
  }

  // Get related videos based on existing video list for infinite scroll
  Future<List<Video>> getRelatedVideos(List<Video> existingVideos) async {
    final List<String> existingVideoIds = existingVideos.map((v) => v.id.value).toList();
    final List<Video> relatedVideos = [];
    
    // Take the top 3 videos and fetch related videos in parallel
    final futures = existingVideos.take(3).map((video) async {
      try {
        final relatedList = await _yt.videos.getRelatedVideos(video).timeout(const Duration(seconds: 4));
        return relatedList ?? <Video>[];
      } catch (_) {
        return <Video>[];
      }
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      for (final v in list) {
        final idStr = v.id.value;
        if (!existingVideoIds.contains(idStr) && !relatedVideos.any((x) => x.id.value == idStr)) {
          relatedVideos.add(v);
        }
      }
    }

    if (relatedVideos.isEmpty) {
      // Fallback search
      try {
        final searchResult = await _yt.search
            .search("Thai Music Hits", filter: TypeFilters.video)
            .timeout(const Duration(seconds: 5));
        for (final video in searchResult.toList()) {
          final idStr = video.id.value;
          if (!existingVideoIds.contains(idStr) && !relatedVideos.any((x) => x.id.value == idStr)) {
            relatedVideos.add(video);
          }
        }
      } catch (_) {}
    }

    return relatedVideos.take(15).toList();
  }

  void dispose() {
    // Keep client open as a singleton
  }
}
