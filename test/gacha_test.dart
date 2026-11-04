import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_star/gacha.dart';
import 'package:forest_star/gacha_store.dart';
import 'package:forest_star/game.dart';
import 'package:forest_star/game_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_screen_test.dart' show FakeAudio;

class MemoryWallet implements WalletStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeBilling implements BillingStore {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  int buys = 0, finishes = 0;
  String? account;
  @override
  String get platform => 'ios';
  @override
  Stream<List<PurchaseDetails>> get events => stream.stream;
  @override
  Future<ProductDetails?> loadProduct() async => ProductDetails(
    id: DrawPool.productId,
    title: '10 draws',
    description: '10 draws',
    price: 'HK\$ 8.00',
    rawPrice: 8,
    currencyCode: 'HKD',
  );
  @override
  Future<bool> buy(ProductDetails product, String walletId) async {
    buys++;
    account = walletId;
    return true;
  }

  @override
  Future<void> finish(PurchaseDetails purchase) async {
    finishes++;
  }

  @override
  Future<void> restore(String walletId) async {}
}

PurchaseDetails purchase(PurchaseStatus status) => PurchaseDetails(
  productID: DrawPool.productId,
  purchaseID: '10001',
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'signed',
    source: 'app_store',
  ),
  transactionDate: '1',
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  test(
    'old six-pet save migrates without resetting levels, growth or team',
    () {
      final old = {
        'sugar': 987,
        'levels': [3, 4, 2, 1, 1, 1],
        'evolutions': [1, 1, 0, 0, 0, 0],
        'growth': [5, 6, 7, 8, 9, 10],
        'unlocked': [true, true, true, true, false, false],
        'team': [2, 0, 1, 3],
      };
      final state = GameState.fromJson(old);
      expect(friends.length, 26);
      expect(state.sugar, 987);
      expect(state.levels.take(6), [3, 4, 2, 1, 1, 1]);
      expect(state.levels.skip(6), everyElement(1));
      expect(state.growth.take(6), [5, 6, 7, 8, 9, 10]);
      expect(state.unlocked.skip(6), everyElement(false));
      expect(state.team, [2, 0, 1, 3]);
      expect(GameState.fromJson(state.toJson()).toJson(), state.toJson());
    },
  );
  test('pool has exact disclosed odds and twenty equally likely pets', () {
    final counts = <String, int>{};
    for (var ticket = 0; ticket < 1000; ticket++) {
      final reward = DrawPool.at(ticket),
          key = '${reward.kind.name}:${reward.pet ?? reward.amount}';
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    for (var pet = 6; pet < 26; pet++) {
      expect(counts['pet:$pet'], 15);
    }
    expect(counts['sugar:20'], 250);
    expect(counts['sugar:40'], 150);
    expect(counts['sugar:80'], 50);
    expect(counts['marbles:3'], 150);
    expect(counts['marbles:8'], 80);
    expect(counts['marbles:15'], 20);
  });
  test(
    'exactly five free draws, persisted quota, UTC+8 midnight and clock rollback',
    () async {
      var state = GameState();
      final day = DateTime.utc(2026, 11, 4, 15, 59);
      for (var i = 0; i < 5; i++) {
        final draw = await performFreeDraw(state, prefs, Random(i), day);
        expect(draw, isNotNull);
        state = draw!.$1;
        expect(freeDrawsLeft(state, day), 4 - i);
      }
      expect(await performFreeDraw(state, prefs, Random(0), day), isNull);
      state = GameState.fromJson(
        jsonDecode(prefs.getString('forest_star_v1')!),
      );
      expect(freeDrawsLeft(state, day), 0);
      expect(freeDrawsLeft(state, DateTime.utc(2026, 11, 4, 16)), 5);
      expect(freeDrawsLeft(state, day.subtract(const Duration(days: 1))), 0);
      final next = await performFreeDraw(
        state,
        prefs,
        Random(0),
        DateTime.utc(2026, 11, 4, 16),
      );
      expect(next!.$1.freeDrawsUsed, 1);
      expect(next.$1.drawDay, 20261105);
    },
  );
  test(
    'duplicate pet gains growth, upgrades, evolves and works in all four lanes',
    () {
      final state = GameState();
      final joined = applyDrawReward(
        state,
        const DrawReward(DrawKind.pet, 1, pet: 25),
      );
      expect(joined.joined, isTrue);
      expect(state.unlock(24), isFalse);
      applyDrawReward(state, const DrawReward(DrawKind.pet, 1, pet: 25));
      expect(state.levels[25], 2);
      applyDrawReward(state, const DrawReward(DrawKind.pet, 1, pet: 25));
      applyDrawReward(state, const DrawReward(DrawKind.pet, 1, pet: 25));
      expect(state.levels[25], 3);
      expect(state.evolutions[25], 1);
      for (final id in [7, 11, 19]) state.unlocked[id] = true;
      state.team = [25, 7, 11, 19];
      final combat = Combat()..begin(state);
      expect(combat.maxHealth, 125);
      for (var i = 0; i < 1200 && combat.active; i++) combat.tick(1 / 60);
      expect(combat.attacks.every((v) => v > 0), isTrue);
    },
  );
  test(
    'overflow and paid reward replay preserve currency and do not award twice',
    () async {
      var state = GameState()..marbles = 998;
      applyDrawReward(state, const DrawReward(DrawKind.marbles, 8));
      expect(state.marbles, 999);
      expect(state.sugar, 67);
      const wallet = 'be389284-9197-4a3f-b5c7-117b826ec331';
      final entry = {
        'sequence': 1,
        'reward': {'kind': 'pet', 'amount': 1, 'pet': 6},
      };
      final applied = await applyPaidDraw(state, prefs, wallet, entry);
      state = applied!.$1;
      expect(state.unlocked[6], isTrue);
      expect(await applyPaidDraw(state, prefs, wallet, entry), isNull);
      expect(state.growth[6], 0);
      await expectLater(
        applyPaidDraw(state, prefs, wallet, {
          'sequence': 3,
          'reward': entry['reward'],
        }),
        throwsFormatException,
      );
      await expectLater(
        applyPaidDraw(state, prefs, wallet, {
          'sequence': 2,
          'reward': {'kind': 'pet', 'amount': 1, 'pet': 999},
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'offline controller grants five free draws, never charges currency',
    () async {
      final session = GameSession(GameState(), prefs, FakeAudio());
      final controller = GachaController(
        session,
        clock: () => DateTime.utc(2026, 11, 4),
      );
      await controller.initialize();
      for (var i = 0; i < 5; i++) expect(await controller.draw(), isNotNull);
      expect(await controller.draw(), isNull);
      expect(controller.canPurchase, isFalse);
      expect(session.state.freeDrawsUsed, 5);
      expect(session.state.sugar, greaterThanOrEqualTo(60));
      controller.dispose();
      session.dispose();
    },
  );
  test(
    'purchase pending/cancel never grant; only verified server wallet grants and completes',
    () async {
      final billing = FakeBilling(), storage = MemoryWallet();
      var tickets = 0, allowVerification = false;
      final api = GachaApi(
        client: MockClient((request) async {
          expect(request.url.host, 'star.singtu.hk');
          expect(request.headers['Authorization'], startsWith('Bearer '));
          if (request.url.path.endsWith('/purchases/verify')) {
            if (!allowVerification) return http.Response('{}', 503);
            tickets = 10;
            return http.Response(
              jsonEncode({
                'verified': true,
                'storeComplete': true,
                'tickets': tickets,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'productId': DrawPool.productId,
              'packDraws': 10,
              'platforms': ['ios'],
              'tickets': tickets,
              'latestSequence': 0,
              'rewards': [],
            }),
            200,
          );
        }),
      );
      final session = GameSession(
        GameState()
          ..drawDay = 20261104
          ..freeDrawsUsed = 5,
        prefs,
        FakeAudio(),
      );
      final controller = GachaController(
        session,
        billing: billing,
        storage: storage,
        api: api,
        clock: () => DateTime.utc(2026, 11, 4),
      );
      await controller.initialize();
      expect(controller.canPurchase, isTrue);
      await controller.buy();
      expect(billing.buys, 1);
      expect(billing.account, controller.wallet!.id);
      billing.stream.add([purchase(PurchaseStatus.pending)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.paidTickets, 0);
      billing.stream.add([purchase(PurchaseStatus.purchased)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.paidTickets, 0);
      expect(billing.finishes, 0);
      allowVerification = true;
      await controller.sync();
      expect(controller.paidTickets, 10);
      expect(billing.finishes, 1);
      billing.stream.add([purchase(PurchaseStatus.canceled)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.paidTickets, 10);
      controller.dispose();
      session.dispose();
      await billing.stream.close();
    },
  );
  test('paid draw network retry uses the same persisted request id', () async {
    final storage = MemoryWallet(), billing = FakeBilling();
    var fail = true, drawRequests = 0;
    String? requestId;
    final api = GachaApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/draw')) {
          drawRequests++;
          final id = jsonDecode(request.body)['requestId'];
          requestId ??= id;
          expect(id, requestId);
          if (fail) return http.Response('{}', 503);
          return http.Response('{}', 200);
        }
        final after = int.parse(request.url.queryParameters['after'] ?? '0');
        return http.Response(
          jsonEncode({
            'productId': DrawPool.productId,
            'packDraws': 10,
            'platforms': ['ios'],
            'tickets': drawRequests > 0 ? 9 : 10,
            'latestSequence': drawRequests > 0 ? 1 : 0,
            'rewards': drawRequests > 0 && after == 0
                ? [
                    {
                      'sequence': 1,
                      'reward': {'kind': 'pet', 'amount': 1, 'pet': 6},
                    },
                  ]
                : [],
          }),
          200,
        );
      }),
    );
    final session = GameSession(
      GameState()
        ..drawDay = 20261104
        ..freeDrawsUsed = 5,
      prefs,
      FakeAudio(),
    );
    final controller = GachaController(
      session,
      billing: billing,
      storage: storage,
      api: api,
      clock: () => DateTime.utc(2026, 11, 4),
    );
    await controller.initialize();
    expect(await controller.draw(), isNull);
    final pending = '${GachaController.pendingKey}.${controller.wallet!.id}';
    expect(storage.values[pending], requestId);
    fail = false;
    await controller.sync();
    expect(drawRequests, 2);
    expect(storage.values[pending], isNull);
    expect(session.state.unlocked[6], isTrue);
    expect(session.state.growth[6], 0);
    await controller.sync();
    expect(session.state.growth[6], 0);
    controller.dispose();
    session.dispose();
    await billing.stream.close();
  });
}
