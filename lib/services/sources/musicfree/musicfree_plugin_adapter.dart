import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'musicfree_bridge.dart';

/// Wraps a MusicFree JS plugin as a [TonicAudioSource].
///
/// Each adapter owns its own [MusicFreeBridge] (QuickJS runtime).
/// This keeps plugins isolated from each other.
class MusicFreePluginAdapter extends TonicAudioSource {
  final String _jsCode;
  final MusicFreeBridge _bridge;
  String _platformName = 'MusicFree';
  bool _loaded = false;

  MusicFreePluginAdapter(this._jsCode)
      : _bridge = MusicFreeBridge();

  /// Initialize the JS runtime and load the plugin code.
  Future<void> init() async {
    await _bridge.init();
    await _bridge.loadPlugin(_jsCode);

    // Read the plugin's platform/name property
    try {
      final nameResult = await _bridge.callMethod('platform', []);
      // If platform is a string property (not a function), callMethod handles it.
      // Otherwise we keep the default.
      if (nameResult != null && nameResult['ok'] == true && nameResult['data'] is String) {
        _platformName = nameResult['data'] as String;
      }
    } catch (_) {
      // keep default name
    }

    _loaded = true;
  }

  @override
  String get name => _platformName;

  @override
  Future<List<TonicSourceMatch>> search(String query) async {
    if (!_loaded || query.isEmpty) return [];

    final result = await _bridge.callMethod('search', [query, 1, 'music']);
    if (result == null || result['ok'] != true) return [];

    final data = result['data'] as Map<String, dynamic>?;
    final items = (data?['data'] ?? data?['items'] ?? []) as List<dynamic>?;
    if (items == null || items.isEmpty) return [];

    return items.map<TonicSourceMatch>((it) {
      final m = it as Map<String, dynamic>? ?? {};
      final id = (m['id'] ?? m['songid'] ?? m['mid'] ?? '').toString();

      return TonicSourceMatch(
        id: id,
        title: (m['name'] ?? m['title'] ?? m['songname'] ?? '').toString(),
        artists: _extractArtists(m),
        duration: _parseMsDuration(m['duration']),
        thumbnail: m['cover'] ?? m['pic'] ?? m['artwork'] ?? m['img'],
        externalUri: m['url'] ?? m['externalUri'],
        sourceName: name,
      );
    }).toList();
  }

  @override
  Future<List<TonicSourceStream>> getStreams(TonicSourceMatch match) async {
    if (!_loaded) return [];

    final musicItem = {
      'id': match.id,
      'name': match.title,
      'artist': match.artists.isNotEmpty ? match.artists.first : '',
      'title': match.title,
    };

    final result = await _bridge.callMethod('getMediaSource', [musicItem, 'high']);
    if (result == null || result['ok'] != true) return [];

    final data = result['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return [];

    return [
      TonicSourceStream(
        url: url,
        container: _guessContainer(url),
        bitrate: data['quality'] == 'super'
            ? null
            : data['quality'] == 'high'
                ? 320000
                : 128000,
      ),
    ];
  }

  Future<String?> getLyrics(String songId) async {
    if (!_loaded) return null;

    final musicItem = {'id': songId};
    final result = await _bridge.callMethod('getLyric', [musicItem]);
    if (result == null || result['ok'] != true) return null;

    final data = result['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return (data['rawLrc'] ?? data['lrc'] ?? data['lyric']) as String?;
  }

  void dispose() {
    _bridge.dispose();
    _loaded = false;
  }

  // ── helpers ────────────────────────────────────────────────────

  List<String> _extractArtists(Map<String, dynamic> m) {
    final artist = m['artist'] ?? m['artists'] ?? m['singer'] ?? m['singername'];
    if (artist == null) return [];
    if (artist is List) return artist.map((e) => e.toString()).toList();
    return [artist.toString()];
  }

  Duration _parseMsDuration(dynamic dur) {
    if (dur == null) return Duration.zero;
    if (dur is int) return Duration(milliseconds: dur);
    if (dur is double) return Duration(milliseconds: dur.toInt());
    if (dur is String) {
      final ms = int.tryParse(dur);
      if (ms != null) return Duration(milliseconds: ms);
    }
    return Duration.zero;
  }

  String _guessContainer(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.flac')) return 'flac';
    if (lower.contains('.mp3')) return 'mp3';
    if (lower.contains('.m4a')) return 'm4a';
    return 'mp3';
  }
}
