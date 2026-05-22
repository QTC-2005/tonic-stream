import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

/// Axios polyfill built on XMLHttpRequest (provided by flutter_js QuickJS runtime).
/// Supports: axios(config), axios.get(url, config), axios.post(url, data, config),
///           params serialization, headers, timeout, responseType.
const _axiosPolyfillJs = r'''
(function() {
  function axiosCreate(defaults) {
    defaults = defaults || {};

    function axios(url, cfg) {
      if (typeof url === 'string') {
        cfg = cfg || {};
        cfg.url = url;
        return axios.request(cfg);
      }
      return axios.request(url || {});
    }

    axios.get = function(url, cfg) {
      cfg = cfg || {};
      cfg.method = 'get';
      cfg.url = url;
      return axios.request(cfg);
    };

    axios.post = function(url, data, cfg) {
      cfg = cfg || {};
      cfg.method = 'post';
      cfg.url = url;
      cfg.data = data;
      return axios.request(cfg);
    };

    axios.request = function(cfg) {
      cfg = Object.assign({}, defaults, cfg);
      return new Promise(function(resolve, reject) {
        var xhr = new XMLHttpRequest();
        var method = (cfg.method || 'GET').toUpperCase();
        var url = cfg.url || '';

        if (cfg.params) {
          var parts = [];
          Object.keys(cfg.params).forEach(function(k) {
            var v = cfg.params[k];
            if (v !== null && v !== undefined) {
              parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(v));
            }
          });
          if (parts.length > 0) {
            url += (url.indexOf('?') >= 0 ? '&' : '?') + parts.join('&');
          }
        }

        xhr.open(method, url);

        if (cfg.headers) {
          Object.keys(cfg.headers).forEach(function(k) {
            xhr.setRequestHeader(k, cfg.headers[k]);
          });
        }

        if (cfg.responseType) {
          xhr.responseType = cfg.responseType;
        }

        if (cfg.timeout) {
          xhr.timeout = cfg.timeout;
        }

        xhr.onload = function() {
          var resp = {
            data: xhr.response,
            status: xhr.status,
            statusText: xhr.statusText,
            headers: {},
            config: cfg
          };
          resolve(resp);
        };

        xhr.onerror = function() {
          reject(new Error('Network Error'));
        };

        xhr.ontimeout = function() {
          reject(new Error('Timeout of ' + cfg.timeout + 'ms exceeded'));
        };

        xhr.send(cfg.data || null);
      });
    };

    axios.defaults = defaults;
    return axios;
  }

  var instance = axiosCreate({});
  instance.create = axiosCreate;
  instance.default = instance;
  __packages['axios'] = { default: instance };
})();
''';

