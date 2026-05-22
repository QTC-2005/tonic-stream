import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/qqmusic/qqmusic_audio_source.dart';

class _QQMusicMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final params = options.uri.queryParameters;
    final hasMid = params.containsKey('mid') && params['mid']!.isNotEmpty;
    String body;

    if (hasMid) {
      // Detail API
      if (params['mid'] == '001abc') {
        body = jsonEncode({
          'song_mid': '001abc',
          'song_title': '晴天',
          'singer_name': '周杰伦',
          'album_name': '叶惠美',
          'album_pic': 'https://y.gtimg.cn/music/photo_new/abc.jpg',
          'song_lyric': '[00:00.00]晴天 - 周杰伦\n[00:10.00]故事的小黄花',
          'song_play_url_hq': 'https://isure6.stream.qqmusic.qq.com/M500001abc.mp3',
          'kbps_hq': 320,
        });
      } else if (params['mid'] == '002nolyric') {
        body = jsonEncode({
          'song_mid': '002nolyric',
          'song_title': '无歌词歌曲',
          'singer_name': '未知歌手',
          'song_play_url_sq': 'https://isure6.stream.qqmusic.qq.com/M500002nolyric.flac',
          'kbps_sq': 999,
        });
      } else {
        body = jsonEncode({});
      }
    } else {
      // Search API
      body = jsonEncode([
        {
          'song_mid': '001abc',
          'song_title': '晴天',
          'singer_name': '周杰伦',
        },
        {
          'song_mid': '002def',
          'song_title': '晴天',
          'singer_name': '刘瑞琦',
        },
      ]);
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
  group('QQMusicAudioSource', () {
    late QQMusicAudioSource source;

    setUp(() {
      final dio = Dio();
      dio.httpClientAdapter = _QQMusicMockAdapter();
      source = QQMusicAudioSource(client: dio);
    });

    test('name is QQMusic', () {
      expect(source.name, 'QQMusic');
    });

    test('search returns parsed matches', () async {
      final results = await source.search('晴天');
      expect(results.length, 2);
      expect(results[0].id, '001abc');
      expect(results[0].title, '晴天');
      expect(results[0].artists, ['周杰伦']);
      expect(results[0].sourceName, 'QQMusic');
      expect(results[0].externalUri, contains('y.qq.com'));
    });

    test('search returns empty for empty query', () async {
      final results = await source.search('');
      expect(results, isEmpty);
    });

    test('getStreams returns audio stream from detail API', () async {
      final match = TonicSourceMatch(
        id: '001abc',
        title: '晴天',
        artists: const ['周杰伦'],
        duration: Duration.zero,
        externalUri: 'https://y.qq.com/n/ryqq/songDetail/001abc',
        sourceName: 'QQMusic',
      );

      final streams = await source.getStreams(match);
      expect(streams.length, 1);
      expect(streams.first.url, contains('stream.qqmusic.qq.com'));
      expect(streams.first.container, 'mp3');
      expect(streams.first.bitrate, 320000);
    });

    test('getStreams picks best quality (SQ flac)', () async {
      final match = TonicSourceMatch(
        id: '002nolyric',
        title: '无歌词歌曲',
        artists: const ['未知歌手'],
        duration: Duration.zero,
        externalUri: 'https://y.qq.com/n/ryqq/songDetail/002nolyric',
        sourceName: 'QQMusic',
      );

      final streams = await source.getStreams(match);
      expect(streams.first.url, contains('.flac'));
      expect(streams.first.container, 'flac');
    });

    test('getLyrics returns lyric text', () async {
      final lyric = await source.getLyrics('001abc');
      expect(lyric, contains('晴天'));
      expect(lyric, contains('故事的小黄花'));
    });

    test('getLyrics returns null for unknown id', () async {
      final lyric = await source.getLyrics('99999999');
      expect(lyric, isNull);
    });

    test('implements TonicAudioSource', () {
      expect(source, isA<TonicAudioSource>());
    });
  });
}
