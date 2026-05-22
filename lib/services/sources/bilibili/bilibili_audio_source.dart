import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

class BilibiliAudioSource extends TonicAudioSource {
  final Dio _client;

  BilibiliAudioSource({Dio? client})
      : _client = (client ?? Dio()) {
    _client.options.headers.addAll(const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Referer': 'https://www.bilibili.com/',
    });
  }

  // ── 2.B.1 heuristic filter constants ──────────────────────────────

  static const _minDurationSec = 60; // 1 min – clips are shorter
  static const _maxDurationSec = 900; // 15 min – podcasts / compilations longer

  /// Non-music patterns – these strongly suggest the video is NOT a song.
  static final _blacklistPatterns = <RegExp>[
    RegExp(r'教程|教学|测评|开箱|广告|预告片|预告'),
    RegExp(r'直播|录播|回放'),
    RegExp(r'合集|集锦|精选|混剪|盘点'),
    RegExp(r'鬼畜|恶搞|搞笑|吐槽|翻车|车祸'),
    RegExp(r'reaction|反应|弹幕'),
    RegExp(r'ASMR|助眠|白噪音|睡眠|冥想'),
    RegExp(r'纯聊|聊天|唠嗑|vlog'),
    RegExp(r'谱子|乐谱|简谱|吉他谱|钢琴谱|教学|教程|演示|示范'),
  ];

  /// Quality / authenticity boost patterns – suggest this IS a proper song.
  static final _qualityBoostPatterns = <RegExp>[
    RegExp(r'无损|Hi-Res|高音质|HQ|SQ|HiFi'),
    RegExp(r'录音棚|录音室|Studio'),
    RegExp(r'官方|Official|MV|M/V'),
    RegExp(r'原唱|原版|完整版|纯享|Full'),
    RegExp(r'现场|LIVE|演唱会|音乐会'),
    RegExp(r'4K|1080P|高画质'),
  ];

  // ── public API ────────────────────────────────────────────────────

  @override
  String get name => 'Bilibili';

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      // Optimize search query: B站 music content responds better with extra context
      final searchQuery = query.length < 10 ? '$query 原唱' : query;

      final response = await _client.get(
        'https://api.bilibili.com/x/web-interface/search/type/v2',
        queryParameters: {
          'search_type': 'video',
          'keyword': searchQuery,
          'page': 1,
        },
      );

      if (response.statusCode != 200) return [];
      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 0) return [];

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return [];

      final resultList = data['result'] as List<dynamic>? ?? [];
      Map<String, dynamic>? videoResult;
      for (final r in resultList) {
        if (r is Map<String, dynamic> && r['type'] == 'video') {
          videoResult = r;
          break;
        }
      }
      if (videoResult == null) return [];

      final videos = videoResult['data'] as List<dynamic>?;
      if (videos == null || videos.isEmpty) return [];

      // Build scored candidates
      final candidates = <_ScoredMatch>[];
      for (final v in videos) {
        final map = v as Map<String, dynamic>;
        final title = _stripTags(map['title'] as String? ?? '');
        final duration = _parseDuration(map['duration'] as String?);

        // 2.B.1 – duration gate
        final durSec = duration.inSeconds;
        if (durSec < _minDurationSec || durSec > _maxDurationSec) continue;

        // 2.B.1 – blacklist gate
        if (_isBlacklisted(title)) continue;

        final bvid = map['bvid'] as String? ?? '';
        final author = map['author'] as String? ?? '';
        final tag = map['tag'] as String? ?? '';
        final pic = _fixProtocol(map['pic'] as String?);

        // 2.B.1 – quality score
        final score = _qualityScore(title, tag);

        // 2.B.3 – prefer duration close to typical song (3-6 min)
        final durationScore = _durationScore(durSec);

        candidates.add(_ScoredMatch(
          bvid: bvid,
          title: title,
          author: author,
          duration: duration,
          thumbnail: pic,
          score: score + durationScore,
        ));
      }

      // Sort by score descending, then by closeness to typical song duration
      candidates.sort((a, b) => b.score.compareTo(a.score));

      return candidates.map((c) => TonicSourceMatch(
        id: c.bvid,
        title: c.title,
        artists: [c.author],
        duration: c.duration,
        thumbnail: c.thumbnail,
        externalUri: 'https://www.bilibili.com/video/${c.bvid}',
        sourceName: name,
      )).toList();
    } on DioException {
      return [];
    }
  }

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    try {
      final cid = await _getCid(match.id);
      if (cid == null) return [];

      // Step 2: get playurl with DASH format (fnval=4048 = 16|32|64|128|256|512|1024|2048)
      final playurlResp = await _client.get(
        'https://api.bilibili.com/x/player/playurl',
        queryParameters: {
          'bvid': match.id,
          'cid': cid,
          'fnval': 4048,
          'fnver': 0,
          'fourk': 1,
        },
      );

      final body = playurlResp.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 0) return [];

      final dash = body['data']?['dash'] as Map<String, dynamic>?;
      if (dash == null) return [];

      final audios = (dash['audio'] as List<dynamic>?) ?? [];
      if (audios.isEmpty) return [];

      // Sort by bandwidth descending (highest quality first)
      audios.sort(
        (a, b) => ((b['bandwidth'] as int?) ?? 0)
            .compareTo((a['bandwidth'] as int?) ?? 0),
      );

      return audios.map<TonicSourceStream>((a) {
        final map = a as Map<String, dynamic>;
        return TonicSourceStream(
          url: map['baseUrl'] as String? ?? '',
          container: 'm4a',
          codec: map['codecs'] as String?,
          bitrate: (map['bandwidth'] as int?),
        );
      }).toList();
    } on DioException {
      return [];
    }
  }

  /// 2.B.2 – Try to extract lyrics from B站 video subtitle / CC track.
  Future<String?> getLyrics(String bvid) async {
    try {
      final cid = await _getCid(bvid);
      if (cid == null) return null;

      final resp = await _client.get(
        'https://api.bilibili.com/x/player/v2',
        queryParameters: {'bvid': bvid, 'cid': cid},
      );
      final body = resp.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 0) return null;

      final subtitle = body['data']?['subtitle'] as Map<String, dynamic>?;
      final subtitles = subtitle?['subtitles'] as List<dynamic>?;
      if (subtitles == null || subtitles.isEmpty) return null;

      // Pick Chinese subtitle track (lan_doc == '中文' or lan == 'zh-CN')
      Map<String, dynamic>? bestSub;
      for (final s in subtitles) {
        final lanDoc = s['lan_doc'] as String? ?? '';
        if (lanDoc.contains('中文') || lanDoc.contains('Chinese')) {
          bestSub = s as Map<String, dynamic>;
          break;
        }
      }
      bestSub ??= subtitles[0] as Map<String, dynamic>;

      final subUrl = bestSub['subtitle_url'] as String?;
      if (subUrl == null) return null;
      final subUrlFull = subUrl.startsWith('//') ? 'https:$subUrl' : subUrl;

      final lrcResp = await _client.get(subUrlFull,
          options: Options(responseType: ResponseType.plain));
      final raw = lrcResp.data.toString();
      return _convertSubtitleToLrc(raw);
    } on DioException {
      return null;
    }
  }

  // ── private helpers ───────────────────────────────────────────────

  Future<int?> _getCid(String bvid) async {
    final resp = await _client.get(
      'https://api.bilibili.com/x/player/pagelist',
      queryParameters: {'bvid': bvid},
    );
    final pages = (resp.data?['data'] as List<dynamic>?) ?? [];
    if (pages.isEmpty) return null;
    return pages[0]['cid'] as int?;
  }

  // ── 2.B.1 filters ─────────────────────────────────────────────────

  bool _isBlacklisted(String title) {
    return _blacklistPatterns.any((p) => p.hasMatch(title));
  }

  /// Higher score = more likely a real music video.
  int _qualityScore(String title, String tag) {
    int score = 0;
    final searchText = '$title $tag';
    for (final p in _qualityBoostPatterns) {
      if (p.hasMatch(searchText)) score += 10;
    }
    // Bonus for having a tag (better classified video)
    if (tag.isNotEmpty) score += 5;
    return score;
  }

  /// Prefer 3-6 min songs; penalty outside that range.
  int _durationScore(int seconds) {
    if (seconds >= 180 && seconds <= 360) return 10;
    if (seconds >= 120 && seconds <= 480) return 5;
    if (seconds >= 480) return -5;
    return 0;
  }

  String? _fixProtocol(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  String _stripTags(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Duration _parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) return Duration.zero;
    final parts = duration.split(':');
    if (parts.length == 2) {
      return Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    }
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    return Duration.zero;
  }

  /// 2.B.2 – Convert B站 JSON subtitle to simple LRC-like text.
  String? _convertSubtitleToLrc(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final items = decoded['body'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final buf = StringBuffer();
      for (final it in items) {
        final map = it as Map<String, dynamic>;
        final fromSec = (map['from'] as num?)?.toDouble() ?? 0;
        final content = map['content'] as String? ?? '';
        if (content.isEmpty) continue;

        final min = (fromSec ~/ 60).toString().padLeft(2, '0');
        final sec = (fromSec % 60).toStringAsFixed(2).padLeft(5, '0');
        buf.writeln('[$min:$sec]$content');
      }
      return buf.toString();
    } catch (_) {
      return null;
    }
  }
}

class _ScoredMatch {
  final String bvid;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnail;
  final int score;

  _ScoredMatch({
    required this.bvid,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.score,
  });
}