/// Minimal cheerio polyfill for MusicFree plugin compatibility.
///
/// Implements the subset of cheerio/jQuery used by common MusicFree plugins:
///   load(html) → $(selector) → children(), first(), find(sel), text(), attr(), prop()
///
/// CSS selector support: tag, .class, #id, parent child, parent > child.
const _cheerioPolyfillJs = r'''
(function() {
  var VOID_ELEMENTS = {
    br:1, hr:1, img:1, input:1, meta:1, link:1, area:1, base:1, col:1,
    embed:1, source:1, track:1, wbr:1, param:1
  };

  var HTML_ENTITIES = {
    '&lt;': '<', '&gt;': '>', '&amp;': '&', '&quot;': '"',
    '&#x27;': "'", '&apos;': "'", '&nbsp;': ' '
  };

  function decodeEntities(str) {
    return str.replace(/&[#\w]+;/g, function(m) { return HTML_ENTITIES[m] || m; });
  }

  function parseHTML(html) {
    var doc = { type: 'root', children: [] };
    var stack = [doc];
    var i = 0;
    var len = html.length;

    while (i < len) {
      if (html[i] === '<') {
        if (i + 1 < len && html[i + 1] === '/') {
          var end = html.indexOf('>', i);
          if (end < 0) break;
          if (stack.length > 1) stack.pop();
          i = end + 1;
        } else if (i + 1 < len && (html[i + 1] === '!' || html[i + 1] === '?')) {
          var end = html.indexOf('>', i);
          if (end < 0) break;
          i = end + 1;
        } else {
          var end = html.indexOf('>', i);
          if (end < 0) break;
          var raw = html.substring(i + 1, end);
          i = end + 1;

          var selfClose = raw.endsWith('/');
          if (selfClose) raw = raw.substring(0, raw.length - 1);

          var spaceIdx = raw.search(/\s/);
          var tagName, rest;
          if (spaceIdx < 0) {
            tagName = raw.toLowerCase();
            rest = '';
          } else {
            tagName = raw.substring(0, spaceIdx).toLowerCase();
            rest = raw.substring(spaceIdx);
          }

          var attrs = {};
          var attrRe = /([\w-]+)\s*=\s*("[^"]*"|'[^']*'|\S+)/g;
          var m;
          while ((m = attrRe.exec(rest)) !== null) {
            var k = m[1];
            var v = m[2];
            if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
              v = v.substring(1, v.length - 1);
            }
            attrs[k] = decodeEntities(v);
          }

          var node = { type: 'tag', tagName: tagName, attrs: attrs, children: [], parent: stack[stack.length - 1] };
          stack[stack.length - 1].children.push(node);

          if (!selfClose && !VOID_ELEMENTS[tagName]) {
            stack.push(node);
          }
        }
      } else {
        var next = html.indexOf('<', i);
        if (next < 0) next = len;
        var text = decodeEntities(html.substring(i, next));
        i = next;
        if (text.trim()) {
          stack[stack.length - 1].children.push({
            type: 'text', text: text, parent: stack[stack.length - 1]
          });
        }
      }
    }
    return doc;
  }

  function matchSelector(node, sel) {
    var parts = sel.match(/([.#]?[\w-]+)/g);
    if (!parts) return false;
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p.startsWith('.')) {
        var cls = (node.attrs['class'] || '');
        var classes = cls.split(/\s+/);
        if (classes.indexOf(p.substring(1)) < 0) return false;
      } else if (p.startsWith('#')) {
        if (node.attrs['id'] !== p.substring(1)) return false;
      } else {
        if (node.tagName !== p.toLowerCase()) return false;
      }
    }
    return true;
  }

  function findAll(root, sel) {
    var out = [];
    function walk(n) {
      if (n.type === 'tag' && matchSelector(n, sel)) out.push(n);
      if (n.children) n.children.forEach(walk);
    }
    walk(root);
    return out;
  }

  function queryAll(root, fullSel) {
    var parts = fullSel.split(/\s*>\s*/);
    var directOnly = parts.length > 1;
    if (!directOnly) {
      parts = fullSel.split(/\s+/);
    }

    if (parts.length === 2) {
      var parents = findAll(root, parts[0]);
      var out = [];
      parents.forEach(function(p) {
        if (p.children) p.children.forEach(function(c) {
          if (c.type === 'tag' && matchSelector(c, parts[1])) out.push(c);
        });
      });
      return out;
    }

    if (parts.length === 1) {
      return findAll(root, parts[0]);
    }

    // Multi-level: iterative
    var current = findAll(root, parts[0]);
    for (var level = 1; level < parts.length; level++) {
      var next = [];
      current.forEach(function(p) {
        if (p.children) p.children.forEach(function(c) {
          if (c.type === 'tag' && matchSelector(c, parts[level])) next.push(c);
        });
      });
      current = next;
    }
    return current;
  }

  function Cheerio(nodes) {
    this.nodes = nodes || [];
    this.length = this.nodes.length;
  }

  Cheerio.prototype.children = function() {
    var kids = [];
    this.nodes.forEach(function(n) {
      if (n.children) n.children.forEach(function(c) {
        if (c.type === 'tag') kids.push(c);
      });
    });
    return new Cheerio(kids);
  };

  Cheerio.prototype.first = function() {
    return new Cheerio(this.nodes.length > 0 ? [this.nodes[0]] : []);
  };

  Cheerio.prototype.find = function(sel) {
    var out = [];
    this.nodes.forEach(function(n) { out = out.concat(queryAll(n, sel)); });
    return new Cheerio(out);
  };

  Cheerio.prototype.text = function() {
    var parts = [];
    function collect(n) {
      if (n.type === 'text') parts.push(n.text);
      if (n.children) n.children.forEach(collect);
    }
    this.nodes.forEach(collect);
    return parts.join('');
  };

  Cheerio.prototype.attr = function(name) {
    if (this.nodes.length === 0) return undefined;
    return this.nodes[0].attrs[name];
  };

  Cheerio.prototype.prop = function(name) {
    if (this.nodes.length === 0) return undefined;
    if (name === 'tagName') return this.nodes[0].tagName.toUpperCase();
    return this.nodes[0].attrs[name];
  };

  var cheerio = {
    load: function(html) {
      var doc = parseHTML(html);
      return function(sel) {
        return new Cheerio(queryAll(doc, sel));
      };
    }
  };

  __packages['cheerio'] = cheerio;
})();
''';

