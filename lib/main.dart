import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: false, ignoreSsl: true);
  try {
    // Ask Android for the panel's highest refresh rate (e.g. 120/144Hz).
    // Falls back silently on 60Hz devices.
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {}
  runApp(const OctaAiApp());
}

class OctaAiApp extends StatefulWidget {
  const OctaAiApp({super.key});

  @override
  State<OctaAiApp> createState() => _OctaAiAppState();
}

class _OctaAiAppState extends State<OctaAiApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OctaAi',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: BrowserPage(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// Domains whose requests are blocked (ads + trackers). Extend freely.
const List<String> kBlockedDomains = [
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'adservice.google.com',
  'ads.yahoo.com',
  'adnxs.com',
  'advertising.com',
  'taboola.com',
  'outbrain.com',
  'criteo.com',
  'criteo.net',
  'moatads.com',
  'amazon-adsystem.com',
  'adsrvr.org',
  'adform.net',
  'rubiconproject.com',
  'pubmatic.com',
  'openx.net',
  'smartadserver.com',
  'quantserve.com',
  'scorecardresearch.com',
  'admob.com',
  'inmobi.com',
  'applovin.com',
  'vungle.com',
  'ironsrc.com',
  'bidswitch.net',
  'sharethrough.com',
  'teads.tv',
  'yieldmo.com',
  'adjust.com',
  'appsflyer.com',
];

String _escapeRegex(String s) => s.replaceAll('.', r'\.');

