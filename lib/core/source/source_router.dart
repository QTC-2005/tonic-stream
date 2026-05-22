import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tonic/core/source/source_aggregator.dart';
import 'package:tonic/core/source/source_provider.dart';
import 'package:tonic/models/metadata/metadata.dart';
import 'package:tonic/provider/metadata_plugin/metadata_plugin_provider.dart';

/// Routes audio source resolution through the Tonic engine chain:
///
/// 1. Built-in Dart engines (via [SourceAggregator])   ← NEW
/// 2. MusicFree JS plugin bridge                         ← Phase 2
/// 3. Legacy Hetu Script plugin                          ← existing
///
/// This is the drop-in replacement for direct
/// `MetadataPluginAudioSourceEndpoint` calls.
class SourceRouter {
  final Ref _ref;

  SourceRouter(this._ref);

  /// Search for track matches. Tries built-in sources first, then
  /// falls back to the Hetu Script plugin.
  Future<List<SpotubeAudioSourceMatchObject>> matches(
    SpotubeFullTrackObject track,
  ) async {
    final aggregator = _ref.read(tonicSourceAggregatorProvider);
    final query = track.name;

    // 1. Try built-in Dart engines
    final dartResults = await aggregator.search(query, limitPerSource: 5);
    if (dartResults.isNotEmpty) {
      return dartResults.map((m) => aggregator.toSpotubeMatch(m)).toList();
    }

    // 2. Fall back to legacy Hetu Script plugin
    final hetuPlugin = await _ref.read(audioSourcePluginProvider.future);
    if (hetuPlugin != null) {
      return hetuPlugin.audioSource.matches(track);
    }

    return [];
  }

  /// Resolve stream URLs. Delegates to the engine that produced [match]
  /// if it's a Dart-level source, otherwise falls back to the Hetu plugin.
  Future<List<SpotubeAudioSourceStreamObject>> streams(
    SpotubeAudioSourceMatchObject match,
  ) async {
    final aggregator = _ref.read(tonicSourceAggregatorProvider);

    // Check if any built-in engine owns this match (by matching externalUri)
    for (final entry in aggregator.sources) {
      try {
        final engineResults = await entry.engine.search(match.title);
        final owned = engineResults.any((r) => r.externalUri == match.externalUri);
        if (owned) {
          final streams = await entry.engine
              .getStreams(engineResults.firstWhere((r) => r.externalUri == match.externalUri));
          return streams.map((s) => aggregator.toSpotubeStream(s)).toList();
        }
      } catch (_) {
        continue;
      }
    }

    // Fall back to Hetu Script plugin
    final hetuPlugin = await _ref.read(audioSourcePluginProvider.future);
    if (hetuPlugin != null) {
      return hetuPlugin.audioSource.streams(match);
    }

    return [];
  }

  /// Whether any built-in engine is registered.
  bool get hasBuiltinEngines =>
      _ref.read(tonicSourceAggregatorProvider).sources.isNotEmpty;
}

final sourceRouterProvider = Provider<SourceRouter>((ref) {
  return SourceRouter(ref);
});
