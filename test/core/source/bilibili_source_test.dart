import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/bilibili/bilibili_audio_source.dart';

class _MockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final path = options.uri.path;
    String body;

    // -- subtitle endpoint (2.B.2) --
    if (path.contains('player/v2')) {
      final bvid = options.uri.queryParameters['bvid'];
      if (bvid == 'BV_has_sub') {
        body = jsonEncode({
          'code': 0,
          'data': {
            'subtitle': {
              'subtitles': [
                {
                  'lan_doc': '中文（自动生成）',
                  'subtitle_url': '//i0.hdslb.com/bfs/ai_subtitle/test.json',
                },
              ],
            },
          },
        });
      } else {
        body = jsonEncode({'code': 0, 'data': {'subtitle': null}});
      }
    } else if (path.contains('pagelist') || path.contains('playurl')) {
      final bvid = options.uri.queryParameters['bvid'];
      if (bvid == 'BV_nonexistent') {
        body = jsonEncode({'code': -404});
        return ResponseBody(
          Stream.fromIterable([utf8.encode(body)]),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      }
      if (path.contains('pagelist')) {
        body = jsonEncode({
          'code': 0,
          'data': [
            {'cid': 12345, 'page': 1, 'part': 'Full Song'},
          ],
        });
      } else {
        body = jsonEncode({
          'code': 0,
          'data': {
            'dash': {
              'audio': [
                {
                  'id': 30280,
                  'baseUrl': 'https://audio.bilibili.com/high.m4a',
                  'bandwidth': 320000,
                  'mimeType': 'audio/mp4',
                  'codecs': 'mp4a.40.2',
                },
                {
                  'id': 30216,
                  'baseUrl': 'https://audio.bilibili.com/low.m4a',
                  'bandwidth': 128000,
                  'mimeType': 'audio/mp4',
                  'codecs': 'mp4a.40.2',
                },
              ],
            },
          },
        });
      }
    } else if (path.contains('search')) {
      body = jsonEncode({
        'code': 0,
        'data': {
          'result': [
            {
              'type': 'video',
              'data': [
                // ✅ Good: proper song with quality keywords
                {
                  'bvid': 'BV_good1',
                  'title': '<em>晴天</em> 无损 高音质 官方 MV',
                  'author': '周杰伦',
                  'duration': '4:30',
                  'pic': '//i0.hdslb.com/bfs/good1.jpg',
                  'tag': '音乐',
                },
                // ✅ Good: typical song duration
                {
                  'bvid': 'BV_good2',
                  'title': '晴天 原唱完整版',
                  'author': '刘瑞琦',
                  'duration': '5:00',
                  'pic': '//i1.hdslb.com/bfs/good2.jpg',
                  'tag': '',
                },
                // ❌ Blacklisted: 教程
                {
                  'bvid': 'BV_tutorial',
                  'title': '吉他教学 晴天 吉他谱教程',
                  'author': '吉他老师',
                  'duration': '10:00',
                  'pic': '//i0.hdslb.com/bfs/tutorial.jpg',
                  'tag': '教学',
                },
                // ❌ Too short (clip)
                {
                  'bvid': 'BV_short',
                  'title': '晴天 片段',
                  'author': '剪辑手',
                  'duration': '0:30',
                  'pic': '//i0.hdslb.com/bfs/short.jpg',
                  'tag': '',
                },
                // ❌ Too long (podcast/compilation)
                {
                  'bvid': 'BV_long',
                  'title': '周杰伦歌曲合集',
                  'author': '音乐频道',
                  'duration': '45:00',
                  'pic': '//i0.hdslb.com/bfs/long.jpg',
                  'tag': '合集',
                },
                // ❌ Blacklisted: 搞笑
                {
                  'bvid': 'BV_funny',
                  'title': '搞笑翻唱晴天',
                  'author': '搞笑博主',
                  'duration': '2:00',
                  'pic': '//i0.hdslb.com/bfs/funny.jpg',
                  'tag': '搞笑',
                },
                // ✅ OK: cover with live keyword
                {
                  'bvid': 'BV_live',
                  'title': '晴天 现场 LIVE',
                  'author': 'LiveHouse',
                  'duration': '4:00',
                  'pic': '//i2.hdslb.com/bfs/live.jpg',
                  'tag': '现场',
                },
                // ✅ OK: just a normal song
                {
                  'bvid': 'BV_normal',
                  'title': '晴天翻唱',
                  'author': '普通歌手',
                  'duration': '3:30',
                  'pic': '//i0.hdslb.com/bfs/normal.jpg',
                  'tag': '翻唱',
                },
              ],
            },
          ],
        },
      });
    } else if (path.contains('ai_subtitle')) {
      // Mock subtitle JSON response
      body = jsonEncode({
        'body': [
          {'from': 0.0, 'to': 3.0, 'content': '晴天 - 周杰伦'},
          {'from': 10.0, 'to': 15.0, 'content': '故事的小黄花'},
        ],
      });
    } else {
      body = jsonEncode({'code': -404});
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
  group('BilibiliAudioSource', () {
    late BilibiliAudioSource source;

    setUp(() {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter();
      source = BilibiliAudioSource(client: dio);
    });

    // ── name ─────────────────────────────────────────────────────

    test('name is Bilibili', () {
      expect(source.name, 'Bilibili');
    });

    // ── 2.B.1 filtering ───────────────────────────────────────────

    test('search filters out blacklisted titles (教程, 搞笑, 合集)', () async {
      final results = await source.search('晴天');
      final ids = results.map((r) => r.id).toSet();
      expect(ids, isNot(contains('BV_tutorial')));
      expect(ids, isNot(contains('BV_funny')));
      expect(ids, isNot(contains('BV_long'))); // also blacklisted by duration
    });

    test('search filters out clips (duration < 1 min)', () async {
      final results = await source.search('晴天');
      final ids = results.map((r) => r.id).toSet();
      expect(ids, isNot(contains('BV_short')));
    });

    test('search filters out long videos (duration > 15 min)', () async {
      final results = await source.search('晴天');
      final ids = results.map((r) => r.id).toSet();
      expect(ids, isNot(contains('BV_long')));
    });

    test('search ranks high-quality matches first', () async {
      final results = await source.search('晴天');
      expect(results.isNotEmpty, true);
      // BV_good1 has highest quality score (无损 + 高音质 + 官方 + MV + tag)
      expect(results.first.id, 'BV_good1');
    });

    test('search returns empty for empty query', () async {
      final results = await source.search('');
      expect(results, isEmpty);
    });

    test('search strips <em> tags from title', () async {
      final results = await source.search('晴天');
      final good1 = results.firstWhere((r) => r.id == 'BV_good1');
      expect(good1.title, isNot(contains('<em>')));
    });

    test('search prepends https: to protocol-relative thumbnail', () async {
      final results = await source.search('晴天');
      expect(results.every((r) => r.thumbnail?.startsWith('https://') ?? true), true);
    });

    // ── getStreams ────────────────────────────────────────────────

    test('getStreams returns audio streams sorted by bandwidth', () async {
      final match = TonicSourceMatch(
        id: 'BV_good1',
        title: 'Test',
        artists: const ['Artist'],
        duration: Duration.zero,
        externalUri: 'https://www.bilibili.com/video/BV_good1',
        sourceName: 'Bilibili',
      );

      final streams = await source.getStreams(match);
      expect(streams.length, 2);
      expect(streams.first.bitrate, 320000);
      expect(streams.last.bitrate, 128000);
      expect(streams.first.url, contains('high.m4a'));
      expect(streams.first.container, 'm4a');
      expect(streams.first.codec, 'mp4a.40.2');
    });

    test('getStreams returns empty for unknown BVID', () async {
      final match = TonicSourceMatch(
        id: 'BV_nonexistent',
        title: 'No',
        artists: const [],
        duration: Duration.zero,
        externalUri: 'https://www.bilibili.com/video/BV_nonexistent',
        sourceName: 'Bilibili',
      );

      final streams = await source.getStreams(match);
      expect(streams, isEmpty);
    });

    // ── 2.B.2 lyrics ──────────────────────────────────────────────

    test('getLyrics returns LRC from subtitle', () async {
      final lyric = await source.getLyrics('BV_has_sub');
      expect(lyric, isNotNull);
      expect(lyric, contains('晴天'));
      expect(lyric, contains('故事的小黄花'));
    });

    test('getLyrics returns null when no subtitle', () async {
      final lyric = await source.getLyrics('BV_no_sub');
      expect(lyric, isNull);
    });

    test('getLyrics returns null for nonexistent BVID', () async {
      final lyric = await source.getLyrics('BV_nonexistent');
      expect(lyric, isNull);
    });

    // ── interface ─────────────────────────────────────────────────

    test('implements TonicAudioSource', () {
      expect(source, isA<TonicAudioSource>());
    });
  });
}
