import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'content_updates.dart' show updateHost;
import 'notice_web_view.dart';

final noticeBoardUri = Uri.https(updateHost, '/notice.html');
const noticeBoardCacheKey = 'forest_notice_html_v2';
const defaultNoticeHtml =
    '<h2>歡迎回到森林</h2>'
    '<p>先到營地與夥伴見面，再前往彈珠屋收集成長分，或帶領小隊守護森林。</p>'
    '<p><strong>點點開始頁的夥伴，看看牠們的回應！</strong></p>';

/// Cache a bounded native text fallback; live announcements use a real WebView.
String sanitizeNoticeHtml(String raw) {
  if (utf8.encode(raw).length > 64 * 1024) {
    throw const FormatException('Notice exceeds size limit');
  }
  final document = parser.parse(raw);
  final result = dom.DocumentFragment();
  var nodes = 0;
  const allowed = {
    'h1',
    'h2',
    'h3',
    'p',
    'strong',
    'b',
    'em',
    'i',
    'u',
    's',
    'br',
    'ul',
    'ol',
    'li',
    'blockquote',
    'hr',
    'div',
    'span',
    'small',
  };
  const discard = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'svg',
    'math',
    'form',
    'input',
    'button',
    'textarea',
    'select',
    'video',
    'audio',
    'canvas',
    'template',
    'noscript',
    'head',
  };
  void append(dom.Node node, dom.Node target, int depth) {
    if (++nodes > 700 || depth > 18) {
      throw const FormatException('Notice too complex');
    }
    if (node is dom.Text) {
      target.append(dom.Text(node.data));
      return;
    }
    if (node is! dom.Element || discard.contains(node.localName)) return;
    final name = node.localName!;
    final next = allowed.contains(name) ? dom.Element.tag(name) : target;
    if (next != target) target.append(next);
    for (final child in node.nodes) {
      append(child, next, depth + 1);
    }
  }

  for (final node in document.body?.nodes ?? <dom.Node>[]) {
    append(node, result, 0);
  }
  if ((result.text ?? '').trim().isEmpty) {
    throw const FormatException('Empty notice');
  }
  return result.outerHtml;
}

class NoticeBoardController extends ChangeNotifier {
  NoticeBoardController({
    required this.prefs,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new {
    final cached = prefs.getString(noticeBoardCacheKey);
    if (cached != null) {
      try {
        html = sanitizeNoticeHtml(cached);
        cachedContent = true;
      } catch (_) {
        /* Use bundled text. */
      }
    }
  }
  final SharedPreferences prefs;
  final http.Client Function() _clientFactory;
  http.Client? _client;
  bool loading = false,
      offline = false,
      cachedContent = false,
      _disposed = false;
  String html = defaultNoticeHtml;
  int _epoch = 0;
  int get revision => _epoch;
  bool get active => !_disposed;
  String get status => loading
      ? '更新中'
      : offline
      ? (cachedContent ? '離線公告' : '森林消息')
      : '最新消息';

  Future<void> refresh() async {
    if (_disposed || loading) return;
    final epoch = ++_epoch;
    loading = true;
    notifyListeners();
    final client = _client = _clientFactory();
    try {
      final raw = await (() async {
        final request = http.Request('GET', noticeBoardUri)
          ..followRedirects = false;
        request.headers['Accept'] = 'text/html';
        request.headers['Cache-Control'] = 'no-cache';
        final response = await client.send(request);
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 64 * 1024) {
          throw const FormatException('Unavailable notice');
        }
        final output = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (_disposed || epoch != _epoch) return null;
          if (output.length + chunk.length > 64 * 1024) {
            throw const FormatException('Notice too large');
          }
          output.add(chunk);
        }
        return output.takeBytes();
      })().timeout(const Duration(seconds: 8));
      if (_disposed || epoch != _epoch || raw == null) return;
      final sanitized = sanitizeNoticeHtml(utf8.decode(raw));
      // Failed cache writes must not prevent this session from showing the news.
      try {
        await prefs.setString(noticeBoardCacheKey, sanitized);
      } catch (_) {
        /* In-memory copy remains usable. */
      }
      if (_disposed || epoch != _epoch) return;
      html = sanitized;
      cachedContent = true;
      offline = false;
    } catch (_) {
      if (!_disposed && epoch == _epoch) offline = true;
    } finally {
      client.close();
      if (!_disposed && epoch == _epoch) {
        _client = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _client?.close();
    super.dispose();
  }
}

class ForestNoticeBoard extends StatelessWidget {
  const ForestNoticeBoard({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final NoticeBoardController controller;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Material(
      color: const Color(0xfffff5da),
      elevation: 9,
      shadowColor: const Color(0x802a3a23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
        side: const BorderSide(color: Color(0xffc69a4c), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('start_notice_board'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.campaign_rounded,
                    size: 20,
                    color: Color(0xff6b804c),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      '森林告示板',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xff3c5c39),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    controller.status,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff8a7149),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.open_in_full,
                    size: 14,
                    color: Color(0xff8a7149),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRect(
                  child: IgnorePointer(
                    child: NoticeWebView(
                      uri: noticeBoardUri,
                      compact: true,
                      reloadToken: controller.revision,
                      fallback: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: NoticeHtml(html: controller.html, compact: true),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class NoticeHtml extends StatelessWidget {
  const NoticeHtml({super.key, required this.html, this.compact = false});
  final String html;
  final bool compact;
  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    textStyle: TextStyle(
      fontFamily: 'ForestUI',
      fontSize: compact ? 12 : 15,
      height: 1.6,
      color: const Color(0xff536146),
    ),
    onTapUrl: (_) => false,
    customStylesBuilder: (element) => switch (element.localName) {
      'h1' || 'h2' || 'h3' => {
        'font-size': compact ? '14px' : '21px',
        'color': '#36553b',
        'margin': '0 0 8px 0',
        'font-weight': '700',
      },
      'p' => {'margin': '0 0 8px 0'},
      'blockquote' => {
        'padding': '10px',
        'background-color': '#e9eedb',
        'margin': '8px 0',
      },
      _ => null,
    },
  );
}

Future<void> showForestNotice(
  BuildContext context,
  NoticeBoardController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: const Color(0xfffff7e4),
  builder: (context) => _ForestNoticeSheet(controller: controller),
);

class _ForestNoticeSheet extends StatefulWidget {
  const _ForestNoticeSheet({required this.controller});
  final NoticeBoardController controller;
  @override
  State<_ForestNoticeSheet> createState() => _ForestNoticeSheetState();
}

class _ForestNoticeSheetState extends State<_ForestNoticeSheet> {
  int _reloadToken = 0;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .82,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '森林告示板',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff36553b),
                  ),
                ),
              ),
              IconButton(
                tooltip: '更新公告',
                onPressed: () {
                  setState(() => _reloadToken++);
                  unawaited(widget.controller.refresh());
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: '關閉公告',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Divider(color: Color(0xffd7c79b)),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (_, _) => NoticeWebView(
                uri: noticeBoardUri,
                reloadToken: _reloadToken,
                fallback: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12, bottom: 20),
                  child: NoticeHtml(html: widget.controller.html),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
