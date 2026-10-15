
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const SelfBrowserApp());
}

class SelfBrowserApp extends StatelessWidget {
  const SelfBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Self Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const BrowserHome(),
    );
  }
}

class BrowserHome extends StatefulWidget {
  const BrowserHome({super.key});

  @override
  State<BrowserHome> createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> {
  late final WebViewController controller;
  final TextEditingController addressController =
      TextEditingController();

  bool isLoading = true;
  bool canGoBack = false;
  bool canGoForward = false;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              addressController.text = url;
            });
          },
          onPageFinished: (url) async {
            final back = await controller.canGoBack();
            final forward = await controller.canGoForward();

            if (!mounted) return;
            setState(() {
              isLoading = false;
              canGoBack = back;
              canGoForward = forward;
              addressController.text = url;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://duckduckgo.com'));
  }

  void openAddress() {
    String text = addressController.text.trim();
    if (text.isEmpty) return;

    final Uri? uri = Uri.tryParse(text);
    final bool isWebAddress = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    final String url = isWebAddress
        ? text
        : 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(text)}';

    controller.loadRequest(Uri.parse(url));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Browser'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addressController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => openAddress(),
                    decoration: InputDecoration(
                      hintText: 'Search or enter website',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: openAddress,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Go',
                ),
              ],
            ),
          ),
          if (isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: WebViewWidget(controller: controller),
          ),
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: canGoBack
                      ? () => controller.goBack()
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                IconButton(
                  onPressed: canGoForward
                      ? () => controller.goForward()
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Forward',
                ),
                IconButton(
                  onPressed: () => controller.reload(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                ),
                IconButton(
                  onPressed: () {
                    addressController.text =
                        'https://duckduckgo.com';
                    openAddress();
                  },
                  icon: const Icon(Icons.home),
                  tooltip: 'Home',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
