import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart';
import 'package:app_herois/providers/hero_provider.dart';
import 'package:app_herois/providers/squad_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test.dart' show MemoryRepository;
import 'squad_test.dart' show MemorySquadRepository;

class SnapshotSquad extends MemorySquadRepository {
  bool delayNext = false;
  Completer<List<Hero>>? pending;
  List<Hero>? snapshot;
  SnapshotSquad(super.heroes);
  @override
  Future<List<Hero>> getMembers() {
    if (!delayNext) return super.getMembers();
    delayNext = false;
    snapshot = List.of(saved);
    pending = Completer<List<Hero>>();
    return pending!.future;
  }

  @override
  Future<RecruitmentResult> recruit(Hero hero) async {
    saved.add(hero);
    return RecruitmentResult.recruited;
  }

  void finishRead() => pending!.complete(snapshot!);
}

class ReviewHeroes extends MemoryRepository {
  final requests = <int, Completer<Hero>>{};
  ReviewHeroes(super.catalog) : super(cachedCount: catalog.length);
  @override
  Future<Hero> getById(int id) => (requests[id] = Completer<Hero>()).future;
  @override
  Future<Hero?> getDailyHero({DateTime? date, Random? random}) async =>
      catalog.first;
}

void main() {
  final data =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map)['heroes']
          as List;
  final catalog = data
      .map((row) => Hero.fromJson(row as Map<String, dynamic>))
      .toList();
  final updated = Hero.fromJson({
    ...catalog.first.toJson(),
    'powerstats': {...catalog.first.powerstats, 'strength': 101},
  });

  test(
    'Consulta antiga não sobrescreve recompensa recebida durante carregamento',
    () async {
      final repository = SnapshotSquad(catalog.take(5).toList());
      final provider = SquadProvider(repository, ReviewHeroes(catalog));
      addTearDown(provider.dispose);
      await provider.loadMembers();
      repository.delayNext = true;
      final loading = provider.loadMembers();
      provider.updateMember(updated);
      repository.finishRead();
      await loading;
      expect(provider.members.first.toJson(), updated.toJson());
      expect(provider.loadingMembers, isFalse);
    },
  );

  test(
    'Consulta antiga não remove da interface um recrutamento concluído',
    () async {
      final repository = SnapshotSquad(catalog.take(1).toList());
      final provider = SquadProvider(repository, ReviewHeroes(catalog));
      addTearDown(provider.dispose);
      await provider.loadMembers();
      repository.delayNext = true;
      final loading = provider.loadMembers();
      provider.dailyHero = catalog[1];
      expect(await provider.recruitDailyHero(), contains('foi recrutado'));
      repository.finishRead();
      await loading;
      expect(
        provider.members.map((hero) => hero.id).toList(),
        catalog.take(2).map((hero) => hero.id).toList(),
      );
      expect(provider.members.length, repository.saved.length);
    },
  );

  test('Carregar contrato não sobrescreve evolução recebida enquanto aguarda SQLite', () async {
    final repository = SnapshotSquad(catalog.take(5).toList());
    final provider = SquadProvider(repository, ReviewHeroes(catalog));
    addTearDown(provider.dispose);
    await provider.loadMembers();
    repository.delayNext = true;
    final loading = provider.loadDailyContract();
    await Future<void>.delayed(Duration.zero);
    provider.updateMember(updated);
    repository.finishRead();
    await loading;
    expect(provider.members.first.powerstats['strength'], 101);
    expect(provider.dailyHero!.id, catalog.first.id);
  });

  test(
    'Resposta antiga de detalhes não substitui o agente mais recente',
    () async {
      final repository = ReviewHeroes(catalog);
      final provider = HeroProvider(repository);
      addTearDown(provider.dispose);
      final first = provider.loadDetails(catalog[0].id);
      final second = provider.loadDetails(catalog[1].id);
      repository.requests[catalog[1].id]!.complete(catalog[1]);
      await second;
      repository.requests[catalog[0].id]!.complete(catalog[0]);
      await first;
      expect(provider.selectedHero!.id, catalog[1].id);
      expect(provider.loadingDetails, isFalse);
    },
  );

  test('Resposta após descarte não notifica um Provider destruído', () async {
    final repository = ReviewHeroes(catalog);
    final provider = HeroProvider(repository);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final request = provider.loadDetails(catalog.first.id);
    provider.dispose();
    repository.requests[catalog.first.id]!.complete(catalog.first);
    await request;
    expect(notifications, 1);
  });
}
