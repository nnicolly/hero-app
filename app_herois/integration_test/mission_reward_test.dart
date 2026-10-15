import 'dart:io';

import 'package:app_herois/data/hero_api.dart';
import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart' as model;
import 'package:app_herois/models/mission_round_result.dart';
import 'package:app_herois/providers/mission_provider.dart';
import 'package:app_herois/providers/squad_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:app_herois/screens/home_screen.dart';
import 'package:app_herois/screens/mission_battle_screen.dart';
import 'package:app_herois/widgets/hero_details_content.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../test/mission_reward_test.dart' show membersFor;
import '../test/mission_test.dart' show SequenceRandom;
import 'catalog_test.dart' show CheckedOfflineApi;
import 'helpers/review_capture.dart';

Future<void> playMission(
  WidgetTester tester,
  MissionProvider mission,
  List<model.Hero> members,
) async {
  for (var round = 0; round < mission.totalRounds; round++) {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('battle-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    final card = find.byKey(ValueKey('mission-agent-${members[round].id}'));
    await tester.scrollUntilVisible(card, 200, scrollable: scrollable);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('confirm-agent')),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-agent')));
    await tester.pumpAndSettle();
    expect(mission.currentRound, round + 1);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Feedback final, recompensa única, persistência e evolução offline no A55',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Validando recompensas…'))),
      );
      const filename = 'mission_reward_validation.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      var database = HeroDatabase(filename: filename);
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
      });
      final catalog = await HeroApi().fetchAll();
      catalog.sort((a, b) => a.id.compareTo(b.id));
      expect(catalog.length, 563);
      await database.saveCatalog(catalog);
      final original = catalog.map((hero) => hero.toJson()).toList();
      final enemy = catalog.firstWhere(
        (hero) => hero.powerstats['combat'] == 50,
      );
      const win = CombatOutcome.victory;
      const loss = CombatOutcome.defeat;
      const draw = CombatOutcome.draw;
      final scenarios = [
        [win, win, loss],
        [loss, loss, win],
        [win, loss, draw],
      ];
      final types = [DialogType.success, DialogType.error, DialogType.info];
      for (var scenario = 0; scenario < scenarios.length; scenario++) {
        final api = CheckedOfflineApi();
        final heroes = HeroRepository(api: api, database: database);
        final squad = SquadRepository(database);
        for (final member in await squad.getMembers()) {
          await squad.dismissMember(member.id);
        }
        final members = membersFor(catalog, scenarios[scenario], enemy);
        for (final hero in members) {
          await squad.recruit(hero);
        }
        final before = (await squad.getMembers())
            .map((hero) => hero.toJson())
            .toList();
        final eligible = catalog
            .where((hero) => !members.any((member) => member.id == hero.id))
            .toList();
        final enemyIndex = eligible.indexWhere((hero) => hero.id == enemy.id);
        final squadProvider = SquadProvider(squad, heroes);
        await squadProvider.loadMembers();
        final mission = MissionProvider(
          heroes,
          squad,
          onMemberUpdated: squadProvider.updateMember,
          random: SequenceRandom([
            0,
            enemyIndex,
            5,
            enemyIndex,
            5,
            enemyIndex,
            5,
            0,
            1,
          ]),
        );
        Widget app({bool rebuild = false}) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: squadProvider),
            ChangeNotifierProvider.value(value: mission),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorSchemeSeed: rebuild ? Colors.blue : Colors.teal,
            ),
            home: const HomeScreen(),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Missões'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('start-mission')));
        await tester.pumpAndSettle();
        await playMission(tester, mission, members);
        expect(
          tester
              .widget<AwesomeDialogHeader>(find.byType(AwesomeDialogHeader))
              .dialogType,
          types[scenario],
        );
        final feedback = find.byKey(const ValueKey('mission-final-feedback'));
        expect(
          find.descendant(
            of: feedback,
            matching: find.text(mission.finalLabel),
          ),
          findsOneWidget,
        );
        expect(mission.finalized, isTrue);
        expect(mission.feedbackShown, isTrue);
        await reviewCapture(tester, 'reward_$scenario');
        expect(
          [mission.victories, mission.defeats, mission.draws],
          scenario == 0
              ? [2, 1, 0]
              : scenario == 1
              ? [1, 2, 0]
              : [1, 1, 1],
        );
        if (scenario == 0) {
          expect(mission.rewardedAgent!.id, members.first.id);
          expect(mission.rewardAttribute, 'strength');
          expect(mission.rewardedAgent!.powerstats['strength'], 101);
          expect(
            squadProvider.members
                .firstWhere((hero) => hero.id == members.first.id)
                .powerstats['strength'],
            101,
          );
          expect(
            tester
                .widget<CachedNetworkImage>(
                  find.byKey(const ValueKey('mission-feedback-image')),
                )
                .imageUrl,
            members.first.largeImage,
          );
          expect(
            find.descendant(
              of: feedback,
              matching: find.textContaining('100 → 101 (+1 permanente)'),
            ),
            findsOneWidget,
          );
        } else {
          expect(mission.rewardedAgent, isNull);
          expect(
            (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
            before,
          );
          if (scenario == 1) {
            expect(
              find.byKey(const ValueKey('mission-feedback-image')),
              findsOneWidget,
            );
          }
        }
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        final rewardedSnapshot = (await squad.getMembers())
            .map((hero) => hero.toJson())
            .toList();
        for (final old in before) {
          final saved = rewardedSnapshot.firstWhere(
            (hero) => hero['id'] == old['id'],
          );
          if (old['id'] == mission.rewardedAgent?.id) {
            final expected = {
              ...old,
              'powerstats': {
                ...old['powerstats'] as Map,
                'strength': (old['powerstats'] as Map)['strength'] + 1,
              },
            };
            expect(saved, expected);
          } else {
            expect(saved, old);
          }
        }
        // Reconstruir e reabrir o feedback não pode conceder outra recompensa.
        await tester.pumpWidget(app(rebuild: true));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mission-final-feedback')),
          findsNothing,
        );
        await tester.tap(find.text('Ver resultado'));
        await tester.pumpAndSettle();
        await mission.finalizeMission();
        await mission.finalizeMission();
        expect(
          (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
          rewardedSnapshot,
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        if (scenario == 0) {
          await tester.tap(find.text('Nova Missão'));
          await tester.pumpAndSettle();
          expect(find.byType(MissionBattleScreen), findsOneWidget);
          expect(mission.currentRound, 1);
          expect(mission.results, isEmpty);
          expect(mission.rewardedAgent, isNull);
          expect(mission.feedbackShown, isFalse);
          await playMission(tester, mission, members);
          expect(mission.rewardedAgent!.powerstats['strength'], 102);
          await tester.tap(find.text('Continuar'));
          await tester.pumpAndSettle();

          // Sincronizar ou recrutar não deve substituir os atributos do membro.
          final evolved = (await squad.getMembers())
              .map((hero) => hero.toJson())
              .toList();
          final onlineHeroes = HeroRepository(database: database);
          expect(await onlineHeroes.synchronize(), 563);
          expect(
            (await onlineHeroes.getById(members.first.id))
                .powerstats['strength'],
            100,
          );
          expect(
            await squad.recruit(
              catalog.firstWhere((hero) => hero.id == members.first.id),
            ),
            RecruitmentResult.alreadyRecruited,
          );
          expect(
            (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
            evolved,
          );
          final other = catalog.firstWhere(
            (hero) => !members.any((member) => member.id == hero.id),
          );
          expect(await squad.recruit(other), RecruitmentResult.recruited);
          expect(
            (await squad.getMembers())
                .firstWhere((hero) => hero.id == members.first.id)
                .powerstats['strength'],
            102,
          );
          await squad.dismissMember(other.id);
          expect(
            (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
            evolved,
          );
        }
        expect(await heroes.countCachedHeroes(), 563);
        expect(
          (await heroes.getPage(
            limit: 563,
            offset: 0,
          )).map((hero) => hero.toJson()).toList(),
          original,
        );
        expect((await squad.getMembers()).length, 5);
        expect(api.requests, 0);
        expect(tester.takeException(), isNull);

        final navigationSnapshot = (await squad.getMembers())
            .map((hero) => hero.toJson())
            .toList();
        await tester.tap(find.text('Voltar para Missões'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Missões'));
        await tester.pumpAndSettle();
        expect(mission.completed, isFalse);
        expect(mission.results, isEmpty);
        expect(mission.rewardedAgent, isNull);
        expect(await mission.finalizeMission(), isFalse);
        expect(
          (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
          navigationSnapshot,
        );
        await tester.pumpWidget(const SizedBox());
        mission.dispose();
        squadProvider.dispose();
        // Simula reinicialização: fecha SQLite, descarta Providers e reabre o mesmo arquivo.
        await database.close();
        if (scenario == 0) {
          // Cópia exclusiva do pacote de validação para conferir reinício real
          // do processo Android depois que o runner terminar.
          await File(path)
              .copy(join(dirname(path), 'mission_reward_restart_snapshot.db'));
        }
        database = HeroDatabase(filename: filename);
        if (scenario == 0) {
          final reopenedApi = CheckedOfflineApi();
          final reopenedHeroes = HeroRepository(
            api: reopenedApi,
            database: database,
          );
          final reopenedSquad = SquadRepository(database);
          final reopenedProvider = SquadProvider(reopenedSquad, reopenedHeroes);
          final saved = (await reopenedSquad.getMembers()).firstWhere(
            (hero) => hero.id == members.first.id,
          );
          expect(saved.powerstats['strength'], 102);
          expect((await database.database).getVersion(), completion(2));
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: reopenedProvider,
              child: const MaterialApp(home: HomeScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Meu Esquadrão'));
          await tester.pumpAndSettle();
          expect(find.text('Destaque: Força (102)'), findsOneWidget);
          await tester.tap(find.byKey(ValueKey('squad-${saved.id}')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('stat-strength')),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          final bar = tester.widget<PrimerProgressBar>(
            find.byKey(const ValueKey('stat-strength')),
          );
          expect(bar.segments.single.value, 102);
          expect(bar.maxTotalValue, 102);
          await reviewCapture(tester, 'evolved_details');
          expect(
            tester
                .widget<HeroDetailsContent>(find.byType(HeroDetailsContent))
                .hero
                .toJson(),
            saved.toJson(),
          );
          final strongEnemy = catalog.firstWhere(
            (hero) =>
                hero.powerstats['strength'] == 100 &&
                !members.any((member) => member.id == hero.id),
          );
          final strongIndex = eligible.indexWhere(
            (hero) => hero.id == strongEnemy.id,
          );
          final next = MissionProvider(
            reopenedHeroes,
            reopenedSquad,
            random: SequenceRandom([0, strongIndex, 1]),
          );
          await next.startMission();
          next.selectAgent(saved.id);
          final result = next.confirmAgent()!;
          expect(result.agentValue, 102);
          expect(result.enemyValue, 100);
          expect(result.outcome, CombatOutcome.victory);
          next.dispose();
          expect(reopenedApi.requests, 0);
          await tester.pumpWidget(const SizedBox());
          reopenedProvider.dispose();
        }
      }
      // Validações inválidas não inserem agentes nem alteram o catálogo.
      final squad = SquadRepository(database);
      final finalMembers = (await squad.getMembers())
          .map((hero) => hero.toJson())
          .toList();
      await expectLater(
        squad.improveAttribute(-1, 'strength'),
        throwsStateError,
      );
      await expectLater(
        squad.improveAttribute(finalMembers.first['id'] as int, 'extra'),
        throwsArgumentError,
      );
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        finalMembers,
      );
      expect(
        (await database.getPage(
          limit: 563,
          offset: 0,
        )).map((hero) => hero.toJson()).toList(),
        original,
      );
    },
  );

  testWidgets(
    'Falha real no SQLite não anuncia bônus; repetir salva uma única vez',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Validando falha de recompensa…')),
        ),
      );
      final directory = await getDatabasesPath();
      expect(directory, contains('com.example.app_herois.validation'));
      final path = join(directory, 'mission_reward_failure_validation.db');
      await deleteDatabase(path);
      final database = HeroDatabase(
        filename: 'mission_reward_failure_validation.db',
      );
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
      });
      final catalog = await HeroApi().fetchAll()
        ..sort((a, b) => a.id.compareTo(b.id));
      await database.saveCatalog(catalog);
      final enemy = catalog.firstWhere(
        (hero) => hero.powerstats['combat'] == 50,
      );
      final members = membersFor(catalog, [
        CombatOutcome.victory,
        CombatOutcome.victory,
        CombatOutcome.defeat,
      ], enemy);
      final squad = SquadRepository(database);
      for (final member in members) {
        await squad.recruit(member);
      }
      final before = (await squad.getMembers())
          .map((hero) => hero.toJson())
          .toList();
      final api = CheckedOfflineApi();
      final heroes = HeroRepository(api: api, database: database);
      final squadProvider = SquadProvider(squad, heroes);
      await squadProvider.loadMembers();
      final eligible = catalog
          .where((hero) => !members.any((member) => member.id == hero.id))
          .toList();
      final enemyIndex = eligible.indexWhere((hero) => hero.id == enemy.id);
      final random = SequenceRandom([
        0,
        enemyIndex,
        5,
        enemyIndex,
        5,
        enemyIndex,
        5,
        0,
        1,
      ]);
      final mission = MissionProvider(
        heroes,
        squad,
        random: random,
        onMemberUpdated: squadProvider.updateMember,
      );
      final db = await database.database;
      // O gatilho pertence somente ao banco isolado e força rollback do update.
      await db.execute(
        "CREATE TRIGGER review_fail_reward BEFORE UPDATE ON squad_members BEGIN SELECT RAISE(ABORT, 'Falha de teste'); END",
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: squadProvider),
            ChangeNotifierProvider.value(value: mission),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missões'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-mission')));
      await tester.pumpAndSettle();
      await playMission(tester, mission, members);
      final drawsConsumed = random.index;
      expect(mission.completed, isTrue);
      expect(mission.finalized, isFalse);
      expect(mission.rewardedAgent, isNull);
      expect(mission.feedbackShown, isFalse);
      expect(
        find.byKey(const ValueKey('mission-final-feedback')),
        findsNothing,
      );
      expect(
        find.textContaining('Não foi possível salvar a recompensa'),
        findsOneWidget,
      );
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        before,
      );
      expect(
        squadProvider.members.map((hero) => hero.toJson()).toList(),
        before,
      );
      await reviewCapture(tester, 'reward_failure');
      await tester.tap(find.text('Salvar recompensa novamente'));
      await tester.pumpAndSettle();
      expect(mission.finalized, isFalse);
      expect(random.index, drawsConsumed);
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        before,
      );
      await db.execute('DROP TRIGGER review_fail_reward');
      await tester.tap(find.text('Salvar recompensa novamente'));
      await tester.tap(find.text('Salvar recompensa novamente'));
      await tester.pumpAndSettle();
      expect(mission.finalized, isTrue);
      expect(mission.rewardError, isNull);
      expect(mission.rewardedAgent!.id, members.first.id);
      expect(mission.rewardedAgent!.powerstats['strength'], 101);
      expect(random.index, drawsConsumed);
      expect(
        find.byKey(const ValueKey('mission-final-feedback')),
        findsOneWidget,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final saved = (await squad.getMembers())
          .map((hero) => hero.toJson())
          .toList();
      await mission.finalizeMission();
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        saved,
      );
      expect(api.requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      mission.dispose();
      squadProvider.dispose();
    },
  );
}
