import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'gacha.dart';
import 'game_session.dart';
import 'audio.dart';

String secureUuid([Random? generator]) {
  final random = generator ?? Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class WalletIdentity {
  const WalletIdentity(this.id, this.secret);
  final String id, secret;
  String get authorization => 'Bearer $id.$secret';
  String get recoveryCode => 'FS1.$id.$secret';
  factory WalletIdentity.create() {
    final random = Random.secure();
    return WalletIdentity(
      secureUuid(random),
      List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    );
  }
  factory WalletIdentity.parse(String code) {
    final match = RegExp(
      r'^FS1\.([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([0-9a-f]{64})$',
    ).firstMatch(code.trim());
    if (match == null) throw const FormatException('Invalid recovery code');
    return WalletIdentity(match[1]!, match[2]!);
  }
}

abstract interface class WalletStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureWalletStorage implements WalletStorage {
  final storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class GachaApi {
  GachaApi({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  static final base = Uri.parse('https://star.singtu.hk/api/gacha/');
  Future<Map<String, dynamic>> request(
    String path,
    WalletIdentity wallet, {
    Map<String, dynamic>? data,
  }) async {
    final request = http.Request(
      data == null ? 'GET' : 'POST',
      base.resolve(path),
    )..followRedirects = false;
    request.headers['Authorization'] = wallet.authorization;
    request.headers['Accept'] = 'application/json';
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    return (() async {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw StateError('Purchase server unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 256 * 1024) {
          throw const FormatException('Response too large');
        }
        bytes.addAll(chunk);
      }
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    })().timeout(const Duration(seconds: 25));
  }

  void dispose() => client.close();
}

abstract interface class BillingStore {
  String get platform;
  Stream<List<PurchaseDetails>> get events;
  Future<ProductDetails?> loadProduct();
  Future<bool> buy(ProductDetails product, String walletId);
  Future<void> finish(PurchaseDetails purchase);
  Future<void> restore(String walletId);
}

class NativeBillingStore implements BillingStore {
  final store = InAppPurchase.instance;
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Stream<List<PurchaseDetails>> get events => store.purchaseStream;
  @override
  Future<ProductDetails?> loadProduct() async {
    if (!await store.isAvailable()) return null;
    final response = await store.queryProductDetails({DrawPool.productId});
    if (response.error != null) return null;
    return response.productDetails
        .where((p) => p.id == DrawPool.productId)
        .firstOrNull;
  }

  @override
  Future<bool> buy(ProductDetails product, String walletId) =>
      store.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: walletId,
        ),
        autoConsume: false,
      );
  @override
  Future<void> finish(PurchaseDetails purchase) async {
    // Google Play consumption is completed by the verified backend. Consuming
    // also acknowledges the purchase; an additional client acknowledge would
    // target an already-consumed product.
    if (platform == 'android') return;
    if (purchase.pendingCompletePurchase) {
      await store.completePurchase(purchase);
    }
  }

  @override
  Future<void> restore(String walletId) =>
      store.restorePurchases(applicationUserName: walletId);
}

class GachaController extends ChangeNotifier {
  GachaController(
    this.session, {
    this.billing,
    WalletStorage? storage,
    GachaApi? api,
    Random? random,
    DateTime Function()? clock,
  }) : storage = storage ?? SecureWalletStorage(),
       api = api ?? GachaApi(),
       random = random ?? Random.secure(),
       clock = clock ?? DateTime.now;
  final GameSession session;
  final BillingStore? billing;
  final WalletStorage storage;
  final GachaApi api;
  final Random random;
  final DateTime Function() clock;
  WalletIdentity? wallet;
  ProductDetails? product;
  bool busy = false,
      initialized = false,
      serverReady = false,
      _disposed = false,
      _storePending = false;
  int paidTickets = 0;
  String message = '每天 5 次免費，寵物與資源都有機會出現。';
  DrawResult? lastResult;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _eventQueue = Future.value();
  final _unfinished = <String, PurchaseDetails>{};
  static const walletKey = 'forest_draw_wallet_v1',
      pendingKey = 'forest_pending_draw_v1';
  int get freeLeft => freeDrawsLeft(session.state, clock());
  bool get canDraw =>
      !busy && (freeLeft > 0 || (serverReady && paidTickets > 0));
  bool get canPurchase =>
      !busy &&
      !_storePending &&
      freeLeft == 0 &&
      serverReady &&
      product != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (initialized || _disposed) return;
    initialized = true;
    // Free draws work without a store, network or secure-storage plugin.
    if (billing == null) return;
    try {
      final saved = await storage.read(walletKey);
      wallet = saved == null
          ? WalletIdentity.create()
          : WalletIdentity.parse(saved);
      if (saved == null) await storage.write(walletKey, wallet!.recoveryCode);
      if (_disposed) return;
      _subscription = billing!.events.listen(
        (purchases) {
          _eventQueue = _eventQueue
              .then((_) => _processPurchases(purchases))
              .catchError((Object _) {
                if (!_disposed) {
                  message = '交易等待核驗，請稍後按「同步／補領」。';
                  _notify();
                }
              });
        },
        onError: (Object _) {
          if (!_disposed) {
            _storePending = false;
            message = '商店暫時未能連線，免費轉珠仍可使用。';
            _notify();
          }
        },
      );
      product = await billing!.loadProduct().timeout(
        const Duration(seconds: 15),
      );
      if (_disposed) return;
      await sync();
    } catch (_) {
      if (!_disposed) {
        serverReady = false;
        message = '付費轉珠尚未開放或暫時無法連線；每日免費照常。';
        _notify();
      }
    }
  }

  Future<void> _syncWallet() async {
    final identity = wallet;
    if (identity == null) return;
    for (var page = 0; page < 100; page++) {
      final after = session.state.paidDrawSequences[identity.id] ?? 0;
      final response = await api.request('wallet?after=$after', identity);
      if (_disposed) return;
      if (response['productId'] != DrawPool.productId ||
          response['packDraws'] != DrawPool.productDraws) {
        throw const FormatException('Product mismatch');
      }
      serverReady = (response['platforms'] as List).contains(billing?.platform);
      final tickets = response['tickets'];
      if (tickets is! int || tickets < 0 || tickets > 1000000) {
        throw const FormatException('Invalid tickets');
      }
      paidTickets = tickets;
      final rewards = response['rewards'] as List;
      if (rewards.length > 100) throw const FormatException('Too many results');
      if (rewards.isEmpty) break;
      session.setExternalOverlay(true, source: 'draw-sync');
      session.cancelPendingSave();
      try {
        for (final entry in rewards) {
          final applied = await applyPaidDraw(
            session.state,
            session.prefs,
            identity.id,
            Map<String, dynamic>.from(entry as Map),
          );
          if (applied != null) {
            session.state = applied.$1;
            lastResult = applied.$2;
          }
        }
      } finally {
        session.setExternalOverlay(false, source: 'draw-sync');
      }
      if (rewards.length < 100) break;
    }
  }

  Future<void> sync() async {
    if (busy || wallet == null || _disposed) return;
    busy = true;
    _notify();
    try {
      for (final purchase in _unfinished.values.toList()) {
        await _verify(purchase);
      }
      final pending = await storage.read('$pendingKey.${wallet!.id}');
      if (pending != null) {
        await api.request('draw', wallet!, data: {'requestId': pending});
      }
      await _syncWallet();
      if (pending != null) await storage.delete('$pendingKey.${wallet!.id}');
      if (!_disposed) message = serverReady ? '已同步轉珠錢包。' : '付費服務尚未開放；每日免費照常。';
    } catch (_) {
      if (!_disposed) {
        serverReady = false;
        message = '暫時無法同步，已購買的次數會保留，請稍後再試。';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<DrawResult?> draw() async {
    if (!canDraw || _disposed) return null;
    busy = true;
    _notify();
    try {
      session.cancelPendingSave();
      if (freeLeft > 0) {
        final result = await performFreeDraw(
          session.state,
          session.prefs,
          random,
          clock(),
        );
        if (result == null) return null;
        session.state = result.$1;
        lastResult = result.$2;
      } else {
        final identity = wallet!;
        // Persist this id before sending: an interrupted request retries the
        // same server draw, never consuming another paid ticket.
        var requestId = await storage.read('$pendingKey.${identity.id}');
        requestId ??= secureUuid();
        await storage.write('$pendingKey.${identity.id}', requestId);
        await api.request('draw', identity, data: {'requestId': requestId});
        await _syncWallet();
        await storage.delete('$pendingKey.${identity.id}');
      }
      session.audio.play(SoundEffect.reward);
      message = '獎品已儲存，可安心返回營地。';
      return lastResult;
    } catch (_) {
      message = '暫時無法完成轉珠，請按同步或稍後重試。';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> buy() async {
    if (!canPurchase || wallet == null || billing == null) return;
    busy = true;
    _storePending = true;
    message = '正在開啟商店付款…';
    _notify();
    try {
      if (!await billing!.buy(product!, wallet!.id)) {
        _storePending = false;
        message = '尚未完成購買。';
      }
    } catch (_) {
      _storePending = false;
      message = '付款未能啟動，請稍後再試。';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> restoreTransactions() async {
    if (billing == null || wallet == null || busy) return;
    try {
      await billing!.restore(wallet!.id);
      await sync();
    } catch (_) {
      message = '暫時未能補領，請檢查網絡後再試。';
      _notify();
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final key =
        purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
    _unfinished[key] = purchase;
    final response = await api.request(
      'purchases/verify',
      wallet!,
      data: {
        'platform': billing!.platform,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'verificationData': purchase.verificationData.serverVerificationData,
      },
    );
    if (response['verified'] != true || response['storeComplete'] != true) {
      throw StateError('Verification pending');
    }
    await billing!.finish(purchase);
    _unfinished.remove(key);
    _storePending = false;
  }

  Future<void> _processPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
      if (purchase.productID != DrawPool.productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _storePending = true;
          message = '付款等待商店或家長核准，尚未發放次數。';
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _storePending = false;
          message = '購買未完成；沒有發放付費次數。';
          await billing!.finish(purchase);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Wait for any current free-draw save before applying paid rewards.
          while (busy && !_disposed) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          if (_disposed) return;
          busy = true;
          _notify();
          try {
            await _verify(purchase);
            await _syncWallet();
            message = '購買成功：10 次轉珠已存入錢包。';
          } catch (_) {
            message = '購買等待核驗；請保持網絡，或按同步／補領。';
          } finally {
            busy = false;
          }
      }
      _notify();
    }
  }

  Future<void> importWallet(String code) async {
    if (busy || _storePending) throw StateError('Transaction pending');
    final identity = WalletIdentity.parse(code);
    busy = true;
    _notify();
    try {
      // Confirm the key with the server before replacing the current wallet.
      await api.request('wallet?after=0', identity);
      await storage.write(walletKey, identity.recoveryCode);
      wallet = identity;
      paidTickets = 0;
      serverReady = false;
    } finally {
      busy = false;
      _notify();
    }
    await sync();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    api.dispose();
    super.dispose();
  }
}
