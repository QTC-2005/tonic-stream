import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/netease/netease_audio_source.dart';

class _NeteaseMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final path = options.uri.path;
    final params = options.uri.queryParameters;
    String body;

    if (path.contains('netease') && !path.contains('lyric')) {
      // Search API
      body = jsonEncode({
        'code': 200,
        'data': [
          {
            'id': 186059,
            'song': '晴天',
            'singer': '周杰伦',
            'album': '叶惠美',
            'cover': '//p1.music.126.net/abc.jpg',
          },
          {
            'id': 25640123,
            'song': '晴天',
            'singer': '刘瑞琦',
            'album': '晴天',
            'cover': 'https://p1.music.126.net/def.jpg',
          },
        ],
      });
    } else if (path.contains('netease') && path.contains('lyric')) {
      final id = params['id'];
      if (id == '186059') {
        body = jsonEncode({
          'code': 200,
          'data': {'lrc': '[00:00.00]晴天 - 周杰伦\n[00:10.00]故事的小黄花'},
        });
      } else {
        body = jsonEncode({'code': 200, 'data': {'lrc': ''}});
      }
    } else if (path.contains('meting')) {
      // Detail API
      body = jsonEncode([
        {
          'name': '晴天',
          'artist': '周杰伦',
          'url': 'https://m801.music.126.net/stream.mp3',
          'pic': 'https://p1.music.126.net/abc.jpg',
        },
      ]);
    } else {
      body = jsonEncode({'code': -1});
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
  group('NeteaseAudioSource', () {
    late NeteaseAudioSource source;

    setUp(() {
      final dio = Dio();
      dio.httpClientAdapter = _NeteaseMockAdapter();
      source = NeteaseAudioSource(client: dio);
    });

    test('name is Netease', () {
      expect(source.name, 'Netease');
    });

    test('search returns parsed matches', () async {
      final results = await source.search('晴天');
      expect(results.length, 2);
      expect(results[0].id, '186059');
      expect(results[0].title, '晴天');
      expect(results[0].artists, ['周杰伦']);
      expect(results[0].thumbnail, 'https://p1.music.126.net/abc.jpg');
      expect(results[0].sourceName, 'Netease');
      expect(results[0].externalUri, contains('music.163.com'));
    });

    test('search returns empty for empty query', () async {
      final results = await source.search('');
      expect(results, isEmpty);
    });

    test('search fixes protocol-relative URLs', () async {
      final results = await source.search('晴天');
      expect(results[0].thumbnail, startsWith('https://'));
    });

    test('getStreams returns audio stream from meting API', () async {
      final match = TonicSourceMatch(
        id: '186059',
        title: '晴天',
        artists: const ['周杰伦'],
        duration: Duration.zero,
        externalUri: 'https://music.163.com/song?id=186059',
        sourceName: 'Netease',
      );

      final streams = await source.getStreams(match);
      expect(streams.length, 1);
      expect(streams.first.url, contains('stream.mp3'));
      expect(streams.first.container, 'mp3');
    });

    test('getLyrics returns lyric text', () async {
      final lyric = await source.getLyrics('186059');
      expect(lyric, contains('晴天'));
      expect(lyric, contains('故事的小黄花'));
    });

    test('getLyrics returns null for unknown id', () async {
      final lyric = await source.getLyrics('99999999');
      expect(lyric, '');
    });

    test('implements TonicAudioSource', () {
      expect(source, isA<TonicAudioSource>());
    });
  });
}
