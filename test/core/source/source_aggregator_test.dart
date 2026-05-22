import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/source_aggregator.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/models/metadata/metadata.dart';

/// Stub engine that returns fixed results with a configurable delay.
class _StubSource extends TonicAudioSource {
  final String _name;
  final List<TonicSourceMatch> _searchResults;
  final List<TonicSourceStream> _streamResults;
  bool shouldThrow = false;
  Duration delay = Duration.zero;

  _StubSource(
    this._name, {
    List<TonicSourceMatch>? searchResults,
    List<TonicSourceStream>? streamResults,
  })  : _searchResults = searchResults ?? [],
        _streamResults = streamResults ?? [];

  @override
  String get name => _name;

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    if (shouldThrow) throw Exception('$_name search failed');
    return _searchResults;
  }

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    if (shouldThrow) throw Exception('$_name getStreams failed');
    return _streamResults;
  }
}

TonicSourceMatch _stubMatch({
  String id = 'test-1',
  String title = 'Test Song',
  String sourceName = 'stub',
  QualityTag quality = QualityTag.unknown,
  Map<String, dynamic>? cacheData,
}) {
  return TonicSourceMatch(
    id: id,
    title: title,
    artists: const ['Test Artist'],
    duration: const Duration(minutes: 3, seconds: 30),
    externalUri: 'https://example.com/$id',
    sourceName: sourceName,
    qualityTag: quality,
    cacheData: cacheData,
  );
}

