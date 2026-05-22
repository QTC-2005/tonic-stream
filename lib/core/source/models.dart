import 'tonic_audio_source.dart';

/// Quality tag for a search result match.
///
/// Helps users select high-quality tracks. Sources populate this
/// based on what they know from the search API response.
enum QualityTag {
  /// Lossless: FLAC/APE/WAV/SQ/ZP/Hi-Res — best quality.
  lossless,

  /// High: 320kbps MP3, HQ — good quality.
  high,

  /// Standard: 128kbps or equivalent.
  standard,

  /// Cannot be determined from search results alone.
  unknown,
}

/// Result of searching an audio source engine.
class TonicSourceMatch {
  final String id;
  final String title;
  final List<String> artists;
  final Duration duration;
  final String? thumbnail;
  final String externalUri;
  final String sourceName;

  /// Inferred quality for this match.
  ///
  /// Sources like QQ Music and Kuwo can detect lossless/high tracks
  /// from the search API. Others default to [QualityTag.unknown].
  final QualityTag qualityTag;

  /// Opaque data cached from search for use by [getStreams].
  ///
  /// When a source emits a match with [cacheData], [getStreams] can
  /// read it back to skip a redundant API call. Sources decide what
  /// (if anything) to store here.
  final Map<String, dynamic>? cacheData;

  const TonicSourceMatch({
    required this.id,
    required this.title,
    required this.artists,
    required this.duration,
    this.thumbnail,
    required this.externalUri,
    required this.sourceName,
    this.qualityTag = QualityTag.unknown,
    this.cacheData,
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

/// Descriptor registering an engine with the [SourceAggregator].
class SourceEntry {
  final TonicAudioSource engine;

  /// Sliding window of recent search latencies in milliseconds.
  /// Most recent last.  Used to compute dynamic priority.
  final List<int> recentLatencies;

  /// Manual priority boost (user-configured).
  /// Lower values are searched first. Default is 0.
  int userBoost;

  SourceEntry({
    required this.engine,
    List<int>? recentLatencies,
    this.userBoost = 0,
  }) : recentLatencies = recentLatencies ?? [];

  /// Average latency, or [double.infinity] if no data yet.
  double get averageLatencyMs {
    if (recentLatencies.isEmpty) return double.infinity;
    return recentLatencies.reduce((a, b) => a + b) / recentLatencies.length;
  }

  /// Score for sorting: lower = faster → searched first.
  /// Negative userBoost pushes a source ahead.
  double get sortScore => averageLatencyMs + userBoost;

  /// Record a new latency sample (max 10 samples kept).
  void recordLatency(int ms) {
    recentLatencies.add(ms);
    while (recentLatencies.length > 10) {
      recentLatencies.removeAt(0);
    }
  }
}
