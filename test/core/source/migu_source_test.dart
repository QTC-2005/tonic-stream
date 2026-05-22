import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/migu/migu_audio_source.dart';

class _MiguMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final params = options.uri.queryParameters;
    final n = params['n'] ?? '';
    final gm = params['gm'] ?? '';
    String body;

    if (options.uri.path.endsWith('.lrc')) {
      body = '[00:00.00]晴天 - 周杰伦\n[00:10.00]故事的小黄花';
    } else if (n.isNotEmpty && n != '') {
      // Detail API
      if (n == '1' && gm == '晴天') {
        body = jsonEncode({
          'code': 200,
          'title': '晴天',
          'singer': '周杰伦',
          'cover': 'https://d.musicapp.migu.cn/prod/pic/abc.jpg',
          'music_url': 'https://freetyst.nf.migu.cn/M500001.flac',
          'lrc_url': 'https://d.musicapp.migu.cn/lrc/abc.lrc',
          'link': 'https://music.migu.cn/v3/music/song/abc',
        });
      } else if (n == '2' && gm == '晴天') {
        body = jsonEncode({
          'code': 200,
          'title': '晴天',
          'singer': '刘瑞琦',
          'music_url': 'https://freetyst.nf.migu.cn/M500002.mp3',
          'lrc_url': null,
        });
      } else {
        body = jsonEncode({'code': 404});
      }
    } else {
      // Search API
      body = jsonEncode({
        'code': 200,
        'data': [
          {'n': 1, 'title': '晴天', 'singer': '周杰伦'},
          {'n': 2, 'title': '晴天', 'singer': '刘瑞琦'},
        ],
      });
    }

    return ResponseBody(
      Stream.fromIterable([utf8.encode(body)]),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('MiguAudioSource', () {
    late MiguAudioSource source;

    setUp(() {
      final dio = Dio();
      dio.httpClientAdapter = _MiguMockAdapter();
      source = MiguAudioSource(client: dio);
    });

    test('name is Migu', () {
      expect(source.name, 'Migu');
    });

    test('search returns parsed matches', () async {
      final results = await source.search('晴天');
      expect(results.length, 2);
      expect(results[0].id, contains('|晴天'));
      expect(results[0].title, '晴天');
      expect(results[0].artists, ['周杰伦']);
      expect(results[0].sourceName, 'Migu');
    });

    test('search returns empty for empty query', () async {
      final results = await source.search('');
      expect(results, isEmpty);
    });

    test('getStreams returns audio stream from detail API', () async {
      final match = TonicSourceMatch(
        id: '1|晴天',
        title: '晴天',
        artists: const ['周杰伦'],
        duration: Duration.zero,
        externalUri: 'https://music.migu.cn/v3/music/song/',
        sourceName: 'Migu',
      );

      final streams = await source.getStreams(match);
      expect(streams.length, 1);
      expect(streams.first.url, contains('migu.cn'));
      expect(streams.first.container, 'flac');
    });

    test('getStreams returns empty for unknown id', () async {
      final match = TonicSourceMatch(
        id: '99|未知',
        title: 'unknown',
        artists: const [],
        duration: Duration.zero,
        externalUri: '',
        sourceName: 'Migu',
      );

      final streams = await source.getStreams(match);
      expect(streams, isEmpty);
    });

    test('getLyrics returns lyric text via lrc_url', () async {
      final lyric = await source.getLyrics('1|晴天');
      expect(lyric, contains('晴天'));
      expect(lyric, contains('故事的小黄花'));
    });

    test('getLyrics returns null for unknown id', () async {
      final lyric = await source.getLyrics('99|未知');
      expect(lyric, isNull);
    });

    test('implements TonicAudioSource', () {
      expect(source, isA<TonicAudioSource>());
    });
  });
}
