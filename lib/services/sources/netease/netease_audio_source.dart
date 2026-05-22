import 'package:dio/dio.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

class NeteaseAudioSource extends TonicAudioSource {
  final Dio _client;

  NeteaseAudioSource({Dio? client}) : _client = client ?? Dio();

  @override
  String get name => 'Netease';

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _client.get(
        'https://api.vkeys.cn/v2/music/netease',
        queryParameters: {'word': query, 'page': 1, 'num': 20},
      );

      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) return [];

      final dataList = body['data'] as List<dynamic>? ?? [];
      return dataList.map<TonicSourceMatch>((it) {
        final map = it as Map<String, dynamic>;
        final songId = map['id']?.toString() ?? '';

        return TonicSourceMatch(
          id: songId,
          title: (map['song'] as String?) ?? '',
          artists: [if ((map['singer'] as String?)?.isNotEmpty ?? false) map['singer'] as String],
          duration: Duration.zero,
          thumbnail: _fixUrl(map['cover'] as String?),
          externalUri: 'https://music.163.com/song?id=$songId',
          sourceName: name,
        );
      }).toList();
    } on DioException {
      return [];
    }
  }

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    try {
      final response = await _client.get(
        'https://api.qijieya.cn/meting/',
        queryParameters: {'type': 'song', 'id': match.id},
      );

      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      if (list.isEmpty) return [];

      final detail = list[0] as Map<String, dynamic>?;
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

  /// Fetch lyrics for a song. Not part of the TonicAudioSource interface yet
  /// but exposed as a helper for future lyrics integration.
  Future<String?> getLyrics(String songId) async {
    try {
      final response = await _client.get(
        'https://api.vkeys.cn/v2/music/netease/lyric',
        queryParameters: {'id': songId},
      );
      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) return null;
      return body['data']?['lrc'] as String?;
    } on DioException {
      return null;
    }
  }

  String? _fixUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) return 'https:$url';
    return url;
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

  int? _guessBitrate(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('hires') || lower.contains('flac')) return null;
    if (lower.contains('320')) return 320000;
    if (lower.contains('128')) return 128000;
    return null;
  }
}