/// Stub packages that MusicFree plugins may require but are rarely used
/// in the core search/getMediaSource/getLyric paths.
const _stubPackagesJs = r'''
(function() {
  __packages['dayjs'] = (function() {
    function dayjs(date) { return new Date(date); }
    dayjs.extend = function() { return dayjs; };
    return dayjs;
  })();

  __packages['qs'] = {
    stringify: function(obj) {
      return Object.keys(obj).map(function(k) {
        return encodeURIComponent(k) + '=' + encodeURIComponent(obj[k]);
      }).join('&');
    },
    parse: function(str) {
      var out = {};
      if (!str) return out;
      str.split('&').forEach(function(pair) {
        var parts = pair.split('=');
        out[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1] || '');
      });
      return out;
    }
  };

  __packages['he'] = {
    decode: function(str) {
      return str.replace(/&#(\d+);/g, function(m, d) { return String.fromCharCode(d); })
                .replace(/&#x([0-9a-f]+);/gi, function(m, d) { return String.fromCharCode(parseInt(d, 16)); })
                .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
                .replace(/&quot;/g, '"').replace(/&#x27;/g, "'").replace(/&nbsp;/g, ' ');
    },
    encode: function(str) {
      return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;').replace(/'/g, '&#x27;');
    }
  };

  __packages['crypto-js'] = {
    MD5: function(str) {
      // Simple hash fallback — real crypto-js not needed for search
      return str;
    },
    enc: { Hex: { stringify: function(h) { return h; } } }
  };

  __packages['big-integer'] = function(v) {
    return { toString: function() { return String(v); }, valueOf: function() { return Number(v); } };
  };

  __packages['webdav'] = { createClient: function() { return {}; } };
})();
''';

/// QuickJS runtime wrapper with MusicFree CommonJS compatibility.
///
/// Provides `require()`, `module.exports`, axios polyfill, cheerio polyfill,
/// and stub packages matching the MusicFree plugin dependency injection spec.
///
/// Async plugin methods (using `await axios.get()`) are supported:
/// flutter_js XHR extension + handlePromises + event-loop polling.
class MusicFreeBridge {
  late final JavascriptRuntime _runtime;
  bool _initialized = false;

  /// Max polling iterations for async method resolution (~10 seconds at 20ms).
  static const int _maxPollIterations = 500;

  /// Delay between async poll checks.
  static const Duration _pollDelay = Duration(milliseconds: 20);

  Future<void> init() async {
    _runtime = getJavascriptRuntime(xhr: true);

    // Inject require registry and CommonJS globals
    _runtime.evaluate('''
      var __packages = {};
      var __pluginResult = null;
      var __callResult = null;

      function _require(name) {
        if (__packages.hasOwnProperty(name)) return __packages[name];
        throw new Error('Package not found: ' + name);
      }

      // env / process stubs (not provided by runtime)
      var _env = {
        getUserVariables: function() { return {}; },
        os: 'win32',
        appVersion: '0.1.0',
        lang: 'zh-CN'
      };
      var _process = { platform: 'win32', version: '0.1.0', env: _env };
    ''');

    _drainMicrotasks();

    // Inject polyfill packages
    _runtime.evaluate(_axiosPolyfillJs);
    _runtime.evaluate(_cheerioPolyfillJs);
    _runtime.evaluate(_stubPackagesJs);
    _drainMicrotasks();

    _initialized = true;
  }