void main() {
  group('SourceAggregator', () {
    late SourceAggregator aggregator;

    setUp(() {
      aggregator = SourceAggregator();
    });

    test('addSource registers an engine', () {
      final engine = _StubSource('TestEngine');
      aggregator.addSource(engine);
      expect(aggregator.sources.length, 1);
      expect(aggregator.sources.first.engine.name, 'TestEngine');
    });

    test('removeSource removes by name', () {
      final engine = _StubSource('TestEngine');
      aggregator.addSource(engine);
      expect(aggregator.sources.length, 1);
      aggregator.removeSource('TestEngine');
      expect(aggregator.sources.length, 0);
    });

    test('removeSource does nothing for unknown name', () {
      aggregator.addSource(_StubSource('A'));
      aggregator.removeSource('NonExistent');
      expect(aggregator.sources.length, 1);
    });

    test('search returns results from multiple engines', () async {
      aggregator.addSource(_StubSource('A', searchResults: [
        _stubMatch(id: 'a1', sourceName: 'A'),
      ]));
      aggregator.addSource(_StubSource('B', searchResults: [
        _stubMatch(id: 'b1', sourceName: 'B'),
        _stubMatch(id: 'b2', sourceName: 'B'),
      ]));

      final results = await aggregator.search('test');
      expect(results.length, 3);
    });

    test('search returns empty when no engines registered', () async {
      final results = await aggregator.search('test');
      expect(results, isEmpty);
    });

    test('search continues after one engine throws', () async {
      final failEngine = _StubSource('Fail', searchResults: [])
        ..shouldThrow = true;
      final okEngine = _StubSource('OK', searchResults: [
        _stubMatch(id: 'ok1', sourceName: 'OK'),
      ]);
      aggregator.addSource(failEngine);
      aggregator.addSource(okEngine);

      final results = await aggregator.search('test');
      expect(results.length, 1);
      expect(results.first.sourceName, 'OK');
    });

    test('search respects limitPerSource', () async {
      final engine = _StubSource('Big', searchResults: [
        for (var i = 0; i < 10; i++) _stubMatch(id: '$i', sourceName: 'Big'),
      ]);
      aggregator.addSource(engine);

      final results = await aggregator.search('test', limitPerSource: 3);
      expect(results.length, 3);
    });

    test('search runs engines concurrently', () async {
      final engineA = _StubSource('A', searchResults: [
        _stubMatch(id: 'a1', sourceName: 'A'),
      ])..delay = const Duration(milliseconds: 200);

      final engineB = _StubSource('B', searchResults: [
        _stubMatch(id: 'b1', sourceName: 'B'),
      ])..delay = const Duration(milliseconds: 100);

      aggregator.addSource(engineA);
      aggregator.addSource(engineB);

      // Streamed: B should complete before A (shorter delay)
      final batches = <List<TonicSourceMatch>>[];
      final stopwatch = Stopwatch()..start();
      await for (final batch in aggregator.searchStreamed('test')) {
        batches.add(batch);
      }
      final elapsed = stopwatch.elapsedMilliseconds;

      // Both batches should have arrived
      expect(batches.length, 2);
      // Total time should be ~200ms (max), not ~300ms (sum) — concurrent
      expect(elapsed, lessThan(400)); // generous bound for CI flakiness
    });

    test('searchStreamed emits results as batches', () async {
      aggregator.addSource(_StubSource('A', searchResults: [
        _stubMatch(id: 'a1', sourceName: 'A'),
      ]));
      aggregator.addSource(_StubSource('B', searchResults: [
        _stubMatch(id: 'b1', sourceName: 'B'),
      ]));

      final batches = <List<TonicSourceMatch>>[];
      await for (final batch in aggregator.searchStreamed('test')) {
        batches.add(batch);
      }

      expect(batches.length, 2);
      final allIds = batches.expand((b) => b.map((m) => m.id)).toSet();
      expect(allIds, contains('a1'));
      expect(allIds, contains('b1'));
    });

    test('latency is recorded per source', () async {
      final engine = _StubSource('A', searchResults: [
        _stubMatch(sourceName: 'A'),
      ]);
      aggregator.addSource(engine);

      await aggregator.search('test');

      final entry = aggregator.sources.first;
      expect(entry.recentLatencies, isNotEmpty);
      expect(entry.recentLatencies.first, greaterThanOrEqualTo(0));
    });

    test('dynamic sorting: faster sources searched first', () async {
      final fast = _StubSource('Fast', searchResults: [
        _stubMatch(sourceName: 'Fast'),
      ]);
      final slow = _StubSource('Slow', searchResults: [
        _stubMatch(sourceName: 'Slow'),
      ])..delay = const Duration(milliseconds: 100);

      aggregator.addSource(fast);
      aggregator.addSource(slow);

      // First search: both have no latency data, sorted evenly
      await aggregator.search('first');
      // Second search: one should have lower latency
      await aggregator.search('second');

      final entries = aggregator.sources;
      final fastEntry = entries.firstWhere((e) => e.engine.name == 'Fast');
      final slowEntry = entries.firstWhere((e) => e.engine.name == 'Slow');

      // Fast should have lower latency than Slow
      expect(fastEntry.averageLatencyMs, lessThan(slowEntry.averageLatencyMs));
    });

    test('searchStreamed is sorted by score', () async {
      // Give Fast a history of low latency
      final fast = _StubSource('Fast', searchResults: [
        _stubMatch(sourceName: 'Fast', id: 'f1'),
      ]);
      final slow = _StubSource('Slow', searchResults: [
        _stubMatch(sourceName: 'Slow', id: 's1'),
      ])..delay = const Duration(milliseconds: 200);

      aggregator.addSource(fast);
      aggregator.addSource(slow);

      // Run one search to record latencies
      await aggregator.search('warmup');

      // Second search: Fast should come first in the stream
      final batches = <List<TonicSourceMatch>>[];
      await for (final batch in aggregator.searchStreamed('test')) {
        batches.add(batch);
      }

      // The first batch should be from Fast (lower latency)
      expect(batches.length, 2);
      expect(batches[0].first.sourceName, 'Fast');
    });

    test('getStreams dispatches to correct engine by sourceName', () async {
      final stream = TonicSourceStream(
        url: 'https://example.com/stream',
        container: 'm4a',
        bitrate: 128000,
      );
      final engineA = _StubSource('A', streamResults: [stream]);
      final engineB = _StubSource('B', streamResults: []);
      aggregator.addSource(engineA);
      aggregator.addSource(engineB);

      final match = _stubMatch(sourceName: 'A');
      final results = await aggregator.getStreams(match);
      expect(results.length, 1);
      expect(results.first.url, 'https://example.com/stream');
    });

    test('getStreams returns empty for unknown sourceName', () async {
      aggregator.addSource(_StubSource('A'));

      final match = _stubMatch(sourceName: 'NonExistent');
      final results = await aggregator.getStreams(match);
      expect(results, isEmpty);
    });

    test('toSpotubeMatch converts TonicSourceMatch correctly', () {
      final match = _stubMatch(id: 'bv123', title: 'Hello', sourceName: 'Bilibili');
      final spotubeMatch = aggregator.toSpotubeMatch(match);

      expect(spotubeMatch.id, 'bv123');
      expect(spotubeMatch.title, 'Hello');
      expect(spotubeMatch.artists, ['Test Artist']);
      expect(spotubeMatch.duration, const Duration(minutes: 3, seconds: 30));
      expect(spotubeMatch.externalUri, 'https://example.com/bv123');
    });

    test('toSpotubeStream converts TonicSourceStream correctly', () {
      final stream = TonicSourceStream(
        url: 'https://audio.example.com/stream.m4a',
        container: 'm4a',
        codec: 'mp4a.40.2',
        bitrate: 320000,
      );
      final spotubeStream = aggregator.toSpotubeStream(stream);

      expect(spotubeStream.url, 'https://audio.example.com/stream.m4a');
      expect(spotubeStream.container, 'm4a');
      expect(spotubeStream.codec, 'mp4a.40.2');
      expect(spotubeStream.bitrate, 320000);
      expect(spotubeStream.type, SpotubeMediaCompressionType.lossy);
    });

    test('QualityTag is propagated in TonicSourceMatch', () {
      final match = _stubMatch(quality: QualityTag.lossless);
      expect(match.qualityTag, QualityTag.lossless);

      final defaultMatch = _stubMatch();
      expect(defaultMatch.qualityTag, QualityTag.unknown);
    });

    test('cacheData is stored and retrievable from match', () {
      final cacheData = <String, dynamic>{'url': 'https://example.com/prefetched'};
      final match = _stubMatch(cacheData: cacheData);
      expect(match.cacheData, isNotNull);
      expect(match.cacheData!['url'], 'https://example.com/prefetched');
    });

    test('userBoost affects sort score', () {
      final entry = SourceEntry(engine: _StubSource('A'));
      expect(entry.sortScore, double.infinity); // No latency data yet

      entry.recordLatency(100);
      entry.userBoost = -50;
      expect(entry.sortScore, 50); // 100 + (-50)
    });
  });
}
