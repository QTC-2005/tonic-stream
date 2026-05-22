import 'package:dio/dio.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

class MiguAudioSource extends TonicAudioSource {
  final Dio _client;

  MiguAudioSource({Dio? client}) : _client = client ?? Dio();

  @override
  String get name => 'Migu';

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _client.get(
        'https://api.xcvts.cn/api/music/migu',
        queryParameters: {'gm': query, 'n': '', 'num': '20', 'type': 'json'},
      );

      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) return [];

      final dataList = body['data'] as List<dynamic>? ?? [];
      return dataList.map<TonicSourceMatch>((it) {
        final map = it as Map<String, dynamic>;
        final n = map['n']?.toString() ?? '0';
        final id = '$n|$query';

        return TonicSourceMatch(
          id: id,
          title: (map['title'] as String?) ?? '',
          artists: [
            if ((map['singer'] as String?)?.isNotEmpty ?? false)
              map['singer'] as String,
          ],
          duration: Duration.zero,
          externalUri: 'https://music.migu.cn/v3/music/song/',
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
      final detail = await _fetchDetail(match.id);
      if (detail == null) return [];

      final url = detail['music_url'] as String?;
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

      final lrcUrl = detail['lrc_url'] as String?;
      if (lrcUrl != null && lrcUrl.isNotEmpty) {
        final lrcResp = await _client.get(lrcUrl,
            options: Options(responseType: ResponseType.plain));
        return lrcResp.data.toString();
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchDetail(String songId) async {
    final idx = songId.indexOf('|');
    if (idx == -1) return null;
    final n = songId.substring(0, idx);
    final keyword = songId.substring(idx + 1);

    final response = await _client.get(
      'https://api.xcvts.cn/api/music/migu',
      queryParameters: {
        'gm': keyword,
        'n': n,
        'num': '20',
        'type': 'json',
      },
    );
    final body = response.data as Map<String, dynamic>?;
    if (body == null || body['code'] != 200) return null;
    return body;
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
