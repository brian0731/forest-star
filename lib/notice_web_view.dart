import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

bool isNoticeNavigationAllowed(Uri origin, String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == origin.host &&
      uri.port == origin.port &&
      uri.userInfo.isEmpty;
}

/// The website controls its HTML/CSS/JS. No game data or JS bridge is exposed.
class NoticeWebView extends StatefulWidget {
  const NoticeWebView({
    super.key,
    required this.uri,
    required this.fallback,
    this.compact = false,
    this.reloadToken = 0,
  });
  final Uri uri;
  final Widget fallback;
  final bool compact;
  final int reloadToken;
  @override
  State<NoticeWebView> createState() => _NoticeWebViewState();
}

class _NoticeWebViewState extends State<NoticeWebView> {
  WebViewController? _web;
  Timer? _timeout;
  int _progress = 0;
  bool _failed = false;
  String? _pageUrl;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final web = WebViewController();
      await web.setBackgroundColor(const Color(0xfffff7e4));
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              isNoticeNavigationAllowed(widget.uri, request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (url) {
            if (!mounted) return;
            _pageUrl = url;
            setState(() {
              _progress = 0;
              _failed = false;
            });
            _startTimeout();
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress.clamp(0, 100));
          },
          onPageFinished: (_) {
            _timeout?.cancel();
            if (mounted) {
              setState(() => _progress = 100);
              unawaited(_fitPage());
            }
          },
          onHttpError: (error) {
            // WKWebView's HTTP error callback does not always supply a URI.
            final uri = error.request?.uri ?? error.response?.uri;
            if (uri == null || uri.toString() == _pageUrl) _fail();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _fail();
          },
        ),
      );
      if (!mounted) return;
      setState(() => _web = web);
      await _reload();
    } catch (_) {
      _fail();
    }
  }

  Future<void> _fitPage() async {
    if (_failed) return;
    try {
      // Respect viewport settings already supplied by the website.
      await _web?.runJavaScript('''
        if (!document.querySelector('meta[name="viewport"]')) {
          const viewport = document.createElement('meta');
          viewport.name = 'viewport';
          viewport.content = 'width=device-width, initial-scale=1';
          document.head.appendChild(viewport);
        }
      ''');
    } catch (_) {
      // Optional fitting must not hide an otherwise readable document.
    }
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), _fail);
  }

  void _fail() {
    _timeout?.cancel();
    if (mounted) {
      setState(() {
        _failed = true;
        _progress = 100;
      });
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;
    if (_web == null) return _initialize();
    setState(() {
      _failed = false;
      _progress = 0;
      _pageUrl = widget.uri.toString();
    });
    _startTimeout();
    try {
      await _web!.loadRequest(
        widget.uri,
        headers: {'Cache-Control': 'no-cache'},
      );
    } catch (_) {
      _fail();
    }
  }

  @override
  void didUpdateWidget(covariant NoticeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.uri != widget.uri) {
      if (WebViewPlatform.instance != null) unawaited(_reload());
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Desktop / widget-test environments may not provide a native WebView.
    if (WebViewPlatform.instance == null) return widget.fallback;
    return Column(
      children: [
        if (_progress < 100 && !_failed)
          LinearProgressIndicator(
            key: const ValueKey('notice_web_progress'),
            value: _progress == 0 ? null : _progress / 100,
            color: const Color(0xff6b804c),
            backgroundColor: const Color(0xffe6e8d3),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_web != null)
                Offstage(
                  offstage: _failed,
                  child: WebViewWidget(
                    key: const ValueKey('notice_native_webview'),
                    controller: _web!,
                    // Scroll the document inside the sheet; dragging its
                    // handle or pressing Close still dismisses the notice.
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                  ),
                ),
              if (_failed)
                ColoredBox(
                  color: const Color(0xfffff7e4),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(widget.compact ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.compact) ...[
                          const Text('暫時無法載入公告，以下為離線內容。'),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => unawaited(_reload()),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('重新載入公告'),
                            ),
                          ),
                        ],
                        widget.fallback,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
