import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const OctaAiApp());

class OctaAiApp extends StatelessWidget {
  const OctaAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OctaAi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const BrowserPage(),
    );
  }
}

/// Domains whose requests are blocked (ads + trackers). Extend freely.
const List<String> _blockedDomains = [
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

List<ContentBlocker> _buildBlockers() => _blockedDomains
    .map((d) => ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*${_escapeRegex(d)}.*'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ))
    .toList();

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static const String _home = 'https://duckduckgo.com/';

  InAppWebViewController? _controller;
  final TextEditingController _addressCtrl = TextEditingController();
  double _progress = 0;
  bool _canBack = false;
  bool _canForward = false;

  late final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    thirdPartyCookiesEnabled: false,
    useWideViewPort: true,
    supportZoom: true,
    builtInZoomControls: true,
    displayZoomControls: false,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    contentBlockers: _buildBlockers(),
  );

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _go(String input) {
    input = input.trim();
    if (input.isEmpty) return;
    String url;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      url = input;
    } else if (!input.contains(' ') &&
        input.contains('.') &&
        !input.endsWith('.')) {
      url = 'https://$input';
    } else {
      url = 'https://duckduckgo.com/?q=${Uri.encodeComponent(input)}';
    }
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _refreshNavState() async {
    final c = _controller;
    if (c == null) return;
    final back = await c.canGoBack();
    final fwd = await c.canGoForward();
    if (mounted) setState(() {
      _canBack = back;
      _canForward = fwd;
    });
  }

  Future<void> _showSummary() async {
    final c = _controller;
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
          .replaceAll(RegExp('[^a-z0-9\u0600-\u06FF ]'), '')
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
          .replaceAll(RegExp('[^a-z0-9\u0600-\u06FF ]'), '')
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_canBack) {
          _controller?.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: TextField(
            controller: _addressCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: _go,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search or type address',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _addressCtrl.clear(),
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        body: Column(
          children: [
            if (_progress < 1)
              LinearProgressIndicator(value: _progress, minHeight: 2),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_home)),
                initialSettings: _settings,
                onWebViewCreated: (c) {
                  _controller = c;
                  _refreshNavState();
                },
                onLoadStart: (c, url) {
                  if (mounted) setState(() => _progress = 0);
                },
                onLoadStop: (c, url) async {
                  if (url != null) _addressCtrl.text = url.toString();
                  if (mounted) setState(() => _progress = 1);
                  await _refreshNavState();
                },
                onUpdateVisitedHistory: (c, url, _) {
                  if (url != null) _addressCtrl.text = url.toString();
                },
                onProgressChanged: (c, p) {
                  if (mounted) setState(() => _progress = p / 100);
                },
                onReceivedError: (c, request, error) {
                  if (request.isForMainFrame ?? false) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Could not load page: ${error.description}')));
                  }
                },
                onDownloadStartRequest: (c, request) async {
                  final uri = Uri.parse(request.url.toString());
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Opening file with an external app…')));
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.arrow_back), label: 'Back'),
            NavigationDestination(
                icon: Icon(Icons.arrow_forward), label: 'Forward'),
            NavigationDestination(icon: Icon(Icons.refresh), label: 'Reload'),
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome), label: 'Summary'),
          ],
          selectedIndex: 2,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                if (_canBack) _controller?.goBack();
                break;
              case 1:
                if (_canForward) _controller?.goForward();
                break;
              case 2:
                _controller?.reload();
                break;
              case 3:
                _go(_home);
                break;
              case 4:
                _showSummary();
                break;
            }
          },
        ),
      ),
    );
  }
}
