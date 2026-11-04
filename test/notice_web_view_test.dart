import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/notice_board.dart';
import 'package:forest_star/notice_web_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class TestWebPlatform extends WebViewPlatform {
  late TestWebController controller;
  late TestNavigation delegate;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = TestWebController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = TestNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => TestWebWidget(params);
}

class TestWebController extends PlatformWebViewController {
  TestWebController(super.params) : super.implementation();
  final requests = <LoadRequestParams>[];
  JavaScriptMode? javaScript;
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      javaScript = mode;
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      requests.add(params);
  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class TestNavigation extends PlatformNavigationDelegate {
  TestNavigation(super.params) : super.implementation();
  late PageEventCallback started, finished;
  late ProgressCallback progress;
  late WebResourceErrorCallback error;
  late HttpResponseErrorCallback httpError;
  late NavigationRequestCallback navigate;
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      started = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      progress = callback;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      error = callback;
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async =>
      httpError = callback;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async => navigate = callback;
}

class TestWebWidget extends PlatformWebViewWidget {
  TestWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    key: ValueKey('platform_web_content'),
    color: Color(0xfffff7e4),
  );
}

void main() {
  late TestWebPlatform platform;
  setUp(() => WebViewPlatform.instance = platform = TestWebPlatform());

  Future<void> mount(WidgetTester tester, {int revision = 0}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeWebView(
            uri: noticeBoardUri,
            reloadToken: revision,
            fallback: const Text('已快取的森林消息'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads real URL with JavaScript, progress and refresh', (
    tester,
  ) async {
    await mount(tester);
    expect(
      platform.controller.requests.single.uri.toString(),
      'https://star.singtu.hk/notice.html',
    );
    expect(platform.controller.javaScript, JavaScriptMode.unrestricted);
    expect(
      platform.controller.requests.single.headers.keys,
      isNot(contains('Authorization')),
    );
    expect(find.byKey(const ValueKey('platform_web_content')), findsOneWidget);
    platform.delegate.started(noticeBoardUri.toString());
    platform.delegate.progress(54);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .54,
    );
    platform.delegate.finished(noticeBoardUri.toString());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await mount(tester, revision: 1);
    expect(platform.controller.requests, hasLength(2));
    platform.delegate.finished(noticeBoardUri.toString());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'subresource errors do not hide page; HTTP main error can retry',
    (tester) async {
      await mount(tester);
      platform.delegate.started(noticeBoardUri.toString());
      platform.delegate.error(
        const WebResourceError(
          errorCode: -2,
          description: 'image',
          isForMainFrame: false,
        ),
      );
      await tester.pump();
      expect(find.text('重新載入公告'), findsNothing);
      platform.delegate.httpError(
        HttpResponseError(
          request: WebResourceRequest(uri: noticeBoardUri),
          response: WebResourceResponse(uri: noticeBoardUri, statusCode: 404),
        ),
      );
      // Native WebViews may emit finished after a failing HTTP response.
      platform.delegate.finished(noticeBoardUri.toString());
      await tester.pump();
      expect(find.text('已快取的森林消息'), findsOneWidget);
      await tester.tap(find.text('重新載入公告'));
      await tester.pump();
      expect(platform.controller.requests, hasLength(2));
      platform.delegate.finished(noticeBoardUri.toString());
      await tester.pump();
      expect(find.text('已快取的森林消息'), findsNothing);
      // iOS HTTP errors can omit both request and response URI.
      platform.delegate.httpError(
        const HttpResponseError(
          response: WebResourceResponse(uri: null, statusCode: 503),
        ),
      );
      await tester.pump();
      expect(find.text('已快取的森林消息'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('offline / timeout can close without late callback errors', (
    tester,
  ) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('已快取的森林消息'), findsOneWidget);
    await tester.tap(find.text('重新載入公告'));
    await tester.pump();
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: 'offline',
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    expect(find.text('已快取的森林消息'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    platform.delegate.finished(noticeBoardUri.toString());
    await tester.pump(const Duration(seconds: 21));
    expect(tester.takeException(), isNull);
  });

  test(
    'navigation accepts same-origin HTTPS and rejects external / app URLs',
    () {
      expect(
        isNoticeNavigationAllowed(
          noticeBoardUri,
          'https://star.singtu.hk/events/1#news',
        ),
        isTrue,
      );
      for (final url in [
        'http://star.singtu.hk/notice.html',
        'https://star.singtu.hk.evil.test/',
        'https://example.com/',
        'https://user:password@star.singtu.hk/',
        'https://star.singtu.hk:8080/',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'intent://test',
      ]) {
        expect(
          isNoticeNavigationAllowed(noticeBoardUri, url),
          isFalse,
          reason: url,
        );
      }
    },
  );
}
