import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const SelfBrowserApp());

class SelfBrowserApp extends StatelessWidget {
  const SelfBrowserApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Self Browser',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6484FF), brightness: Brightness.dark), useMaterial3: true),
    home: const BrowserPage(),
  );
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final _address = TextEditingController(text: 'https://duckduckgo.com');
  WebViewController? _web;
  bool _loading = true, _adBlock = true, _private = false;
  String _url = 'https://duckduckgo.com', _status = 'Ready';
  List<String> _bookmarks = [];
  final List<String> _blocked = ['doubleclick.net','googlesyndication.com','googletagmanager.com','google-analytics.com','adservice.google.com','adnxs.com','taboola.com','outbrain.com'];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => setState(() { _loading = true; _url = url; _address.text = url; }),
        onPageFinished: (url) => setState(() { _loading = false; _url = url; _address.text = url; _status = 'Loaded'; }),
        onNavigationRequest: (request) {
          if (_adBlock && _isBlocked(request.url)) return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
        onWebResourceError: (e) => setState(() { _loading = false; _status = 'Page error'; }),
      ))
      ..loadRequest(Uri.parse(_url));
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { _bookmarks = p.getStringList('bookmarks') ?? []; _adBlock = p.getBool('adblock') ?? true; });
  }

  bool _isBlocked(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return _blocked.any((h) => host == h || host.endsWith('.$h'));
  }

  String _normalize(String value) {
    final s = value.trim();
    if (s.isEmpty) return 'https://duckduckgo.com';
    final u = Uri.tryParse(s);
    if (u != null && (u.scheme == 'https' || u.scheme == 'http')) return s;
    if (s.contains(' ') || !s.contains('.')) return 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(s)}';
    return 'https://$s';
  }

  Future<void> _go([String? value]) async {
    final url = _normalize(value ?? _address.text);
    if (_adBlock && _isBlocked(url)) {
      setState(() { _status = 'Blocked by Self Browser'; _loading = false; });
      return;
    }
    setState(() { _loading = true; _status = 'Loading'; _url = url; _address.text = url; });
    try { await _web?.loadRequest(Uri.parse(url)); }
    catch (_) { setState(() { _loading = false; _status = 'Could not load page'; }); }
  }

  Future<void> _toggleBookmark() async {
    final p = await SharedPreferences.getInstance();
    setState(() { _bookmarks.contains(_url) ? _bookmarks.remove(_url) : _bookmarks.add(_url); });
    await p.setStringList('bookmarks', _bookmarks);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_bookmarks.contains(_url) ? 'Bookmark saved' : 'Bookmark removed')));
  }

  Future<void> _showBookmarks() async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: SizedBox(height: 420, child: Column(children: [
      const ListTile(title: Text('Bookmarks')),
      Expanded(child: _bookmarks.isEmpty ? const Center(child: Text('No bookmarks yet')) : ListView.builder(
        itemCount: _bookmarks.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: Text(_bookmarks[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () { Navigator.pop(ctx); _go(_bookmarks[i]); },
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
            final p = await SharedPreferences.getInstance();
            setState(() => _bookmarks.removeAt(i));
            await p.setStringList('bookmarks', _bookmarks);
            if (ctx.mounted) Navigator.pop(ctx);
            _showBookmarks();
          }),
        ),
      )),
    ]))));
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Privacy settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SwitchListTile(title: const Text('Basic ad/tracker blocking'), subtitle: const Text('Small host list, not a full ad blocker.'), value: _adBlock, onChanged: (v) async { setState(() => _adBlock = v); setSheet(() {}); final p = await SharedPreferences.getInstance(); await p.setBool('adblock', v); }),
        SwitchListTile(title: const Text('Private session indicator'), subtitle: const Text('This does not isolate cookies or guarantee incognito mode.'), value: _private, onChanged: (v) { setState(() => _private = v); setSheet(() {}); }),
        ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('Clear cache and bookmarks'), onTap: () async {
          final p = await SharedPreferences.getInstance();
          await p.remove('bookmarks');
          await _web?.clearCache();
          await _web?.clearLocalStorage();
          setState(() => _bookmarks.clear());
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache, local storage and bookmarks cleared')));
        }),
        const Padding(padding: EdgeInsets.all(8), child: Text('This app does not include a VPN. Websites and your network provider can still see connection metadata.', style: TextStyle(color: Colors.white70))),
      ]),
    ))));
  }

  Future<void> _ai() async {
    final c = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Self AI'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This starter searches the web for your question. No AI service is connected and page content is not sent automatically.'),
        const SizedBox(height: 12),
        TextField(controller: c, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Ask a question')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { final q = c.text.trim(); Navigator.pop(ctx); if (q.isNotEmpty) _go('https://duckduckgo.com/?q=${Uri.encodeQueryComponent(q)}'); }, child: const Text('Search')),
      ],
    ));
  }

  Future<void> _clearData() async {
    await _web?.clearCache();
    await _web?.clearLocalStorage();
  }

  @override
  void dispose() { _address.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(children: [Icon(Icons.shield_moon_outlined), SizedBox(width: 8), Text('Self Browser', style: TextStyle(fontWeight: FontWeight.bold))]),
      actions: [
        IconButton(tooltip: 'Bookmarks', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
        IconButton(tooltip: 'Privacy settings', onPressed: _settings, icon: const Icon(Icons.tune)),
        IconButton(tooltip: 'Self AI', onPressed: _ai, icon: const Icon(Icons.auto_awesome)),
      ],
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), child: Row(children: [
        Expanded(child: TextField(controller: _address, keyboardType: TextInputType.url, textInputAction: TextInputAction.go, onSubmitted: _go, decoration: InputDecoration(
          hintText: 'Search or enter website', prefixIcon: const Icon(Icons.search), filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest, contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ))),
        IconButton(onPressed: () => _go(_address.text), icon: const Icon(Icons.arrow_forward_rounded)),
        IconButton(onPressed: _toggleBookmark, icon: Icon(_bookmarks.contains(_url) ? Icons.bookmark : Icons.bookmark_border)),
      ])),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: _web == null ? const Center(child: CircularProgressIndicator()) : WebViewWidget(controller: _web!)),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), color: Theme.of(context).colorScheme.surfaceContainer, child: Row(children: [
        Icon(_private ? Icons.visibility_off : Icons.shield_outlined, size: 14), const SizedBox(width: 6),
        Expanded(child: Text('${_private ? "Private indicator (not fully isolated)" : "Protected browsing"} • $_status', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
      ])),
    ]),
    bottomNavigationBar: SafeArea(top: false, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      IconButton(tooltip: 'Back', onPressed: () async { if (await _web?.canGoBack() ?? false) _web?.goBack(); }, icon: const Icon(Icons.arrow_back)),
      IconButton(tooltip: 'Forward', onPressed: () async { if (await _web?.canGoForward() ?? false) _web?.goForward(); }, icon: const Icon(Icons.arrow_forward)),
      IconButton(tooltip: 'Home', onPressed: () => _go('https://duckduckgo.com'), icon: const Icon(Icons.home_outlined)),
      IconButton(tooltip: 'Reload', onPressed: () => _web?.reload(), icon: const Icon(Icons.refresh)),
    ])),
  );
}
