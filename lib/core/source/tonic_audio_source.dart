import 'package:tonic/core/source/models.dart';

/// Abstract interface for any audio source engine.
///
/// Each engine (Bilibili, NetEase, MusicFree bridge, etc.) implements
/// this interface. The [SourceAggregator] routes queries across all
/// registered engines and merges results.
abstract class TonicAudioSource {
  /// Human-readable name of this source engine (e.g. "Bilibili", "NetEase").
  String get name;

  /// Search for tracks matching [query].
  ///
  /// Returns a list of [TonicSourceMatch] objects describing each candidate.
  Future<List<TonicSourceMatch>> search(String query);

  /// Resolve playable stream URLs for the given [match].
  ///
  /// Each returned [TonicSourceStream] represents one quality/container variant.
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match);
}