List<ContentBlocker> buildBlockers() => kBlockedDomains
    .map((d) => ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*${_escapeRegex(d)}.*'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ))
    .toList();

class BrowserTab {
  BrowserTab(this.url);
  InAppWebViewController? controller;
  String url;
  String title = 'New tab';
  int blocked = 0;
  double progress = 0;
  bool canBack = false;
  bool canForward = false;
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.isDark, required this.onToggleTheme});
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static const String _home = 'https://wsalahe.github.io/octaai-search/';
  static const int _maxTabs = 12;

  final List<BrowserTab> _tabs = [BrowserTab(_home)];
  int _current = 0;
  final TextEditingController _addressCtrl = TextEditingController();
  bool _barsVisible = true;
  int _lastScrollY = 0;
  List<Map<String, String>> _videos = [];
  Timer? _videoTimer;
  bool _videoBusy = false;

  List<Map<String, String>> _bookmarks = [];
  List<Map<String, String>> _history = [];

  BrowserTab get _tab => _tabs[_current];

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    thirdPartyCookiesEnabled: false,
    useWideViewPort: true,
    supportZoom: true,
    builtInZoomControls: true,
    displayZoomControls: false,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    contentBlockers: buildBlockers(),
  );

  @override
  void initState() {
    super.initState();
    _loadStores();
    _videoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _scanVideos();
    });
  }

  Future<void> _loadStores() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final b = jsonDecode(prefs.getString('bookmarks') ?? '[]') as List;
      final h = jsonDecode(prefs.getString('history') ?? '[]') as List;
      setState(() {
        _bookmarks = b.map((e) => Map<String, String>.from(e as Map)).toList();
        _history = h.map((e) => Map<String, String>.from(e as Map)).toList();
      });
    } catch (_) {}
  }

  Future<void> _saveStores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmarks', jsonEncode(_bookmarks));
    await prefs.setString('history', jsonEncode(_history));
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _videoTimer?.cancel();
    super.dispose();
  }

  // ---------- navigation ----------

  void _go(String input, [BrowserTab? tab]) {
    input = input.trim();
    if (input.isEmpty) return;
    final t = tab ?? _tab;
    String url;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      url = input;
    } else if (!input.contains(' ') &&
        input.contains('.') &&
        !input.endsWith('.')) {
      url = 'https://$input';
    } else {
      url = 'https://wsalahe.github.io/octaai-search/?q=${Uri.encodeComponent(input)}';
    }
    t.url = url;
    t.controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addTab([String url = _home]) {
    if (_tabs.length >= _maxTabs) {
      _toast('Tab limit reached');
      return;
    }
    setState(() {
      _tabs.add(BrowserTab(url));
      _current = _tabs.length - 1;
      _addressCtrl.text = '';
    });
  }

  void _closeTab(int i) {
    if (_tabs.length == 1) {
      setState(() {
        _tabs[0] = BrowserTab(_home);
        _current = 0;
        _addressCtrl.clear();
      });
      return;
    }
    setState(() {
      _tabs.removeAt(i);
      if (_current >= _tabs.length) _current = _tabs.length - 1;
      if (i < _current) _current--;
      _addressCtrl.text = _tab.url;
    });
  }

  void _switchTab(int i) {
    setState(() {
      _current = i;
      _addressCtrl.text = _tab.url;
    });
  }

  Future<void> _refreshNav(BrowserTab t) async {
    final c = t.controller;
    if (c == null) return;
    t.canBack = await c.canGoBack();
    t.canForward = await c.canGoForward();
    if (mounted) setState(() {});
  }

  // ---------- history / bookmarks ----------

  void _recordHistory(BrowserTab t) {
    if (t.url.isEmpty || t.url == 'about:blank') return;
    if (_history.isNotEmpty && _history.first['u'] == t.url) {
      _history.first['t'] = t.title;
    } else {
      _history.insert(0, {'u': t.url, 't': t.title, 'ts': '${DateTime.now()}'});
      if (_history.length > 300) _history.removeLast();
    }
    _saveStores();
  }

  bool get _isBookmarked => _bookmarks.any((b) => b['u'] == _tab.url);

  void _toggleBookmark() {
    if (_isBookmarked) {
      _bookmarks.removeWhere((b) => b['u'] == _tab.url);
      _toast('Bookmark removed');
    } else {
      _bookmarks.insert(0, {'u': _tab.url, 't': _tab.title});
      _toast('Bookmarked');
    }
    setState(() {});
    _saveStores();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ---------- AI summary ----------

  Future<void> _showSummary() async {
    final c = _tab.controller;
    if (c == null) return;
    final raw = await c.evaluateJavascript(
        source: 'document.body ? document.body.innerText : ""');
    final summary = _summarize((raw ?? '').toString());
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text('On-device AI summary',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Made on your phone. Nothing leaves the device.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 16),
            SelectableText(summary),
          ],
        ),
      ),
    );
  }

  /// Extractive summary: scores sentences by word frequency. No network, no API.
  String _summarize(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'No readable text on this page.';
    if (cleaned.length < 400) return cleaned;
    final sentences = cleaned
        .split(RegExp(r'(?<=[.!?؟])\s+'))
        .where((s) => s.split(' ').length >= 6)
        .toList();
    if (sentences.length <= 4) return sentences.join(' ');
    const stop = {
      'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'for',
      'with', 'is', 'are', 'was', 'were', 'it', 'this', 'that', 'as', 'at',
      'by', 'from', 'be', 'has', 'have', 'had', 'not', 'its', 'their', 'they',
      'we', 'you', 'i', 'he', 'she', 'his', 'her', 'them', 'our', 'your',
      'will', 'would', 'can', 'could',
    };
    final freq = <String, int>{};
    for (final s in sentences) {
      for (final w in s
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9؀-ۿ ]'), '')
          .split(' ')) {
        if (w.length > 2 && !stop.contains(w)) {
          freq[w] = (freq[w] ?? 0) + 1;
        }
      }
    }
    double score(String s) {
      var sum = 0.0;
      var n = 0;
      for (final w in s
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9؀-ۿ ]'), '')
          .split(' ')) {
        if (freq.containsKey(w)) {
          sum += freq[w]!;
          n++;
        }
      }
      return n == 0 ? 0 : sum / n;
    }

    final idx = List<int>.generate(sentences.length, (i) => i)
      ..sort((a, b) => score(sentences[b]).compareTo(score(sentences[a])));
    final chosen = idx.take(4).toList()..sort();
    return chosen.map((i) => sentences[i].trim()).join('\n\n');
  }

  // ---------- sheets ----------

  void _showTabs() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tabs.length,
                itemBuilder: (ctx, i) {
                  final t = _tabs[i];
                  return ListTile(
                    selected: i == _current,
                    leading: const Icon(Icons.public),
                    title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(t.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _closeTab(i);
                        Navigator.pop(ctx);
                      },
                    ),
                    onTap: () {
                      _switchTab(i);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New tab'),
              onTap: () {
                _addTab();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showList(String title, List<Map<String, String>> items,
      {required IconData icon, void Function(Map<String, String>)? onDelete}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Nothing here yet'))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final e = items[i];
                        return ListTile(
                          leading: Icon(icon),
                          title: Text(e['t'] ?? e['u'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(e['u'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: onDelete == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    onDelete(e);
                                    setState(() {});
                                    _saveStores();
                                    Navigator.pop(ctx);
                                  },
                                ),
                          onTap: () {
                            _go(e['u'] ?? '');
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }


  // ---------- video download ----------

  Future<void> _scanVideos() async {
    if (_videoBusy) return;
    final c = _tab.controller;
    if (c == null) return;
    _videoBusy = true;
    try {
      final r = await c.evaluateJavascript(source: """
(function(){
  try{
    var out=[];
    document.querySelectorAll('video').forEach(function(v){
      if(v.currentSrc)out.push(v.currentSrc);
      if(v.src)out.push(v.src);
      v.querySelectorAll('source').forEach(function(s){if(s.src)out.push(s.src);});
    });
    try{
      performance.getEntriesByType('resource').forEach(function(e){
        if(/\\.(m3u8|mp4|webm|mov|mkv)(\\?|#|\$)/i.test(e.name))out.push(e.name);
      });
    }catch(e){}
    var seen={},res=[];
    out.forEach(function(u){
      if(!u||u.indexOf('blob:')===0)return;
      if(!seen[u]){seen[u]=1;res.push(u);}
    });
    return JSON.stringify(res.slice(0,20));
  }catch(e){return '[]';}
})();""");
      final list = (jsonDecode((r ?? '[]').toString()) as List).cast<String>();
      final mapped =
          list.map((u) => <String, String>{'url': u, 'kind': _videoKind(u)}).toList();
      final changed = mapped.length != _videos.length ||
          (mapped.isNotEmpty && mapped.first['url'] != (_videos.isNotEmpty ? _videos.first['url'] : ''));
      if (changed && mounted) {
        setState(() => _videos = mapped);
      } else {
        _videos = mapped;
      }
    } catch (_) {
      // page not ready or JS blocked; try again on the next tick
    } finally {
      _videoBusy = false;
    }
  }

  String _videoKind(String u) {
    final l = u.toLowerCase();
    if (l.contains('.m3u8')) return 'hls';
    if (l.contains('.mpd')) return 'dash';
    return 'file';
  }

  void _showVideoSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Download video',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Works for direct video files and many HLS streams. Protected streams (DRM, e.g. Netflix) cannot be saved.'),
              ),
              ..._videos.map((v) {
                final kind = v['kind'] ?? 'file';
                final url = v['url'] ?? '';
                final icon = kind == 'hls'
                    ? Icons.stream
                    : kind == 'dash'
                        ? Icons.dashboard_customize_outlined
                        : Icons.movie;
                final label = kind == 'hls'
                    ? 'Streaming video (HLS)'
                    : kind == 'dash'
                        ? 'Streaming video (DASH)'
                        : 'Video file';
                return ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  subtitle: Text(Uri.tryParse(url)?.host ?? url,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (kind == 'dash') {
                      _toast('DASH streams are not supported yet');
                    } else if (kind == 'hls') {
                      _downloadHls(url);
                    } else {
                      _downloadFile(url);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadFile(String url) async {
    final name = _fileNameFor(url);
    try {
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: '/storage/emulated/0/Download',
        fileName: name,
        showNotification: true,
        openFileFromNotification: true,
      );
      _toast('Downloading $name to Downloads');
    } catch (_) {
      _toast('Could not start the download');
    }
  }

  Future<void> _downloadHls(String masterUrl) async {
    try {
      final body = await _fetchText(masterUrl);
      final lines = body.split('\n').map((e) => e.trim()).toList();
      final variants = <Map<String, String>>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
          final res = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(lines[i]);
          final bw = RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i]);
          final next = i + 1 < lines.length ? lines[i + 1] : '';
          if (next.isNotEmpty && !next.startsWith('#')) {
            variants.add(<String, String>{
              'label': res != null
                  ? res.group(1)!
                  : (bw != null
                      ? '${(int.parse(bw.group(1)!) / 1000000).toStringAsFixed(1)} Mbps'
                      : 'Variant ${variants.length + 1}'),
              'url': _resolveUrl(masterUrl, next),
            });
          }
        }
      }
      if (!mounted) return;
      if (variants.isEmpty) {
        await _saveHls(masterUrl);
        return;
      }
      final choice = await showModalBottomSheet<Map<String, String>>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Choose quality',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...variants.map((v) => ListTile(
                      leading: const Icon(Icons.hd),
                      title: Text(v['label'] ?? ''),
                      onTap: () => Navigator.pop(ctx, v),
                    )),
              ],
            ),
          );
        },
      );
      if (choice != null) {
        await _saveHls(choice['url']!, label: choice['label'] ?? '');
      }
    } catch (_) {
      _toast('Could not read this video stream');
    }
  }

  Future<void> _saveHls(String playlistUrl, {String label = ''}) async {
    _toast(label.isEmpty ? 'Preparing download...' : 'Preparing download ($label)...');
    try {
      final body = await _fetchText(playlistUrl);
      final segs = <String>[];
      for (final raw in body.split('\n')) {
        final l = raw.trim();
        if (l.isEmpty || l.startsWith('#')) continue;
        segs.add(_resolveUrl(playlistUrl, l));
      }
      if (segs.isEmpty) {
        _toast('No downloadable parts found in this stream');
        return;
      }
      if (segs.first.toLowerCase().endsWith('.m4s')) {
        _toast('This stream format (fMP4) is not supported yet');
        return;
      }
      if (segs.length > 600) {
        _toast('Stream is too long to save (${segs.length} parts)');
        return;
      }
      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final out = File('${tmp.path}/octaai-$stamp.ts');
      final sink = out.openWrite();
      final client = HttpClient();
      try {
        for (var i = 0; i < segs.length; i++) {
          final req = await client.getUrl(Uri.parse(segs[i]));
          req.headers.set('User-Agent', kVideoUserAgent);
          final resp = await req.close();
          if (resp.statusCode != 200) {
            throw HttpException('part ${i + 1} failed');
          }
          await resp.forEach(sink.add);
        }
      } finally {
        client.close();
        await sink.close();
      }
      final name = _fileNameFor(playlistUrl, '.ts');
      try {
        await out.copy('/storage/emulated/0/Download/$name');
        _toast('Saved to Downloads/$name');
      } catch (_) {
        final docs = await getApplicationDocumentsDirectory();
        final dest = await out.copy('${docs.path}/$name');
        _toast('Saved in app folder: ${dest.path}');
      }
    } catch (_) {
      _toast('Video download failed');
    }
  }

  static const String kVideoUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  Future<String> _fetchText(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', kVideoUserAgent);
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
      }
      return await resp.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  String _resolveUrl(String base, String rel) {
    if (rel.startsWith('http')) return rel;
    return Uri.parse(base).resolve(rel).toString();
  }

  String _fileNameFor(String url, [String ext = '']) {
    var base = '';
    final segs = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    if (segs.isNotEmpty) base = segs.last.split('?').first;
    if (base.isEmpty || base.length > 60 || !base.contains('.')) {
      base =
          'octaai-video-${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.mp4' : ext}';
    }
    if (ext.isNotEmpty && !base.toLowerCase().endsWith(ext)) {
      base = base.replaceAll(RegExp(r'\.[a-z0-9]+$'), '') + ext;
    }
    return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  // ---------- WebView builder ----------

  Widget _buildWebView(BrowserTab t) {
    return InAppWebView(
      key: ValueKey(t),
      initialUrlRequest: URLRequest(url: WebUri(t.url)),
      initialSettings: _settings,
      onWebViewCreated: (c) {
        t.controller = c;
        _refreshNav(t);
      },
      onLoadStart: (c, url) {
        t.progress = 0;
        t.blocked = 0;
        if (t == _tab && mounted) setState(() {});
      },
      onLoadStop: (c, url) async {
        if (url != null) {
          t.url = url.toString();
          t.title = (await c.getTitle()) ?? t.url;
        }
        t.progress = 1;
        if (t == _tab && mounted) _addressCtrl.text = t.url;
        _recordHistory(t);
        await _refreshNav(t);
        _scanVideos();
      },
      onTitleChanged: (c, title) {
        if (title != null && title.isNotEmpty) t.title = title;
      },
      onUpdateVisitedHistory: (c, url, _) {
        if (url != null) {
          t.url = url.toString();
          if (t == _tab && mounted) _addressCtrl.text = t.url;
        }
      },
      onProgressChanged: (c, p) {
        t.progress = p / 100;
        if (t == _tab && mounted) setState(() {});
      },
      onScrollChanged: (c, x, y) {
        if (t != _tab) return;
        final dy = y - _lastScrollY;
        _lastScrollY = y;
        if (dy > 40 && _barsVisible) {
          setState(() => _barsVisible = false);
        } else if (dy < -40 && !_barsVisible) {
          setState(() => _barsVisible = true);
        }
      },
      onReceivedError: (c, request, error) {
        final main = request.isForMainFrame ?? false;
        final u = request.url.toString();
        if (!main && kBlockedDomains.any((d) => u.contains(d))) {
          t.blocked++;
          if (t == _tab && mounted) setState(() {});
        } else if (main) {
          _toast('Could not load page: ${error.description}');
        }
      },
      onDownloadStartRequest: (c, request) async {
        final uri = Uri.parse(request.url.toString());
        var opened = false;
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (opened) {
          _toast('Opened file with an external app');
        } else {
          await Clipboard.setData(ClipboardData(text: uri.toString()));
          _toast('No app can open this file. Link copied.');
        }
      },
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = _tab;
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (t.canBack) {
          t.controller?.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        floatingActionButton: _videos.isEmpty
            ? null
            : FloatingActionButton.small(
                heroTag: 'videoDownloadFab',
                backgroundColor: cs.primary,
                onPressed: _showVideoSheet,
                child: const Icon(Icons.download, color: Colors.white),
              ),
        body: SafeArea(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _barsVisible ? 64 : 0,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressCtrl,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onSubmitted: _go,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search or type address',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (t.blocked > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 2),
                                        child: Chip(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          avatar: const Icon(Icons.shield, size: 16),
                                          label: Text('${t.blocked}'),
                                        ),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        _isBookmarked ? Icons.star : Icons.star_border,
                                        size: 20,
                                        color: _isBookmarked ? cs.primary : null,
                                      ),
                                      onPressed: _toggleBookmark,
                                    ),
                                  ],
                                ),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: t.progress < 1 ? 1 : 0,
                child: SizedBox(
                  height: 2,
                  child: t.progress < 1
                      ? LinearProgressIndicator(value: t.progress)
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _current,
                  children: _tabs.map(_buildWebView).toList(),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _barsVisible ? 58 : 0,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: t.canBack ? () => t.controller?.goBack() : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: t.canForward ? () => t.controller?.goForward() : null,
                        ),
                        IconButton(
                          icon: Badge(
                            label: Text('${_tabs.length}'),
                            isLabelVisible: _tabs.length > 1,
                            child: const Icon(Icons.tab_outlined),
                          ),
                          onPressed: _showTabs,
                        ),
                        IconButton(
                          icon: const Icon(Icons.home_outlined),
                          onPressed: () => _go(_home),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: _showMenu,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI summary'),
              subtitle: const Text('On-device, nothing uploaded'),
              onTap: () {
                Navigator.pop(ctx);
                _showSummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Bookmarks'),
              onTap: () {
                Navigator.pop(ctx);
                _showList('Bookmarks', _bookmarks,
                    icon: Icons.star_border,
                    onDelete: (e) => _bookmarks.remove(e));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(ctx);
                _showList('History', _history,
                    icon: Icons.history,
                    onDelete: (e) => _history.remove(e));
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload'),
              onTap: () {
                Navigator.pop(ctx);
                _tab.controller?.reload();
              },
            ),
            ListTile(
              leading: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              title: Text(widget.isDark ? 'Light mode' : 'Dark mode'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onToggleTheme();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Ad and tracker blocking'),
              subtitle: Text(
                  '${kBlockedDomains.length} networks blocked. ${_tab.blocked} requests blocked on this page.'),
            ),
          ],
        ),
      ),
    );
  }
}
