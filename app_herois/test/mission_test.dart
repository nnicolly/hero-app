import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart';
import 'package:app_herois/models/mission_round_result.dart';
import 'package:app_herois/providers/mission_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class LocalHeroes extends HeroRepository {
  final List<Hero> catalog;
  bool fail = false;
  LocalHeroes(this.catalog);
  @override
  Future<int> countCachedHeroes() async {
    if (fail) throw StateError('Falha local');
    return catalog.length;
  }

  @override
  Future<List<Hero>> getPage({required int limit, required int offset}) async =>
      catalog.skip(offset).take(limit).toList();
}

class LocalSquad extends SquadRepository {
  final List<Hero> saved;
  bool fail = false;
  LocalSquad(this.saved) : super(HeroDatabase());
  @override
  Future<List<Hero>> getMembers() async {
    if (fail) throw StateError('Falha local');
    return List.of(saved);
  }
}

class SequenceRandom implements Random {
  final List<int> values;
  int index = 0;
  SequenceRandom(this.values);
  @override
  int nextInt(int max) {
    final value = values[index++ % values.length];
    assert(value >= 0 && value < max);
    return value;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final rows =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map)['heroes']
          as List;
  final catalog =
      rows.map((row) => Hero.fromJson(row as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  test('Bloqueia menos de cinco, catálogo vazio e erros locais; permite tentar novamente', () async {
    final squad = LocalSquad(catalog.take(4).toList());
    final heroes = LocalHeroes(catalog);
    final mission = MissionProvider(heroes, squad, random: SequenceRandom([0]));
    addTearDown(mission.dispose);
    await mission.loadMembers();
    expect(mission.canStart, isFalse);
    expect(await mission.startMission(), isFalse);
    expect(mission.error, contains('5 agentes'));
    squad.saved.add(catalog[4]);
    heroes.fail = true;
    expect(await mission.startMission(), isFalse);
    expect(mission.error, contains('dados locais'));
    expect(mission.loading, isFalse);
    heroes.fail = false;
    expect(await mission.startMission(), isTrue);
    await mission.loadMembers();
    squad.fail = true;
    await mission.loadMembers();
    expect(mission.error, contains('esquadrão'));
    expect(mission.canStart, isFalse);
    final empty = MissionProvider(
      LocalHeroes([]),
      LocalSquad(catalog.take(5).toList()),
    );
    addTearDown(empty.dispose);
    expect(await empty.startMission(), isFalse);
    expect(empty.error, contains('sincronize'));
  });

  for (final rounds in [3, 4, 5]) {
    test(
      '$rounds rounds, exclusão do esquadrão, uso único, placar e reinicialização',
      () async {
        final squad = LocalSquad(catalog.take(15).toList());
        final original = catalog
            .map((hero) => jsonEncode(hero.toJson()))
            .toList();
        final saved = squad.saved
            .map((hero) => jsonEncode(hero.toJson()))
            .toList();
        final sequence = [
          rounds - 3,
          for (var n = 0; n < rounds; n++) ...[0, n % 6],
        ];
        final mission = MissionProvider(
          LocalHeroes(catalog),
          squad,
          random: SequenceRandom(sequence),
        );
        addTearDown(mission.dispose);
        var notifications = 0;
        mission.addListener(() => notifications++);
        expect(await mission.startMission(), isTrue);
        expect(await mission.startMission(), isFalse);
        expect(mission.totalRounds, rounds);
        for (var round = 1; round <= rounds; round++) {
          expect(mission.currentRound, round);
          expect(MissionProvider.attributes, contains(mission.attribute));
          expect(
            squad.saved.any((hero) => hero.id == mission.enemy!.id),
            isFalse,
          );
          expect(mission.confirmAgent(), isNull);
          mission.selectAgent(-1);
          expect(mission.selectedAgent, isNull);
          if (round > 1) {
            mission.selectAgent(squad.saved.first.id);
            expect(mission.selectedAgent, isNull);
          }
          mission.selectAgent(squad.saved[round - 1].id);
          expect(mission.canConfirm, isTrue);
          final agentValue =
              mission.selectedAgent!.powerstats[mission.attribute] as int;
          final enemyValue =
              mission.enemy!.powerstats[mission.attribute] as int;
          final result = mission.confirmAgent()!;
          expect(
            result.outcome,
            agentValue > enemyValue
                ? CombatOutcome.victory
                : agentValue < enemyValue
                ? CombatOutcome.defeat
                : CombatOutcome.draw,
          );
          expect(mission.confirmAgent(), isNull);
          expect(mission.results.length, round);
          expect(mission.victories + mission.defeats + mission.draws, round);
          expect(mission.isUsed(result.agent.id), isTrue);
          mission.advanceRound();
          final current = mission.currentRound;
          mission.advanceRound();
          expect(mission.currentRound, current);
        }
        expect(mission.completed, isTrue);
        expect(mission.canConfirm, isFalse);
        expect(
          mission.victoriousAgents.map((hero) => hero.id),
          mission.results
              .where((r) => r.outcome == CombatOutcome.victory)
              .map((r) => r.agent.id),
        );
        expect(
          squad.saved.map((hero) => jsonEncode(hero.toJson())).toList(),
          saved,
        );
        expect(
          catalog.map((hero) => jsonEncode(hero.toJson())).toList(),
          original,
        );
        expect(await mission.startMission(), isTrue);
        expect(mission.currentRound, 1);
        expect(mission.results, isEmpty);
        expect(mission.victories + mission.defeats + mission.draws, 0);
        expect(mission.isUsed(squad.saved.first.id), isFalse);
        expect(notifications, greaterThan(rounds * 2));
      },
    );
  }

  test(
    'Os seis atributos resolvem vitória, derrota e empate por valores reais',
    () async {
      for (var stat = 0; stat < 6; stat++) {
        final key = MissionProvider.attributes[stat];
        final enemy = catalog.firstWhere(
          (hero) =>
              (hero.powerstats[key] as int) > 0 &&
              (hero.powerstats[key] as int) < 100,
        );
        final value = enemy.powerstats[key] as int;
        final equal = catalog.firstWhere(
          (hero) => hero.id != enemy.id && hero.powerstats[key] == value,
        );
        final higher = catalog.firstWhere(
          (hero) => (hero.powerstats[key] as int) > value,
        );
        final lower = catalog.firstWhere(
          (hero) => (hero.powerstats[key] as int) < value,
        );
        final members = <Hero>[higher, lower, equal];
        members.addAll(
          catalog
              .where(
                (hero) =>
                    hero.id != enemy.id && !members.any((m) => m.id == hero.id),
              )
              .take(2),
        );
        final mission = MissionProvider(
          LocalHeroes([enemy, ...members]),
          LocalSquad(members),
          random: SequenceRandom([0, 0, stat, 0, stat, 0, stat]),
        );
        addTearDown(mission.dispose);
        expect(await mission.startMission(), isTrue);
        for (var n = 0; n < 3; n++) {
          mission.selectAgent(members[n].id);
          final result = mission.confirmAgent()!;
          expect(result.outcome, CombatOutcome.values[n]);
          expect(result.enemyValue, value);
          mission.advanceRound();
        }
        expect([mission.victories, mission.defeats, mission.draws], [1, 1, 1]);
        expect(mission.victoriousAgents.single.id, higher.id);
      }
    },
  );

  test('Atributo ausente não inventa um valor nem consome o agente', () async {
    final incomplete = Hero.fromJson({
      ...catalog.first.toJson(),
      'powerstats': {},
    });
    final members = [incomplete, ...catalog.skip(1).take(4)];
    final mission = MissionProvider(
      LocalHeroes(catalog),
      LocalSquad(members),
      random: SequenceRandom([0]),
    );
    addTearDown(mission.dispose);
    await mission.startMission();
    mission.selectAgent(incomplete.id);
    expect(mission.confirmAgent(), isNull);
    expect(mission.error, contains('não está informado'));
    expect(mission.isUsed(incomplete.id), isFalse);
    expect(mission.results, isEmpty);
  });

  test(
    'Sorteio com Random percorre as três durações e os seis atributos',
    () async {
      final durations = <int>{};
      final attributes = <String>{};
      final members = catalog.take(5).toList();
      final mission = MissionProvider(
        LocalHeroes(catalog),
        LocalSquad(members),
        random: Random(42),
      );
      addTearDown(mission.dispose);
      for (var run = 0; run < 40; run++) {
        await mission.loadMembers();
        await mission.startMission();
        durations.add(mission.totalRounds);
        attributes.add(mission.attribute!);
        expect(members.any((hero) => hero.id == mission.enemy!.id), isFalse);
      }
      expect(durations, {3, 4, 5});
      expect(attributes, MissionProvider.attributes.toSet());
    },
  );
}
