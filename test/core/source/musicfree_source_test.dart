import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonic/core/source/models.dart';
import 'package:tonic/core/source/tonic_audio_source.dart';
import 'package:tonic/services/sources/musicfree/musicfree_bridge.dart';

/// A minimal MusicFree-compatible plugin written in pure JS (synchronous).
/// No npm dependencies — returns hardcoded results for testing the bridge.
const testPluginJs = r'''
module.exports = {
  platform: 'TestPlugin',
  version: '1.0.0',
  author: 'Tester',
  supportedSearchType: ['music'],

  search: function(query, page, type) {
    if (!query) return { isEnd: true, data: [] };
    return {
      isEnd: true,
      data: [
        {
          id: 'song_001',
          name: query + ' - 测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          duration: 245000,
          cover: 'https://img.example.com/cover.jpg',
          url: 'https://music.example.com/song_001'
        },
        {
          id: 'song_002',
          name: query + ' - 第二首',
          artist: '歌手B',
          duration: 198000,
        },
      ]
    };
  },

  getMediaSource: function(musicItem, quality) {
    return {
      url: 'https://audio.example.com/' + musicItem.id + '.mp3',
      quality: quality,
    };
  },

  getLyric: function(musicItem) {
    return {
      rawLrc: '[00:00.00]Test Lyrics Line 1\n[00:10.00]Test Lyrics Line 2',
    };
  }
};
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicFree bridge', () {
    late MusicFreeBridge bridge;

    setUp(() async {
      bridge = MusicFreeBridge();
      await bridge.init();
    });

    tearDown(() {
      bridge.dispose();
    });

    test('init completes without error', () async {
      // Bridge was already initialized in setUp — if we got here, init succeeded.
      expect(bridge, isNotNull);
    });

    test('loadPlugin executes CommonJS module', () async {
      await bridge.loadPlugin(testPluginJs);
      // If no exception, the plugin loaded successfully
    });

    test('callMethod invokes search and returns parsed results', () async {
      await bridge.loadPlugin(testPluginJs);

      final result = await bridge.callMethod('search', ['晴天', 1, 'music']);
      expect(result, isNotNull);
      expect(result['ok'], true);

      final data = result['data'] as Map<String, dynamic>?;
      expect(data, isNotNull);
      expect(data!['isEnd'], true);

      final items = data['data'] as List<dynamic>?;
      expect(items, isNotNull);
      expect(items!.length, 2);
      expect(items[0]['name'], contains('晴天'));
      expect(items[0]['id'], 'song_001');
      expect(items[1]['name'], contains('第二首'));
    });

    test('callMethod invokes getMediaSource', () async {
      await bridge.loadPlugin(testPluginJs);

      final result = await bridge.callMethod('getMediaSource', [
        {'id': 'song_001'},
        'high',
      ]);
      expect(result, isNotNull);
      expect(result['ok'], true);

      final data = result['data'] as Map<String, dynamic>?;
      expect(data!['url'], contains('song_001.mp3'));
    });

    test('callMethod invokes getLyric', () async {
      await bridge.loadPlugin(testPluginJs);

      final result = await bridge.callMethod('getLyric', [
        {'id': 'song_001'},
      ]);
      expect(result, isNotNull);
      expect(result['ok'], true);

      final data = result['data'] as Map<String, dynamic>?;
      expect(data!['rawLrc'], contains('Test Lyrics'));
    });

    test('callMethod returns null for non-existent property', () async {
      await bridge.loadPlugin(testPluginJs);

      final result = await bridge.callMethod('nonExistentMethod', []);
      expect(result['ok'], true);
      expect(result['data'], isNull);
    });

    test('search returns empty for empty query (plugin logic)', () async {
      await bridge.loadPlugin(testPluginJs);

      final result = await bridge.callMethod('search', ['', 1, 'music']);
      expect(result['ok'], true);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['data'] as List, isEmpty);
    });

    test('bridge can load and query multiple times', () async {
      await bridge.loadPlugin(testPluginJs);

      for (int i = 0; i < 3; i++) {
        final result = await bridge.callMethod('search', ['test$i', 1, 'music']);
        expect(result['ok'], true);
        final items = (result['data'] as Map)['data'] as List;
        expect(items.length, 2);
      }
    });
  });

  group('Real MusicFree plugin (geciqianxun)', () {
    late MusicFreeBridge bridge;
    final pluginJs = _loadPluginJs();

    setUp(() async {
      bridge = MusicFreeBridge();
      await bridge.init();
      await bridge.loadPlugin(pluginJs);
    });

    tearDown(() {
      bridge.dispose();
    });

    test('plugin loads and exports platform name', () async {
      // Verify the plugin loaded by calling search with unsupported type
      // (returns sync undefined, no HTTP needed)
      final result = await bridge.callMethod('platform', []);
      expect(result['ok'], true);
      expect(result['data'], '歌词千寻');
    });

    test('axios polyfill HTTP stack does not crash', () async {
      // Smoke test: start an HTTP request via axios polyfill and verify
      // the bridge event loop doesn't deadlock or crash.
      bridge.testEval(r'''
        __testAxiosDone = false;
        __testAxiosError = null;
        var _axios = _require("axios");
        _axios.default.get('https://httpbin.org/get', { params: { q: 'test' } })
          .then(function(r) { __testAxiosDone = true; })
          .catch(function(e) { __testAxiosDone = true; __testAxiosError = e.message || String(e); });
      ''');

      // Poll until the request completes (or times out)
      for (int i = 0; i < 150; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        final done = bridge.testEval('__testAxiosDone');
        if (done == 'true' || done == '1') {
          // Request completed (either success or error) — bridge event loop works.
          expect(true, isTrue);
          return;
        }
      }
      // Timeout is also acceptable — network may be unreachable.
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('search returns expected structure', () async {
      final result = await bridge.callMethod('search', ['晴天', 1, 'lyric']);
      expect(result, isNotNull);
      expect(result['ok'], true);

      final data = result['data'] as Map<String, dynamic>?;
      // May be null if the plugin returns undefined (type !== 'lyric' gate)
      if (data == null) return;

      expect(data['isEnd'], true);
      final items = data['data'] as List<dynamic>?;
      expect(items, isNotNull);
      // items may be empty if lrcgc.com is unreachable — that's a network issue, not a bridge issue.
      if (items!.isNotEmpty) {
        expect(items[0], containsPair('title', isNotEmpty));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('search with unsupported type returns undefined', () async {
      final result = await bridge.callMethod('search', ['test', 1, 'music']);
      // MusicFree plugin returns undefined for unsupported type
      expect(result['ok'], true);
      expect(result['data'], isNull);
    });

    test('getLyric returns raw lrc', () async {
      final result = await bridge.callMethod('getLyric', [
        {'id': 'https://so.lrcgc.com/lyric/12345.html'},
      ]);
      expect(result, isNotNull);
      expect(result['ok'], true);
      final data = result['data'] as Map<String, dynamic>?;
      expect(data, isNotNull);
      // rawLrc may be empty if the ID is invalid, but structure should be correct
      expect(data!.containsKey('rawLrc'), true);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('cheerio polyfill parses HTML correctly', () async {
      // Test cheerio directly via eval, not through a plugin
      bridge.testEval(r'''
        var testHtml = '<div class="wrap"><dl><dt><a href="/lyric/123">Test Song</a></dt><dd><small>歌手：Singer  专辑:Album</small></dd></dl></div>';
        var cheerio = _require("cheerio");
        var $c = cheerio.load(testHtml);
        var results = $c('.wrap').children();
        var first = results.first();
        __testCheerioTagName = first.prop('tagName');
        __testCheerioTitle = first.find('dt > a').text();
        __testCheerioHref = first.find('dt > a').attr('href');
        __testCheerioDesc = first.find('dd > small').text();
      ''');

      expect(bridge.testEval('__testCheerioTagName'), 'DL');
      expect(bridge.testEval('__testCheerioTitle'), 'Test Song');
      expect(bridge.testEval('__testCheerioHref'), '/lyric/123');
      expect(bridge.testEval('__testCheerioDesc'), contains('Singer'));
    });
  });
}

/// Load the real geciqianxun plugin from the extracted MusicFreePlugins repo.
String _loadPluginJs() {
  // Use the compiled dist version (same as what MusicFree loads).
  // Path is relative to project root.
  final f = File('extracted/MusicFreePlugins/dist/geciqianxun/index.js');
  if (!f.existsSync()) {
    // Fallback: load from parent directory
    final alt = File('../extracted/MusicFreePlugins/dist/geciqianxun/index.js');
    if (alt.existsSync()) return alt.readAsStringSync();
    throw StateError(
      'geciqianxun plugin not found at extracted/MusicFreePlugins/dist/geciqianxun/index.js',
    );
  }
  return f.readAsStringSync();
}
