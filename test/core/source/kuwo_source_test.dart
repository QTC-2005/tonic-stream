import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/kuwo/kuwo_audio_source.dart';

class _KuwoMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final params = options.uri.queryParameters;
    final isDetail = params['type'] == 'song';
    String body;

    if (isDetail) {
      final id = params['id'];
      if (id == '12345') {
        body = jsonEncode({
          'code': 200,
          'data': {
            'rid': '12345',
            'name': '晴天',
            'artist': '周杰伦',
            'album': '叶惠美',
            'pic': 'https://img1.kwcdn.kuwo.cn/star/album/abc.jpg',
            'url': 'https://isure6.stream.kuwo.cn/M50012345.flac',
            'lyric': '[00:00.00]晴天 - 周杰伦\n[00:10.00]故事的小黄花',
          },
        });
      } else {
        body = jsonEncode({'code': 404, 'data': null});
      }
    } else {
      // Search API
      body = jsonEncode({
        'code': 200,
        'data': [
          {
            'rid': 12345,
            'name': '晴天',
            'artist': '周杰伦',
            'album': '叶惠美',
            'pic': 'https://img1.kwcdn.kuwo.cn/star/album/abc.jpg',
          },
          {
            'rid': 67890,
            'name': '晴天',
            'artist': '刘瑞琦',
            'album': '晴天',
            'pic': null,
          },
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
  group('KuwoAudioSource', () {
    late KuwoAudioSource source;

    setUp(() {
      final dio = Dio();
      dio.httpClientAdapter = _KuwoMockAdapter();
      source = KuwoAudioSource(client: dio);
    });

    test('name is Kuwo', () {
      expect(source.name, 'Kuwo');
    });

    test('search returns parsed matches', () async {
      final results = await source.search('晴天');
      expect(results.length, 2);
      expect(results[0].id, '12345');
      expect(results[0].title, '晴天');
      expect(results[0].artists, ['周杰伦']);
      expect(results[0].thumbnail, contains('kwcdn.kuwo.cn'));
      expect(results[0].sourceName, 'Kuwo');
      expect(results[0].externalUri, contains('kuwo.cn'));
    });

    test('search returns empty for empty query', () async {
      final results = await source.search('');
      expect(results, isEmpty);
    });

    test('getStreams returns audio stream from detail API', () async {
      final match = TonicSourceMatch(
        id: '12345',
        title: '晴天',
        artists: const ['周杰伦'],
        duration: Duration.zero,
        externalUri: 'https://www.kuwo.cn/play_detail/12345',
        sourceName: 'Kuwo',
      );

      final streams = await source.getStreams(match);
      expect(streams.length, 1);
      expect(streams.first.url, contains('stream.kuwo.cn'));
      expect(streams.first.container, 'flac');
    });

    test('getStreams returns empty for unknown id', () async {
      final match = TonicSourceMatch(
        id: '99999',
        title: 'unknown',
        artists: const [],
        duration: Duration.zero,
        externalUri: '',
        sourceName: 'Kuwo',
      );

      final streams = await source.getStreams(match);
      expect(streams, isEmpty);
    });

    test('getLyrics returns lyric text', () async {
      final lyric = await source.getLyrics('12345');
      expect(lyric, contains('晴天'));
      expect(lyric, contains('故事的小黄花'));
    });

    test('getLyrics returns null for unknown id', () async {
      final lyric = await source.getLyrics('99999');
      expect(lyric, isNull);
    });

    test('implements TonicAudioSource', () {
      expect(source, isA<TonicAudioSource>());
    });
  });
}
