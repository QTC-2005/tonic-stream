import 'dart:async';

import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/models/metadata/metadata.dart';

/// Aggregates multiple [TonicAudioSource] engines, searches them
/// **concurrently**, tracks per-source latency, and re-ranks future
/// searches so fast sources are tried first.
///
/// ## Streaming search
/// [searchStreamed] launches all sources at once and emits results
/// as each source completes. The UI can display matches incrementally
/// ("fastest first") instead of blocking on the slowest source.
///
/// ## Dynamic priority
/// Each source's recent latency is recorded. Before every search the
/// source list is sorted so historically-fast sources go first.
/// Users can also apply a manual boost via [SourceEntry.userBoost].
///
/// ## Caching
/// Sources may attach [TonicSourceMatch.cacheData] to matches.
/// When [getStreams] is called the match is passed back to the same
/// source, which can read [cacheData] to skip a redundant API round-trip.
class SourceAggregator {
  final List<SourceEntry> _sources = [];

  /// Register an engine.
  void addSource(TonicAudioSource engine) {
    _sources.add(SourceEntry(engine: engine));
  }

  /// Remove a previously registered engine by name.
  void removeSource(String engineName) {
    _sources.removeWhere((e) => e.engine.name == engineName);
  }

  /// All registered entries.
  List<SourceEntry> get sources => List.unmodifiable(_sources);

  /// Search all engines **concurrently** and return merged results.
  ///
  /// Equivalent to calling [searchStreamed] and collecting all batches
  /// into a single flat list.
  Future<List<TonicSourceMatch>> search(
    String query, {
    int? limitPerSource,
  }) async {
    final results = <TonicSourceMatch>[];
    await for (final batch in searchStreamed(query, limitPerSource: limitPerSource)) {
      results.addAll(batch);
    }
    return results;
  }

  /// Search all engines concurrently, emitting each source's results
  /// as a batch as soon as that source completes.
  ///
  /// Sources that finish first emit first. The stream closes when
  /// every source has responded (or errored).
  Stream<List<TonicSourceMatch>> searchStreamed(
    String query, {
    int? limitPerSource,
  }) {
    final entries = List<SourceEntry>.from(_sources);

    // Sort by dynamic score: faster sources first.
    // Sources with no history go last (infinity sortScore → pushed to end).
    entries.sort((a, b) {
      final aInf = a.sortScore.isInfinite;
      final bInf = b.sortScore.isInfinite;
      if (aInf && bInf) return 0;
      if (aInf) return 1;
      if (bInf) return -1;
      return a.sortScore.compareTo(b.sortScore);
    });

    final controller = StreamController<List<TonicSourceMatch>>();
    if (entries.isEmpty) {
      controller.close();
      return controller.stream;
    }

    var completed = 0;
    final total = entries.length;

    void onDone() {
      completed++;
      if (completed >= total) {
        controller.close();
      }
    }

    for (final entry in entries) {
      final stopwatch = Stopwatch()..start();
      entry.engine.search(query).then((matches) {
        entry.recordLatency(stopwatch.elapsedMilliseconds);
        if (limitPerSource != null && matches.length > limitPerSource) {
          matches = matches.sublist(0, limitPerSource);
        }
        if (!controller.isClosed) {
          controller.add(matches);
        }
        onDone();
      }).catchError((_) {
        // Record a high latency on failure so the source is deprioritized
        entry.recordLatency(10000);
        if (!controller.isClosed) {
          controller.add([]);
        }
        onDone();
      });
    }

    return controller.stream;
  }

  /// Resolve stream URLs using the engine that produced [match].
  ///
  /// If [match.cacheData] is set the source can use it to skip
  /// a redundant API call.
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    for (final entry in _sources) {
      if (entry.engine.name == match.sourceName) {
        return entry.engine.getStreams(match);
      }
    }
    return [];
  }

  /// Bridge: convert a [TonicSourceMatch] to the Spotube model so the
  /// existing UI/player pipeline can consume it.
  SpotubeAudioSourceMatchObject toSpotubeMatch(TonicSourceMatch match) {
    return SpotubeAudioSourceMatchObject(
      id: match.id,
      title: match.title,
      artists: match.artists,
      duration: match.duration,
      thumbnail: match.thumbnail,
      externalUri: match.externalUri,
    );
  }

  /// Bridge: convert a [TonicSourceStream] to the Spotube model.
  SpotubeAudioSourceStreamObject toSpotubeStream(TonicSourceStream stream) {
    return SpotubeAudioSourceStreamObject(
      url: stream.url,
      container: stream.container,
      type: SpotubeMediaCompressionType.lossy,
      codec: stream.codec,
      bitrate: stream.bitrate?.toDouble(),
    );
  }
}
