import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forest_star/notice_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'HTML keeps readable formatting and removes executable/network content',
    () {
      final html = sanitizeNoticeHtml('''<!doctype html><html><head>
      <style>body {display:none}</style></head><body>
      <h2 onclick="fetch('/secret')">森林消息</h2>
      <p style="color:red">歡迎<strong>夥伴</strong></p>
      <ul><li>彈珠屋</li><li>守衛</li></ul>
      <a href="https://example.com">純文字連結</a>
      <img src="https://example.com/track"><script>secret()</script>
      <iframe src="https://example.com">不能出現</iframe>
      <form><input name="password">也不能出現</form></body></html>''');
      expect(html, contains('<h2>森林消息</h2>'));
      expect(html, contains('<strong>夥伴</strong>'));
      expect(html, contains('<li>守衛</li>'));
      expect(html, contains('純文字連結'));
      for (final excluded in [
        'onclick',
        'style',
        'href',
        'http',
        'secret',
        '<img',
        '<script',
        '<iframe',
        '不能出現',
        '<form',
      ]) {
        expect(html, isNot(contains(excluded)), reason: excluded);
      }
    },
  );

  test('rejects empty, oversized and excessively nested HTML', () {
    expect(
      () => sanitizeNoticeHtml('<script>text</script>'),
      throwsFormatException,
    );
    expect(() => sanitizeNoticeHtml('中' * 22000), throwsFormatException);
    expect(
      () => sanitizeNoticeHtml('${'<div>' * 20}text${'</div>' * 20}'),
      throwsFormatException,
    );
    expect(
      () => sanitizeNoticeHtml('<p>text</p>' * 701),
      throwsFormatException,
    );
  });

  test(
    'loads correct HTTPS endpoint and persists a sanitized UTF8 notice',
    () async {
      final controller = NoticeBoardController(
        prefs: prefs,
        clientFactory: () => MockClient((request) async {
          expect(
            request.url.toString(),
            'https://star.singtu.hk/notice.html',
          );
          expect(request.followRedirects, isFalse);
          return http.Response(
            '<h2>森林更新</h2><p>新公告</p>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      await controller.refresh();
      expect(controller.html, contains('森林更新'));
      expect(controller.status, '最新消息');
      expect(prefs.getString(noticeBoardCacheKey), controller.html);
      controller.dispose();
      final restored = NoticeBoardController(prefs: prefs);
      expect(restored.html, contains('森林更新'));
      restored.dispose();
    },
  );

  for (final status in [404, 302, 500]) {
    test('HTTP $status preserves last good notice', () async {
      await prefs.setString(noticeBoardCacheKey, '<p>上次公告</p>');
      final controller = NoticeBoardController(
        prefs: prefs,
        clientFactory: () =>
            MockClient((_) async => http.Response('error', status)),
      );
      await controller.refresh();
      expect(controller.html, '<p>上次公告</p>');
      expect(controller.status, '離線公告');
      expect(controller.loading, isFalse);
      controller.dispose();
    });
  }

  test(
    'stream cap works without Content-Length and retains bundled fallback',
    () async {
      final controller = NoticeBoardController(
        prefs: prefs,
        clientFactory: () => MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('x' * 40000),
              utf8.encode('y' * 40000),
            ]),
            200,
          ),
        ),
      );
      await controller.refresh();
      expect(controller.html, defaultNoticeHtml);
      expect(controller.status, '森林消息');
      expect(prefs.containsKey(noticeBoardCacheKey), isFalse);
      controller.dispose();
    },
  );

  test('deduplicates refresh and ignores completion after disposal', () async {
    final response = Completer<http.Response>();
    var requests = 0, notifications = 0;
    final controller = NoticeBoardController(
      prefs: prefs,
      clientFactory: () => MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    controller.addListener(() => notifications++);
    final pending = controller.refresh();
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    controller.dispose();
    response.complete(http.Response('<p>too late</p>', 200));
    await pending;
    expect(notifications, 1);
    expect(prefs.containsKey(noticeBoardCacheKey), isFalse);
  });
}