  /// Load a MusicFree plugin from JS source.
  ///
  /// Wraps the plugin code in a CommonJS IIFE so that `module.exports`
  /// is captured into `__pluginResult`.
  Future<void> loadPlugin(String jsCode) async {
    _checkInit();

    // Note: Real MusicFree plugins use `require("axios")` — the first IIFE parameter
    // must be named `require`. `module` is accessible via closure from the outer scope.
    final wrapped = '''
      (function() {
        var module = { exports: {} };
        var exports = module.exports;

        (function(require, _module, _exports, console, env, process) {
          $jsCode
        })(_require, module, exports, console, _env, _process);

        __pluginResult = module.exports.default || module.exports;
      })();
    ''';

    _runtime.evaluate(wrapped);
    _drainMicrotasks();
  }

  /// Call a method on the loaded plugin.
  ///
  /// Supports both sync and async plugin functions. For async functions
  /// (returning a JS Promise), polls the QuickJS event loop until the
  /// Promise resolves and the result is captured via `.then()`.
  Future<dynamic> callMethod(
    String method,
    List<dynamic> args,
  ) async {
    _checkInit();

    final argsJson = _safeJsonEncode(args);
    // Reset result holder before call
    _runtime.evaluate('__callResult = null');
    _drainMicrotasks();

    final code = '''
      try {
        var target = __pluginResult['$method'];
        if (typeof target !== 'function') {
          // Property access — return value directly (undefined → null)
          __callResult = JSON.stringify({ ok: true, data: target !== undefined ? target : null });
        } else {
          var parsedArgs = JSON.parse('$argsJson');
          var result = target.apply(__pluginResult, parsedArgs);

          if (result && typeof result.then === 'function') {
            // Async function — chain .then() to capture resolved value
            result.then(function(v) {
              __callResult = JSON.stringify({ ok: true, data: v });
            }).catch(function(e) {
              __callResult = JSON.stringify({ ok: false, error: e.message || String(e) });
            });
          } else {
            // Sync function — capture immediately (undefined → null)
            __callResult = JSON.stringify({ ok: true, data: result !== undefined ? result : null });
          }
        }
      } catch(e) {
        __callResult = JSON.stringify({ ok: false, error: e.message || String(e) });
      }
    ''';

    _runtime.evaluate(code);
    _drainMicrotasks();

    // Poll for async completion (harmless no-op if already sync-resolved)
    for (int i = 0; i < _maxPollIterations; i++) {
      _drainMicrotasks();
      final rawResult = _runtime.evaluate('__callResult');
      final raw = rawResult.stringResult;
      if (raw.isNotEmpty && raw != 'null' && raw != 'undefined') {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return null;
        }
      }
      await Future.delayed(_pollDelay);
    }

    return {'ok': false, 'error': 'timeout after ${_maxPollIterations * _pollDelay.inMilliseconds}ms'};
  }

  /// Evaluate JS code and return the result as a string.
  /// Exposed for testing — not part of the normal plugin API.
  String testEval(String code) {
    _checkInit();
    final result = _runtime.evaluate(code);
    _drainMicrotasks();
    return result.stringResult;
  }

  void dispose() {
    _runtime.dispose();
    _initialized = false;
  }

  void _checkInit() {
    if (!_initialized) throw StateError('call init() first');
  }

  void _drainMicrotasks() {
    for (int i = 0; i < 100; i++) {
      if (_runtime.executePendingJob() <= 0) break;
    }
  }

  /// JSON-encode args, escaping single-quotes for JS string embedding.
  String _safeJsonEncode(List<dynamic> args) {
    return jsonEncode(args).replaceAll("'", "\\'");
  }
}
