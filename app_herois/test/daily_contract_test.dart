import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OffsetRandom implements Random {
  final int offset;
  OffsetRandom(this.offset);
  @override
  int nextInt(int max) => offset;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
}

class CachedDatabase extends HeroDatabase {
  final List<Hero> catalog;
  CachedDatabase(this.catalog);
  @override
  Future<int> count() async => catalog.length;
  @override
  Future<Hero?> getById(int id) async =>
      catalog.where((hero) => hero.id == id).firstOrNull;
  @override
  Future<List<Hero>> getPage({required int limit, required int offset}) async =>
      catalog.skip(offset).take(limit).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map)['heroes']
          as List;
  final catalog = original
      .map((json) => Hero.fromJson(json as Map<String, dynamic>))
      .toList();
  final today = DateTime(2026, 10, 13);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Sorteio alcança o último dos 563 e permanece no mesmo dia ao reabrir',
    () async {
      final repository = HeroRepository(database: CachedDatabase(catalog));
      final selected = await repository.getDailyHero(
        date: today,
        random: OffsetRandom(562),
      );
      expect(selected!.id, catalog.last.id);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('daily_contract_date'), '2026-10-13');
      expect(preferences.getInt('daily_contract_hero_id'), selected.id);
      final reopened = HeroRepository(database: CachedDatabase(catalog));
      expect(
        (await reopened.getDailyHero(
          date: today.add(const Duration(hours: 23)),
          random: OffsetRandom(0),
        ))!.id,
        selected.id,
      );
    },
  );

  test('Mudança da data faz novo sorteio e persiste a data local', () async {
    final repository = HeroRepository(database: CachedDatabase(catalog));
    final first = await repository.getDailyHero(
      date: today,
      random: OffsetRandom(562),
    );
    final next = await repository.getDailyHero(
      date: today.add(const Duration(days: 1)),
      random: OffsetRandom(0),
    );
    expect(next!.id, catalog.first.id);
    expect(next.id, isNot(first!.id));
    expect(
      (await SharedPreferences.getInstance()).getString('daily_contract_date'),
      '2026-10-14',
    );
  });

  test('Sem catálogo, não persiste um sorteio inválido', () async {
    final repository = HeroRepository(database: CachedDatabase([]));
    expect(await repository.getDailyHero(date: today), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
