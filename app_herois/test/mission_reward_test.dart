import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_herois/models/hero.dart' as model;
import 'package:app_herois/models/mission_round_result.dart';
import 'package:app_herois/providers/mission_provider.dart';
import 'package:app_herois/providers/squad_provider.dart';
import 'package:app_herois/widgets/hero_powerstats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';

import 'mission_test.dart' show LocalHeroes, LocalSquad, SequenceRandom;

class RewardSquad extends LocalSquad {
  int calls = 0;
  int writes = 0;
  bool failReward = false;
  Completer<void>? gate;
  RewardSquad(super.saved);

  @override
  Future<model.Hero> improveAttribute(int heroId, String attribute) async {
    calls++;
    if (gate != null) await gate!.future;
    if (failReward) throw StateError('Falha simulada na gravação');
    final index = saved.indexWhere((hero) => hero.id == heroId);
    final hero = saved[index];
    final stats = Map<String, dynamic>.from(hero.powerstats);
    stats[attribute] = (stats[attribute] as int) + 1;
    final updated = model.Hero.fromJson({
      ...hero.toJson(),
      'powerstats': stats,
    });
    saved[index] = updated;
    writes++;
    return updated;
  }
}

class RewardRandom extends SequenceRandom {
  final List<int> bounds = [];
  RewardRandom(super.values);

  @override
  int nextInt(int max) {
    bounds.add(max);
    return super.nextInt(max);
  }
}

List<model.Hero> membersFor(
  List<model.Hero> catalog,
  List<CombatOutcome> outcomes,
  model.Hero enemy,
) {
  final members = <model.Hero>[];
  final value = enemy.powerstats['combat'] as int;
  for (final outcome in outcomes) {
    members.add(
      catalog.firstWhere((hero) {
        if (hero.id == enemy.id ||
            members.any((member) => member.id == hero.id)) {
          return false;
        }
        final stat = hero.powerstats['combat'] as int;
        return switch (outcome) {
          CombatOutcome.victory => stat > value,
          CombatOutcome.defeat => stat < value,
          CombatOutcome.draw => stat == value,
        };
      }),
    );
  }
  members.addAll(
    catalog
        .where(
          (hero) =>
              hero.id != enemy.id &&
              !members.any((member) => member.id == hero.id),
        )
        .take(5 - members.length),
  );
  return members;
}

void completeMission(MissionProvider mission, List<model.Hero> members) {
  final total = mission.totalRounds;
  for (var n = 0; n < total; n++) {
    mission.selectAgent(members[n].id);
    expect(mission.confirmAgent(), isNotNull);
    mission.advanceRound();
  }
}

