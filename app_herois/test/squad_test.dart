import 'dart:convert';
import 'dart:io';

import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart';
import 'package:app_herois/providers/squad_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySquadRepository extends SquadRepository {
  final List<Hero> saved;
  bool fail = false;
  MemorySquadRepository(List<Hero> heroes)
    : saved = List.of(heroes),
      super(HeroDatabase());
  @override
  Future<List<Hero>> getMembers() async => List.of(saved);
  @override
  Future<int> dismissMember(int heroId) async {
    if (fail) throw StateError('Falha ao excluir');
    final previous = saved.length;
    saved.removeWhere((hero) => hero.id == heroId);
    return previous - saved.length;
  }
}

void main() {
  final json =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map)['heroes']
          as List;
  final catalog = json
      .map((data) => Hero.fromJson(data as Map<String, dynamic>))
      .toList();

  test('Destaque considera apenas os seis atributos e escolhe o maior', () {
    final hero = Hero.fromJson({
      'id': 1,
      'powerstats': {
        'intelligence': 10,
        'strength': 20,
        'speed': 30,
        'durability': 40,
        'power': 50,
        'combat': 95,
        'extra': 999,
      },
    });
    expect(hero.strongestPowerstat!.key, 'combat');
    expect(hero.strongestPowerstat!.value, 95);
  });

  test('Destaque trata empate, zero e informações ausentes', () {
    expect(
      Hero.fromJson({
        'id': 1,
        'powerstats': {'intelligence': 100, 'strength': 100},
      }).strongestPowerstat!.key,
      'intelligence',
    );
    expect(
      Hero.fromJson({
        'id': 1,
        'powerstats': {'strength': 0},
      }).strongestPowerstat!.value,
      0,
    );
    expect(
      Hero.fromJson({
        'id': 1,
        'powerstats': {'strength': null, 'power': '-'},
      }).strongestPowerstat,
      isNull,
    );
  });

  test(
    'Dispensa atualiza os membros, libera vaga e notifica a interface',
    () async {
      final repository = MemorySquadRepository(catalog.take(15).toList());
      final provider = SquadProvider(repository, HeroRepository());
      addTearDown(provider.dispose);
      var notifications = 0;
      provider.addListener(() => notifications++);
      await provider.loadMembers();
      provider.dailyHero = catalog.first;
      expect(provider.isFull, isTrue);
      expect(await provider.dismissMember(catalog.first.id), isTrue);
      expect(provider.members.length, 14);
      expect(provider.isFull, isFalse);
      expect(provider.alreadyRecruited, isFalse);
      expect(provider.canRecruit, isTrue);
      expect(notifications, greaterThanOrEqualTo(4));
    },
  );

  test('Falha na dispensa conserva os membros e informa o erro', () async {
    final repository = MemorySquadRepository(catalog.take(2).toList())
      ..fail = true;
    final provider = SquadProvider(repository, HeroRepository());
    addTearDown(provider.dispose);
    await provider.loadMembers();
    expect(await provider.dismissMember(catalog.first.id), isFalse);
    expect(provider.members.length, 2);
    expect(provider.dismissing, isFalse);
    expect(provider.dismissalError, isNotNull);
  });
}
