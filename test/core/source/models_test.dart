import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';

/// Minimal step to verify TonicAudioSource interface can be implemented.
class _FakeSource extends TonicAudioSource {
  @override
  String get name => 'Fake';

  @override
  Future<List<TonicSourceMatch>> search(String query) async => [];

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async =>
      [];
}

void main() {
  group('TonicSourceMatch', () {
    test('creates with all required fields', () {
      final match = TonicSourceMatch(
        id: 'BV1xx',
        title: 'Test Song',
        artists: const ['Artist A', 'Artist B'],
        duration: const Duration(minutes: 4, seconds: 15),
        thumbnail: 'https://i0.hdslb.com/bfs/archive/test.jpg',
        externalUri: 'https://www.bilibili.com/video/BV1xx',
        sourceName: 'Bilibili',
      );

      expect(match.id, 'BV1xx');
      expect(match.title, 'Test Song');
      expect(match.artists, ['Artist A', 'Artist B']);
      expect(match.duration, const Duration(minutes: 4, seconds: 15));
      expect(match.thumbnail, contains('hdslb.com'));
      expect(match.externalUri, contains('BV1xx'));
      expect(match.sourceName, 'Bilibili');
    });

    test('thumbnail can be null', () {
      final match = TonicSourceMatch(
        id: '1',
        title: 'No Thumb',
        artists: const [],
        duration: Duration.zero,
        externalUri: 'https://example.com',
        sourceName: 'test',
      );
      expect(match.thumbnail, isNull);
    });

    test('quality tag defaults to unknown', () {
      final match = TonicSourceMatch(
        id: '1', title: 't', artists: const [],
        duration: Duration.zero, externalUri: 'http://x', sourceName: 'x',
      );
      expect(match.qualityTag, QualityTag.unknown);
    });

    test('quality tag can be set to lossless', () {
      final match = TonicSourceMatch(
        id: '1', title: 't', artists: const [],
        duration: Duration.zero, externalUri: 'http://x', sourceName: 'x',
        qualityTag: QualityTag.lossless,
      );
      expect(match.qualityTag, QualityTag.lossless);
    });

    test('cacheData defaults to null', () {
      final match = TonicSourceMatch(
        id: '1', title: 't', artists: const [],
        duration: Duration.zero, externalUri: 'http://x', sourceName: 'x',
      );
      expect(match.cacheData, isNull);
    });

    test('cacheData can carry prefetched info', () {
      final match = TonicSourceMatch(
        id: '1', title: 't', artists: const [],
        duration: Duration.zero, externalUri: 'http://x', sourceName: 'x',
        cacheData: {'url': 'https://prefetched.example.com/stream'},
      );
      expect(match.cacheData!['url'], contains('prefetched'));
    });
  });

  group('TonicSourceStream', () {
    test('creates with all fields', () {
      final stream = TonicSourceStream(
        url: 'https://audio.bilibili.com/stream.m4a',
        container: 'm4a',
        codec: 'mp4a.40.2',
        bitrate: 320000,
      );

      expect(stream.url, contains('stream.m4a'));
      expect(stream.container, 'm4a');
      expect(stream.codec, 'mp4a.40.2');
      expect(stream.bitrate, 320000);
    });

    test('optional fields can be null', () {
      final stream = TonicSourceStream(
        url: 'https://example.com/audio',
        container: 'mp3',
      );
      expect(stream.codec, isNull);
      expect(stream.bitrate, isNull);
    });
  });

  group('QualityTag', () {
    test('has four distinct values', () {
      final indices = QualityTag.values.map((e) => e.index).toSet();
      expect(indices.length, 4);
    });

    test('ordering: lossless < high < standard < unknown', () {
      expect(QualityTag.lossless.index, lessThan(QualityTag.high.index));
      expect(QualityTag.high.index, lessThan(QualityTag.standard.index));
      expect(QualityTag.standard.index, lessThan(QualityTag.unknown.index));
    });
  });

  group('SourceEntry', () {
    test('holds engine and tracks latency', () {
      final engine = _FakeSource();
      final entry = SourceEntry(engine: engine);

      expect(entry.engine, same(engine));
      expect(entry.recentLatencies, isEmpty);
      expect(entry.averageLatencyMs, double.infinity);
    });

    test('recordLatency stores samples', () {
      final entry = SourceEntry(engine: _FakeSource());
      entry.recordLatency(100);
      entry.recordLatency(200);

      expect(entry.recentLatencies.length, 2);
      expect(entry.averageLatencyMs, 150);
    });

    test('recordLatency keeps at most 10 samples', () {
      final entry = SourceEntry(engine: _FakeSource());
      for (int i = 0; i < 15; i++) {
        entry.recordLatency(i * 10);
      }
      expect(entry.recentLatencies.length, 10);
      // Should have kept the last 10 (indices 5-14)
      expect(entry.recentLatencies.first, 50);
      expect(entry.recentLatencies.last, 140);
    });

    test('userBoost affects sortScore', () {
      final entry = SourceEntry(engine: _FakeSource());
      entry.recordLatency(200);
      entry.userBoost = -100;

      expect(entry.sortScore, 100); // 200 + (-100)
    });

    test('sortScore with no latency is infinite', () {
      final entry = SourceEntry(engine: _FakeSource());
      expect(entry.sortScore, double.infinity);
    });
  });

  group('TonicAudioSource', () {
    test('can be implemented by a fake engine', () {
      final source = _FakeSource();
      expect(source.name, 'Fake');
    });

    test('search returns list', () async {
      final source = _FakeSource();
      final results = await source.search('test');
      expect(results, isA<List<TonicSourceMatch>>());
    });

    test('getStreams returns list', () async {
      final source = _FakeSource();
      final match = TonicSourceMatch(
        id: '1', title: 't', artists: const [],
        duration: Duration.zero, externalUri: 'http://x', sourceName: 'x',
      );
      final streams = await source.getStreams(match);
      expect(streams, isA<List<TonicSourceStream>>());
    });
  });
}