void main() {
  final data =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map)['heroes']
          as List;
  final catalog =
      data
          .map((row) => model.Hero.fromJson(row as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final enemy = catalog.firstWhere((hero) => hero.powerstats['combat'] == 50);
  const win = CombatOutcome.victory;
  const loss = CombatOutcome.defeat;
  const draw = CombatOutcome.draw;
  final scenarios = <List<CombatOutcome>>[
    [win, win, loss],
    [loss, loss, win],
    [win, loss, draw],
    [draw, draw, draw],
    [win, win, loss, draw],
    [loss, loss, win, draw],
    [win, win, win, loss, draw],
    [win, win, win],
    [win, win, win, loss],
    [win, win, loss, loss],
    [win, loss, loss, loss],
    [win, win, win, loss, loss],
    [win, win, loss, loss, loss],
    [win, win, loss, loss, draw],
    [win, win, loss, draw, draw],
  ];
  final expected = [
    MissionOutcome.success,
    MissionOutcome.failure,
    MissionOutcome.neutral,
    MissionOutcome.neutral,
    MissionOutcome.neutral,
    MissionOutcome.neutral,
    MissionOutcome.success,
    MissionOutcome.success,
    MissionOutcome.success,
    MissionOutcome.neutral,
    MissionOutcome.failure,
    MissionOutcome.success,
    MissionOutcome.failure,
    MissionOutcome.neutral,
    MissionOutcome.neutral,
  ];

  for (var n = 0; n < scenarios.length; n++) {
    final scenario = scenarios[n];
    final victories = scenario.where((result) => result == win).length;
    final defeats = scenario.where((result) => result == loss).length;
    final draws = scenario.where((result) => result == draw).length;
    test('Maioria: ${scenario.length} rounds, $victories vitórias, '
        '$defeats derrotas, $draws empates → ${expected[n].name}', () async {
      final members = membersFor(catalog, scenarios[n], enemy);
      final squad = RewardSquad(members);
      final mission = MissionProvider(
        LocalHeroes([enemy, ...members]),
        squad,
        random: SequenceRandom([
          scenarios[n].length - 3,
          for (var r = 0; r < scenarios[n].length; r++) ...[0, 5],
          0,
          0,
        ]),
      );
      addTearDown(mission.dispose);
      expect(await mission.finalizeMission(), isFalse);
      await mission.startMission();
      completeMission(mission, members);
      expect(mission.results.map((result) => result.outcome), scenario);
      expect(mission.victories, victories);
      expect(mission.defeats, defeats);
      expect(mission.draws, draws);
      expect(mission.outcome, expected[n]);
      expect(await mission.finalizeMission(), isTrue);
      expect(mission.finalized, isTrue);
      expect(squad.writes, expected[n] == MissionOutcome.success ? 1 : 0);
      expect(
        mission.rewardedAgent == null,
        expected[n] != MissionOutcome.success,
      );
    });
  }

  test('Só finaliza após confirmar e encerrar todos os rounds', () async {
    final members = membersFor(catalog, [win, win, loss], enemy);
    final squad = RewardSquad(members);
    final mission = MissionProvider(
      LocalHeroes([enemy, ...members]),
      squad,
      random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 0, 1]),
    );
    addTearDown(mission.dispose);
    await mission.startMission();
    for (var round = 0; round < 3; round++) {
      expect(mission.outcome, isNull);
      expect(await mission.finalizeMission(), isFalse);
      mission.selectAgent(members[round].id);
      mission.confirmAgent();
      expect(await mission.finalizeMission(), isFalse);
      expect(squad.writes, 0);
      mission.advanceRound();
    }
    expect(mission.completed, isTrue);
    expect(await mission.finalizeMission(), isTrue);
    expect(squad.writes, 1);
  });

  test('Sorteio inclui todos os vencedores e exclui derrotados, empates e ausentes', () async {
    for (final scenario in [
      [loss, win, win],
      [loss, win, draw, win, win],
    ]) {
      final members = membersFor(catalog, scenario, enemy);
      final winners = [
        for (var index = 0; index < scenario.length; index++)
          if (scenario[index] == win) members[index],
      ];
      for (var winnerIndex = 0; winnerIndex < winners.length; winnerIndex++) {
        final squad = RewardSquad(List.of(members));
        final random = RewardRandom([
          scenario.length - 3,
          for (var round = 0; round < scenario.length; round++) ...[0, 5],
          winnerIndex,
          0,
        ]);
        final mission = MissionProvider(
          LocalHeroes([enemy, ...members]),
          squad,
          random: random,
        );
        addTearDown(mission.dispose);
        await mission.startMission();
        completeMission(mission, members);
        expect(
          mission.victoriousAgents.map((hero) => hero.id),
          winners.map((hero) => hero.id),
        );
        await mission.finalizeMission();
        expect(random.bounds.sublist(random.bounds.length - 2), [
          winners.length,
          6,
        ]);
        expect(mission.rewardedAgent!.id, winners[winnerIndex].id);
        expect(squad.writes, 1);
      }
    }
  });

  test(
    'Gravação pendente termina sem notificar o Provider descartado',
    () async {
      final members = membersFor(catalog, [win, win, loss], enemy);
      final squad = RewardSquad(members)..gate = Completer<void>();
      var updates = 0;
      var notifications = 0;
      final mission = MissionProvider(
        LocalHeroes([enemy, ...members]),
        squad,
        onMemberUpdated: (_) => updates++,
        random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 0, 1]),
      );
      await mission.startMission();
      completeMission(mission, members);
      mission.addListener(() => notifications++);
      final saving = mission.finalizeMission();
      expect(notifications, 1);
      mission.dispose();
      squad.gate!.complete();
      expect(await saving, isTrue);
      expect(squad.writes, 1);
      expect(notifications, 1);
      expect(updates, 0);
      expect(await mission.finalizeMission(), isFalse);
    },
  );

  test(
    'Somente vencedores são sorteados; exatamente um atributo ganha +1',
    () async {
      for (var attributeIndex = 0; attributeIndex < 6; attributeIndex++) {
        final members = membersFor(catalog, [win, win, loss], enemy);
        final squad = RewardSquad(members);
        final before = squad.saved
            .map((hero) => jsonEncode(hero.toJson()))
            .toList();
        final mission = MissionProvider(
          LocalHeroes([enemy, ...members]),
          squad,
          random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 1, attributeIndex]),
        );
        addTearDown(mission.dispose);
        await mission.startMission();
        completeMission(mission, members);
        await mission.finalizeMission();
        expect(mission.rewardedAgent!.id, members[1].id);
        final key = MissionProvider.attributes[attributeIndex];
        expect(mission.rewardAttribute, key);
        final oldJson = jsonDecode(before[1]) as Map<String, dynamic>;
        (oldJson['powerstats'] as Map)[key] =
            (oldJson['powerstats'] as Map)[key] + 1;
        expect(mission.rewardedAgent!.toJson(), oldJson);
        for (var index = 0; index < members.length; index++) {
          if (index != 1) {
            expect(jsonEncode(squad.saved[index].toJson()), before[index]);
          }
        }
        await mission.finalizeMission();
        mission.markFeedbackShown();
        mission.markFeedbackShown();
        await mission.finalizeMission();
        expect(squad.writes, 1);
        expect(mission.feedbackShown, isTrue);
      }
    },
  );

  test('Confirmações concorrentes e nova missão durante gravação não duplicam a recompensa', () async {
    final members = membersFor(catalog, [win, win, loss], enemy);
    final squad = RewardSquad(members)..gate = Completer<void>();
    final mission = MissionProvider(
      LocalHeroes([enemy, ...members]),
      squad,
      random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 0, 1]),
    );
    addTearDown(mission.dispose);
    await mission.startMission();
    completeMission(mission, members);
    final first = mission.finalizeMission();
    expect(mission.finalizing, isTrue);
    expect(await mission.finalizeMission(), isFalse);
    expect(await mission.startMission(), isFalse);
    await mission.loadMembers();
    expect(mission.completed, isTrue);
    squad.gate!.complete();
    expect(await first, isTrue);
    expect(squad.calls, 1);
    expect(squad.writes, 1);
    expect(mission.finalizing, isFalse);
  });

  test(
    'Falha permite repetir o mesmo sorteio e só confirma após persistir',
    () async {
      final members = membersFor(catalog, [win, win, loss], enemy);
      final squad = RewardSquad(members)..failReward = true;
      final random = SequenceRandom([0, 0, 5, 0, 5, 0, 5, 1, 4]);
      final mission = MissionProvider(
        LocalHeroes([enemy, ...members]),
        squad,
        random: random,
      );
      addTearDown(mission.dispose);
      await mission.startMission();
      completeMission(mission, members);
      expect(await mission.finalizeMission(), isFalse);
      final consumed = random.index;
      expect(mission.rewardedAgent, isNull);
      expect(mission.rewardError, contains('salvar'));
      expect(mission.rewardAttribute, 'power');
      expect(squad.writes, 0);
      squad.failReward = false;
      expect(await mission.finalizeMission(), isTrue);
      expect(random.index, consumed);
      expect(mission.rewardedAgent!.id, members[1].id);
      expect(mission.rewardError, isNull);
      expect(squad.writes, 1);
    },
  );

  test('Provider atualiza o esquadrão; nova missão limpa o estado e permite outra recompensa', () async {
    final members = membersFor(catalog, [win, win, loss], enemy);
    final squad = RewardSquad(members);
    final heroes = LocalHeroes([enemy, ...members]);
    final squadProvider = SquadProvider(squad, heroes);
    addTearDown(squadProvider.dispose);
    await squadProvider.loadMembers();
    var updates = 0;
    squadProvider.addListener(() => updates++);
    final mission = MissionProvider(
      heroes,
      squad,
      onMemberUpdated: squadProvider.updateMember,
      random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 0, 1]),
    );
    addTearDown(mission.dispose);
    final originalStrength = members.first.powerstats['strength'] as int;
    for (var run = 1; run <= 2; run++) {
      await mission.startMission();
      expect(mission.finalized, isFalse);
      expect(mission.feedbackShown, isFalse);
      expect(mission.rewardedAgent, isNull);
      expect(mission.rewardAttribute, isNull);
      expect(mission.results, isEmpty);
      completeMission(mission, members);
      await mission.finalizeMission();
      mission.markFeedbackShown();
      expect(
        squadProvider.members.first.powerstats['strength'],
        originalStrength + run,
      );
      expect(
        mission.members.first.powerstats['strength'],
        originalStrength + run,
      );
      expect(squad.writes, run);
    }
    expect(updates, 2);
  });

  test('A evolução 100 → 101 é usada em um confronto posterior', () async {
    final members = membersFor(catalog, [win, win, loss], enemy);
    expect(members.first.powerstats['strength'], 100);
    final squad = RewardSquad(members);
    final mission = MissionProvider(
      LocalHeroes([enemy, ...members]),
      squad,
      random: SequenceRandom([0, 0, 5, 0, 5, 0, 5, 0, 1]),
    );
    addTearDown(mission.dispose);
    await mission.startMission();
    completeMission(mission, members);
    await mission.finalizeMission();
    final opponent = catalog.firstWhere(
      (hero) =>
          hero.powerstats['strength'] == 100 &&
          !members.any((member) => member.id == hero.id),
    );
    final next = MissionProvider(
      LocalHeroes([opponent, ...members]),
      squad,
      random: SequenceRandom([0, 0, 1]),
    );
    addTearDown(next.dispose);
    await next.startMission();
    next.selectAgent(members.first.id);
    final result = next.confirmAgent()!;
    expect(result.agentValue, 101);
    expect(result.enemyValue, 100);
    expect(result.outcome, CombatOutcome.victory);
    expect(catalog.first.powerstats['strength'], 100);
  });

  testWidgets('PrimerProgressBar exibe o valor evoluído acima de 100', (
    tester,
  ) async {
    final hero = catalog.first;
    final updated = model.Hero.fromJson({
      ...hero.toJson(),
      'powerstats': {...hero.powerstats, 'strength': 101},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HeroPowerstats(hero: updated)),
        ),
      ),
    );
    final bar = tester.widget<PrimerProgressBar>(
      find.byKey(const ValueKey('stat-strength')),
    );
    expect(bar.maxTotalValue, 101);
    expect(bar.segments.single.value, 101);
    expect(find.text('Força (strength): 101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
