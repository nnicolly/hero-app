import 'dart:math';

import 'package:app_herois/data/hero_api.dart';
import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/providers/mission_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:app_herois/screens/home_screen.dart';
import 'package:app_herois/screens/mission_battle_screen.dart';
import 'package:app_herois/screens/missions_screen.dart';
import 'package:app_herois/widgets/hero_powerstats.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'catalog_test.dart' show CheckedOfflineApi;
import 'helpers/review_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Missão offline no SQLite: mínimo, grid, rounds, placar e reutilização',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Validando missões…'))),
      );
      const filename = 'mission_validation.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      final database = HeroDatabase(filename: filename);
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
      });
      final catalog = await HeroApi().fetchAll();
      catalog.sort((a, b) => a.id.compareTo(b.id));
      expect(catalog.length, 563);
      await database.saveCatalog(catalog);
      final api = CheckedOfflineApi();
      final heroes = HeroRepository(api: api, database: database);
      final squad = SquadRepository(database);
      for (final hero in catalog.take(4)) {
        await squad.recruit(hero);
      }
      final mission = MissionProvider(heroes, squad, random: Random(42));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: mission,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missões'));
      await tester.pumpAndSettle();
      expect(find.byType(MissionsScreen), findsOneWidget);
      expect(find.text('4 agentes no esquadrão.'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('start-mission')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Recrute pelo menos 5'), findsOneWidget);
      for (final hero in catalog.skip(4).take(11)) {
        await squad.recruit(hero);
      }
      final members = (await squad.getMembers())
          .map((hero) => hero.toJson())
          .toList();
      await tester.tap(find.text('Atualizar esquadrão'));
      await tester.pumpAndSettle();
      expect(find.text('15 agentes no esquadrão.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-mission')));
      await tester.pumpAndSettle();
      expect(find.byType(MissionBattleScreen), findsOneWidget);
      final total = mission.totalRounds;
      expect(total, inInclusiveRange(3, 5));
      await reviewCapture(tester, 'battle');
      for (var round = 1; round <= total; round++) {
        expect(find.text('Rodada $round de $total'), findsOneWidget);
        final enemy = mission.enemy!;
        final attribute = mission.attribute!;
        expect(mission.members.any((hero) => hero.id == enemy.id), isFalse);
        expect(MissionProvider.attributes, contains(attribute));
        expect(find.byType(HeroPowerstats), findsNothing);
        expect(
          find.text('${enemy.name}: ${enemy.powerstats[attribute]}'),
          findsNothing,
        );
        expect(find.textContaining('Atributo dominante:'), findsOneWidget);
        expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
              .imageUrl,
          enemy.largeImage,
        );
        final grid = tester.widget<GridView>(
          find.byKey(const ValueKey('mission-squad-grid')),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          3,
        );
        expect(grid.childrenDelegate.estimatedChildCount, 15);
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('battle-list')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('confirm-agent')),
          250,
          scrollable: scrollable,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('confirm-agent')),
              )
              .onPressed,
          isNull,
        );
        final agent = mission.members[round - 1];
        final card = find.byKey(ValueKey('mission-agent-${agent.id}'));
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(card, 200, scrollable: scrollable);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(mission.selectedAgent!.id, agent.id);
        if (round == 1) await reviewCapture(tester, 'battle_selected');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('confirm-agent')),
          250,
          scrollable: scrollable,
        );
        await tester.tap(find.byKey(const ValueKey('confirm-agent')));
        await tester.pumpAndSettle();
        final result = mission.lastResult!;
        expect(find.text('Rodada $round: ${result.label}'), findsOneWidget);
        expect(
          find.textContaining('${agent.name}: ${result.agentValue}'),
          findsOneWidget,
        );
        expect(mission.victories + mission.defeats + mission.draws, round);
        expect(mission.isUsed(agent.id), isTrue);
        expect(mission.confirmAgent(), isNull);
        expect(mission.results.length, round);
        expect(mission.currentRound, round);
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
        expect(mission.completed, round == total);
        if (round == total) {
          expect(
            find.byKey(const ValueKey('mission-final-feedback')),
            findsOneWidget,
          );
          expect(mission.finalized, isTrue);
          await tester.tap(find.text('Continuar'));
          await tester.pumpAndSettle();
        }
        if (round < total) {
          expect(mission.currentRound, round + 1);
          expect(mission.selectedAgent, isNull);
          mission.selectAgent(agent.id);
          expect(mission.selectedAgent, isNull);
          expect(
            tester
                .widget<InkWell>(
                  find.descendant(of: card, matching: find.byType(InkWell)),
                )
                .onTap,
            isNull,
          );
        }
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Missão encerrada'), findsOneWidget);
      expect(find.text('$total rounds concluídos.'), findsOneWidget);
      expect(
        find.text(
          'Vitórias: ${mission.victories} • Derrotas: ${mission.defeats} • Empates: ${mission.draws}',
        ),
        findsOneWidget,
      );
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        members
            .map(
              (json) => json['id'] == mission.rewardedAgent?.id
                  ? mission.rewardedAgent!.toJson()
                  : json,
            )
            .toList(),
      );
      expect(await heroes.countCachedHeroes(), 563);
      expect(
        (await heroes.getPage(
          limit: 563,
          offset: 0,
        )).map((hero) => hero.toJson()).toList(),
        catalog.map((hero) => hero.toJson()).toList(),
      );
      await tester.tap(find.text('Nova Missão'));
      await tester.pumpAndSettle();
      expect(mission.currentRound, 1);
      expect(mission.completed, isFalse);
      expect(mission.results, isEmpty);
      expect(mission.victories + mission.defeats + mission.draws, 0);
      expect(mission.isUsed(mission.members.first.id), isFalse);
      mission.selectAgent(mission.members.first.id);
      expect(mission.canConfirm, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MissionsScreen), findsOneWidget);
      expect(mission.currentRound, 0);
      expect(api.requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      mission.dispose();
    },
  );
}
