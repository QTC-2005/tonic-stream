import 'tonic_audio_source.dart';

/// Result of searching an audio source engine.
class TonicSourceMatch {
  final String id;
  final String title;
  final List<String> artists;
  final Duration duration;
  final String? thumbnail;
  final String externalUri;
  final String sourceName;

  const TonicSourceMatch({
    required this.id,
    required this.title,
    required this.artists,
    required this.duration,
    this.thumbnail,
    required this.externalUri,
    required this.sourceName,
  });
}

/// A playable stream variant from an audio source.
class TonicSourceStream {
  final String url;
  final String container;
  final String? codec;
  final int? bitrate;

  const TonicSourceStream({
    required this.url,
    required this.container,
    this.codec,
    this.bitrate,
  });
}

/// Priority tier for an audio source engine.
///
/// Engines at a higher tier are tried before lower tiers.
enum SourcePriority {
  /// Built-in sources (Bilibili, etc.) — fastest, most reliable.
  builtin,

  /// MusicFree JS plugin bridge.
  musicfree,

  /// Legacy Hetu Script plugins (retained for compatibility).
  hetuPlugin,
}

/// Descriptor registering an engine with the [SourceAggregator].
class SourceEntry {
  final TonicAudioSource engine;
  final SourcePriority priority;

  const SourceEntry({
    required this.engine,
    required this.priority,
  });
}
