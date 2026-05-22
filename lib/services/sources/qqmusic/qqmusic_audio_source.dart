import 'package:dio/dio.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

class QQMusicAudioSource extends TonicAudioSource {
  final Dio _client;

  QQMusicAudioSource({Dio? client}) : _client = client ?? Dio();

  @override
  String get name => 'QQMusic';

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _client.get(
        'https://tang.api.s01s.cn/music_open_api.php',
        queryParameters: {'msg': query, 'type': 'json'},
      );

      final body = response.data;
      final List<dynamic> dataList;
      if (body is List) {
        dataList = body;
      } else if (body is Map<String, dynamic>) {
        dataList = (body['data'] as List<dynamic>?) ?? [];
      } else {
        return [];
      }

      return dataList.map<TonicSourceMatch>((it) {
        final map = it as Map<String, dynamic>;
        final songId = map['song_mid']?.toString() ?? '';

        return TonicSourceMatch(
          id: songId,
          title: (map['song_title'] as String?) ?? '',
          artists: [
            if ((map['singer_name'] as String?)?.isNotEmpty ?? false)
              map['singer_name'] as String,
          ],
          duration: Duration.zero,
          externalUri: 'https://y.qq.com/n/ryqq/songDetail/$songId',
          sourceName: name,
          qualityTag: QualityTag.high, // Multi-quality: sq→pq→hq→standard→fq
        );
      }).toList();
    } on DioException {
      return [];
    }
  }

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    try {
      final detail = await _fetchDetail(match.id);
      if (detail == null) return [];

      final url = _pickBestUrl(detail);
      if (url == null || url.isEmpty) return [];

      return [
        TonicSourceStream(
          url: url,
          container: _guessContainer(url),
          codec: _guessCodec(url),
          bitrate: _guestBitrate(url, detail),
        ),
      ];
    } on DioException {
      return [];
    }
  }

  Future<String?> getLyrics(String songId) async {
    try {
      final detail = await _fetchDetail(songId);
      if (detail == null) return null;
      return (detail['song_lyric'] ?? detail['lyric']) as String?;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchDetail(String songMid) async {
    final response = await _client.get(
      'https://tang.api.s01s.cn/music_open_api.php',
      queryParameters: {'type': 'json', 'mid': songMid},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  String? _pickBestUrl(Map<String, dynamic> detail) {
    final candidates = [
      detail['song_play_url_sq'],
      detail['song_play_url_pq'],
      detail['song_play_url_accom'],
      detail['song_play_url_hq'],
      detail['song_play_url_standard'],
      detail['song_play_url_fq'],
      detail['song_play_url'],
    ];
    for (final url in candidates) {
      if (url != null && url.toString().isNotEmpty) return url.toString();
    }
    return null;
  }

  String _guessContainer(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp3')) return 'mp3';
    if (lower.contains('.flac')) return 'flac';
    if (lower.contains('.m4a')) return 'm4a';
    if (lower.contains('.aac')) return 'aac';
    return 'mp3';
  }

  String? _guessCodec(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('flac')) return 'flac';
    if (lower.contains('.m4a') || lower.contains('aac')) return 'aac';
    if (lower.contains('.mp3')) return 'mp3';
    return null;
  }

  int? _guestBitrate(String url, Map<String, dynamic> detail) {
    final kbpsFields = ['kbps_sq', 'kbps_pq', 'kbps_hq', 'kbps_standard', 'kbps_fq'];
    for (final field in kbpsFields) {
      final v = detail[field];
      if (v != null) {
        final kbps = int.tryParse(v.toString());
        if (kbps != null) return kbps * 1000;
      }
    }
    final lower = url.toLowerCase();
    if (lower.contains('flac') || lower.contains('wav')) return null;
    if (lower.contains('320')) return 320000;
    if (lower.contains('128')) return 128000;
    return null;
  }
}
