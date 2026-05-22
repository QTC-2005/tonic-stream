import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/models/metadata/metadata.dart';

/// Aggregates multiple [TonicAudioSource] engines and routes queries
/// across them in priority order.
///
/// Built-in Dart engines are queried first, followed by MusicFree
/// bridge plugins, then legacy Hetu Script plugins as fallback.
class SourceAggregator {
  final List<SourceEntry> _sources = [];

  /// Register an engine at the given [priority].
  void addSource(TonicAudioSource engine, SourcePriority priority) {
    _sources.add(SourceEntry(engine: engine, priority: priority));
  }

  /// Remove a previously registered engine by name.
  void removeSource(String engineName) {
    _sources.removeWhere((e) => e.engine.name == engineName);
  }

  /// All registered engines, grouped by priority.
  List<SourceEntry> get sources => List.unmodifiable(_sources);

  /// Search across all engines (priority order) and return merged results.
  ///
  /// If [limitPerSource] is set, at most that many results are taken from
  /// each engine before merging.
  Future<List<TonicSourceMatch>> search(
    String query, {
    int? limitPerSource,
  }) async {
    // Sort by priority: builtin first, then musicfree, then hetu
    _sources.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    final results = <TonicSourceMatch>[];
    for (final entry in _sources) {
      try {
        var matches = await entry.engine.search(query);
        if (limitPerSource != null && matches.length > limitPerSource) {
          matches = matches.sublist(0, limitPerSource);
        }
        results.addAll(matches);
      } catch (_) {
        // Engine failure should not break the whole chain
        continue;
      }
    }
    return results;
  }

  /// Resolve stream URLs using the engine that produced [match].
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
