import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/hero_api.dart';
import '../data/hero_database.dart';
import '../models/hero.dart';

class HeroRepository {
  final HeroApi _api;
  final HeroDatabase _database;
  final String dailyPreferencePrefix;

  HeroRepository({
    HeroApi? api,
    HeroDatabase? database,
    this.dailyPreferencePrefix = 'daily_contract',
  }) : _api = api ?? HeroApi(),
       _database = database ?? HeroDatabase();

  Future<int> countCachedHeroes() => _database.count();

  Future<Hero?> getDailyHero({DateTime? date, Random? random}) async {
    final now = date ?? DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final preferences = await SharedPreferences.getInstance();
    final dateKey = '${dailyPreferencePrefix}_date';
    final idKey = '${dailyPreferencePrefix}_hero_id';
    final savedDate = preferences.getString(dateKey);
    final savedId = preferences.getInt(idKey);
    if (savedDate == today) {
      // Não sorteia novamente se o agente do dia estiver indisponível no cache.
      if (savedId == null) throw Exception('Sorteio diário incompleto.');
      return _database.getById(savedId);
    }
    final total = await countCachedHeroes();
    if (total == 0) return null;
    final offset = (random ?? Random()).nextInt(total);
    final page = await getPage(limit: 1, offset: offset);
    if (page.isEmpty) return null;
    final hero = page.first;
    // Salva primeiro o ID; a data só confirma um sorteio gravado com sucesso.
    if (!await preferences.setInt(idKey, hero.id) ||
        !await preferences.setString(dateKey, today)) {
      throw Exception('Não foi possível salvar o sorteio diário.');
    }
    return hero;
  }

  Future<Hero> getById(int id) async {
    try {
      return await _api.fetchById(id);
    } catch (_) {
      final cached = await _database.getById(id);
      if (cached != null) return cached;
      throw Exception('O agente não está disponível na API nem no cache.');
    }
  }

  Future<int> synchronize() async {
    final heroes = await _api.fetchAll();
    await _database.saveCatalog(heroes);
    return heroes.length;
  }

  Future<List<Hero>> getPage({required int limit, required int offset}) =>
      _database.getPage(limit: limit, offset: offset);
}
