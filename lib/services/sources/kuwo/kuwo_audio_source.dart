import 'package:dio/dio.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

class KuwoAudioSource extends TonicAudioSource {
  final Dio _client;

  KuwoAudioSource({Dio? client}) : _client = client ?? Dio();

  @override
  String get name => 'Kuwo';

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _client.get(
        'https://kw-api.cenguigui.cn/',
        queryParameters: {'name': query, 'page': '1', 'limit': '20'},
      );

      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) return [];

      final dataList = body['data'] as List<dynamic>? ?? [];
      return dataList.map<TonicSourceMatch>((it) {
        final map = it as Map<String, dynamic>;
        final songId = map['rid']?.toString() ?? '';

        return TonicSourceMatch(
          id: songId,
          title: (map['name'] as String?) ?? '',
          artists: [
            if ((map['artist'] as String?)?.isNotEmpty ?? false)
              map['artist'] as String,
          ],
          duration: Duration.zero,
          thumbnail: map['pic'] as String?,
          externalUri: 'https://www.kuwo.cn/play_detail/$songId',
          sourceName: name,
          qualityTag: QualityTag.lossless, // getStreams uses level=zp
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

      final url = detail['url'] as String?;
      if (url == null || url.isEmpty) return [];

      return [
        TonicSourceStream(
          url: url,
          container: _guessContainer(url),
          codec: _guessCodec(url),
          bitrate: _guessBitrate(url),
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
      return detail['lyric'] as String?;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchDetail(String rid) async {
    final response = await _client.get(
      'https://kw-api.cenguigui.cn/',
      queryParameters: {
        'id': rid,
        'type': 'song',
        'level': 'zp',
        'format': 'json',
      },
    );
    final body = response.data as Map<String, dynamic>?;
    if (body == null || body['code'] != 200) return null;
    return body['data'] as Map<String, dynamic>?;
  }

  String _guessContainer(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.flac')) return 'flac';
    if (lower.contains('.mp3')) return 'mp3';
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

  int? _guessBitrate(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('flac') || lower.contains('lossless')) return null;
    if (lower.contains('320')) return 320000;
    if (lower.contains('128')) return 128000;
    return null;
  }
}
