import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:app_herois/data/hero_api.dart';
import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart' as model;
import 'package:app_herois/providers/hero_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:app_herois/screens/agents_screen.dart';
import 'package:app_herois/screens/agent_details_screen.dart';
import 'package:app_herois/widgets/hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import 'package:app_herois/providers/squad_provider.dart';
import 'package:app_herois/screens/daily_contract_screen.dart';
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app_herois/screens/home_screen.dart';
import 'package:app_herois/screens/squad_screen.dart';
import 'package:app_herois/screens/squad_agent_details_screen.dart';
import 'package:app_herois/widgets/squad_card.dart';
import 'package:app_herois/widgets/hero_details_content.dart';
import 'package:app_herois/providers/mission_provider.dart';
import 'package:app_herois/screens/missions_screen.dart';

import 'helpers/review_capture.dart';

class UnavailableApi extends HeroApi {
  @override
  Future<List<model.Hero>> fetchAll() async =>
      throw const SocketException('offline');

  @override
  Future<model.Hero> fetchById(int id) async =>
      throw const SocketException('offline');
}

class DetailsApi extends HeroApi {
  bool offline = false;
  int requests = 0;

  @override
  Future<model.Hero> fetchById(int id) async {
    requests++;
    if (offline) throw const SocketException('offline');
    return super.fetchById(id);
  }
}

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

class CheckedOfflineApi extends UnavailableApi {
  int requests = 0;
  @override
  Future<List<model.Hero>> fetchAll() {
    requests++;
    return super.fetchAll();
  }

  @override
  Future<model.Hero> fetchById(int id) {
    requests++;
    return super.fetchById(id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Menu, esquadrão offline, detalhes, cancelamento, dispensa e novo recrutamento',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Validando esquadrão…'))),
      );
      const filename = 'squad_screen_validation.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      final database = HeroDatabase(filename: filename);
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('squad_screen_daily_date');
        await prefs.remove('squad_screen_daily_hero_id');
      });
      final catalog = await HeroApi().fetchAll();
      catalog.sort((a, b) => a.id.compareTo(b.id));
      await database.saveCatalog(catalog);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('squad_screen_daily_date');
      await prefs.remove('squad_screen_daily_hero_id');
      final api = CheckedOfflineApi();
      final heroes = HeroRepository(
        api: api,
        database: database,
        dailyPreferencePrefix: 'squad_screen_daily',
      );
      final squad = SquadRepository(database);
      for (final hero in catalog.take(15)) {
        expect(await squad.recruit(hero), RecruitmentResult.recruited);
      }
      final today = DateTime.now();
      final selected = (await heroes.getDailyHero(
        date: today,
        random: OffsetRandom(0),
      ))!;
      final provider = SquadProvider(squad, heroes);
      await provider.loadDailyContract();
      final heroProvider = HeroProvider(heroes);
      await heroProvider.initialize();
      final missionProvider = MissionProvider(heroes, squad);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: heroProvider),
            ChangeNotifierProvider.value(value: missionProvider),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (final option in [
        'Agentes',
        'Contrato Diário',
        'Meu Esquadrão',
        'Missões',
      ]) {
        expect(find.text(option), findsOneWidget);
      }
      await reviewCapture(tester, 'home');
      await tester.tap(find.text('Missões'));
      await tester.pumpAndSettle();
      expect(find.byType(MissionsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu Esquadrão'));
      await tester.pumpAndSettle();
      expect(provider.members.length, 15);
      expect(
        provider.members.map((hero) => hero.id).toList(),
        catalog.take(15).map((hero) => hero.id).toList(),
      );
      final card = find.byKey(ValueKey('squad-${selected.id}'));
      expect(
        tester.widget<SquadCard>(find.byType(SquadCard).first).hero.id,
        selected.id,
      );
      expect(
        find.descendant(of: card, matching: find.text(selected.name)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CachedNetworkImage>(
              find.descendant(
                of: card,
                matching: find.byType(CachedNetworkImage),
              ),
            )
            .imageUrl,
        selected.thumbnail,
      );
      expect(
        find.descendant(of: card, matching: find.text('Destaque: Força (100)')),
        findsOneWidget,
      );
      await reviewCapture(tester, 'squad');
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Detalhes do Meu Agente'), findsOneWidget);
      expect(
        tester
            .widget<HeroDetailsContent>(find.byType(HeroDetailsContent))
            .hero
            .toJson(),
        selected.toJson(),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stat-intelligence')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(PrimerProgressBar), findsNWidgets(6));
      await reviewCapture(tester, 'squad_details');
      await tester.scrollUntilVisible(
        find.text('Dispensar do Esquadrão'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Dispensar do Esquadrão'));
      await tester.pumpAndSettle();
      expect(find.text('Dispensar agente?'), findsOneWidget);
      await reviewCapture(tester, 'dismiss');
      expect(find.byType(AnimatedButton), findsNWidgets(2));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect((await squad.getMembers()).length, 15);
      expect(find.byType(SquadAgentDetailsScreen), findsOneWidget);
      await tester.tap(find.text('Dispensar do Esquadrão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.byType(SquadAgentDetailsScreen), findsNothing);
      expect(find.byType(SquadScreen), findsOneWidget);
      expect(find.text('14/15 agentes no esquadrão.'), findsOneWidget);
      expect(provider.members.length, 14);
      expect(provider.members.any((hero) => hero.id == selected.id), isFalse);
      expect(find.byKey(ValueKey('squad-${selected.id}')), findsNothing);
      expect(provider.isFull, isFalse);
      expect(provider.canRecruit, isTrue);
      expect((await squad.getMembers()).length, 14);
      expect(await database.count(), 563);
      expect(
        (await database.getById(selected.id))!.toJson(),
        selected.toJson(),
      );
      final futureHero = (await heroes.getDailyHero(
        date: today.add(const Duration(days: 1)),
        random: OffsetRandom(0),
      ))!;
      expect(futureHero.id, selected.id);
      provider.dailyHero = futureHero;
      expect(await provider.recruitDailyHero(), contains('foi recrutado'));
      await tester.pumpAndSettle();
      expect(find.text('15/15 agentes no esquadrão.'), findsOneWidget);
      for (final member in List<model.Hero>.of(provider.members)) {
        expect(await provider.dismissMember(member.id), isTrue);
      }
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Seu esquadrão está vazio. Recrute um agente no Contrato Diário.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SquadCard), findsNothing);
      expect(find.text('Abrir Contrato Diário'), findsOneWidget);
      expect(await database.count(), 563);
      expect(api.requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      heroProvider.dispose();
      missionProvider.dispose();
    },
  );

  testWidgets(
    'Migração preserva 563 heróis; contrato, recrutamento, reabertura e limite 15 offline',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Validando migração…'))),
      );
      const filename = 'squad_migration_validation.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      final original = await HeroApi().fetchAll();
      expect(original.length, 563);
      final versionOne = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE heroes (id INTEGER PRIMARY KEY, name TEXT NOT NULL, complete_json TEXT NOT NULL)',
          );
        },
      );
      await versionOne.transaction((transaction) async {
        final batch = transaction.batch();
        for (final hero in original) {
          batch.insert('heroes', {
            'id': hero.id,
            'name': hero.name,
            'complete_json': jsonEncode(hero.toJson()),
          });
        }
        await batch.commit(noResult: true);
      });
      await versionOne.close();

      var database = HeroDatabase(filename: filename);
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('validation_daily_date');
        await prefs.remove('validation_daily_hero_id');
      });
      expect(await database.count(), 563);
      expect(await (await database.database).getVersion(), 2);
      expect(await database.getSquadMembers(), isEmpty);
      final expected = original.toList()..sort((a, b) => a.id.compareTo(b.id));
      expect(
        (await database.getPage(
          limit: 563,
          offset: 0,
        )).map((hero) => hero.toJson()).toList(),
        expected.map((hero) => hero.toJson()).toList(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('validation_daily_date');
      await prefs.remove('validation_daily_hero_id');
      var heroes = HeroRepository(
        api: UnavailableApi(),
        database: database,
        dailyPreferencePrefix: 'validation_daily',
      );
      final today = DateTime.now();
      final first = (await heroes.getDailyHero(
        date: today,
        random: OffsetRandom(562),
      ))!;
      expect(first.id, expected.last.id);
      expect(
        (await heroes.getDailyHero(date: today, random: OffsetRandom(0)))!.id,
        first.id,
      );
      await database.close();
      await prefs.reload();
      database = HeroDatabase(filename: filename);
      heroes = HeroRepository(
        api: UnavailableApi(),
        database: database,
        dailyPreferencePrefix: 'validation_daily',
      );
      expect(
        (await heroes.getDailyHero(date: today, random: OffsetRandom(0)))!.id,
        first.id,
      );
      final tomorrow = (await heroes.getDailyHero(
        date: today.add(const Duration(days: 1)),
        random: OffsetRandom(0),
      ))!;
      expect(tomorrow.id, expected.first.id);
      expect(tomorrow.id, isNot(first.id));
      final selected = (await heroes.getDailyHero(
        date: today,
        random: OffsetRandom(0),
      ))!;

      var squad = SquadRepository(database);
      final squadProvider = SquadProvider(squad, heroes);
      final heroProvider = HeroProvider(heroes);
      await heroProvider.initialize();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: heroProvider),
            ChangeNotifierProvider.value(value: squadProvider),
          ],
          child: const MaterialApp(home: AgentsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Contrato Diário'));
      await tester.pumpAndSettle();
      expect(find.text('Contrato Diário'), findsOneWidget);
      expect(squadProvider.dailyHero!.id, selected.id);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stat-intelligence')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(PrimerProgressBar), findsNWidgets(6));
      await reviewCapture(tester, 'contract');
      await tester.scrollUntilVisible(
        find.text('Recrutar para o Esquadrão'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Recrutar para o Esquadrão'));
      await tester.pumpAndSettle();
      expect((await squad.getMembers()).single.id, selected.id);
      expect(squadProvider.alreadyRecruited, isTrue);
      expect(squadProvider.canRecruit, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Recrutar para o Esquadrão'),
            )
            .onPressed,
        isNull,
      );
      expect(await squad.recruit(selected), RecruitmentResult.alreadyRecruited);
      expect((await heroes.getDailyHero(date: today))!.id, selected.id);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      squadProvider.dispose();
      heroProvider.dispose();
      await database.close();
      await prefs.reload();
      database = HeroDatabase(filename: filename);
      heroes = HeroRepository(
        api: UnavailableApi(),
        database: database,
        dailyPreferencePrefix: 'validation_daily',
      );
      squad = SquadRepository(database);
      final reopened = SquadProvider(squad, heroes);
      await reopened.loadDailyContract();
      expect(reopened.dailyHero!.id, selected.id);
      expect(reopened.members.single.toJson(), selected.toJson());
      expect(reopened.alreadyRecruited, isTrue);

      final candidates = expected
          .where((hero) => hero.id != selected.id)
          .toList();
      final results = await Future.wait(candidates.take(16).map(squad.recruit));
      expect(
        results.where((result) => result == RecruitmentResult.recruited).length,
        14,
      );
      expect(
        results.where((result) => result == RecruitmentResult.full).length,
        2,
      );
      expect((await squad.getMembers()).length, 15);
      expect(
        (await squad.getMembers()).map((hero) => hero.id).toSet().length,
        15,
      );
      expect(await squad.recruit(selected), RecruitmentResult.alreadyRecruited);
      await database.saveCatalog(original);
      expect((await squad.getMembers()).length, 15);
      expect(await database.count(), 563);
      await prefs.setInt('validation_daily_hero_id', candidates[15].id);
      await reopened.loadDailyContract();
      expect(reopened.isFull, isTrue);
      expect(reopened.alreadyRecruited, isFalse);
      expect(reopened.canRecruit, isFalse);
      expect(await reopened.recruitDailyHero(), contains('limite de 15'));
      reopened.dispose();
      await database.close();
      database = HeroDatabase(filename: filename);
      expect((await database.getSquadMembers()).length, 15);
      expect(await database.count(), 563);
    },
  );

  testWidgets(
    'Contrato sem catálogo apresenta mensagem e opção de tentar novamente',
    (tester) async {
      const filename = 'empty_contract_validation.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      final database = HeroDatabase(filename: filename);
      final heroes = HeroRepository(
        api: UnavailableApi(),
        database: database,
        dailyPreferencePrefix: 'empty_validation',
      );
      final provider = SquadProvider(SquadRepository(database), heroes);
      await provider.loadDailyContract();
      expect(provider.dailyHero, isNull);
      expect(provider.error, contains('catálogo local'));
      expect(provider.canRecruit, isFalse);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: DailyContractScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      await database.close();
      await deleteDatabase(path);
    },
  );

  testWidgets(
    'API, SQLite completo, paginação e reabertura offline no Android',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Validando catálogo…'))),
        ),
      );
      final database = HeroDatabase(filename: 'catalog_validation.db');
      final online = HeroRepository(database: database);
      final original = await HeroApi().fetchAll();
      expect(original.length, 563);
      expect(await online.synchronize(), 563);
      expect(await online.countCachedHeroes(), 563);
      final expected = original.toList()..sort((a, b) => a.id.compareTo(b.id));
      final loaded = <model.Hero>[];
      for (var offset = 0; offset < 563; offset += 20) {
        final page = await online.getPage(limit: 20, offset: offset);
        expect(page.length, offset == 560 ? 3 : 20);
        loaded.addAll(page);
      }
      expect(
        loaded.map((hero) => hero.toJson()).toList(),
        expected.map((hero) => hero.toJson()).toList(),
      );
      expect(loaded.map((hero) => hero.id).toSet().length, 563);
      await database.close();

      final reopened = HeroDatabase(filename: 'catalog_validation.db');
      final offline = HeroRepository(api: UnavailableApi(), database: reopened);
      final provider = HeroProvider(offline);
      await provider.initialize();
      expect(provider.total, 563);
      await provider.synchronize();
      expect(provider.error, isNull);
      expect(await offline.countCachedHeroes(), 563);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AgentsScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('563 agentes no catálogo'), findsOneWidget);
      expect(find.text('A-Bomb'), findsOneWidget);
      await reviewCapture(tester, 'catalog');
      expect(tester.takeException(), isNull);
      while (provider.pagingController.nextPageKey != null) {
        await provider.loadPage(provider.pagingController.nextPageKey!);
      }
      expect(provider.pagingController.itemList!.length, 563);
      final list = find.byType(Scrollable).first;
      tester.state<ScrollableState>(list).position.jumpTo(1000000);
      await tester.pumpAndSettle();
      expect(find.text('Você chegou ao fim do catálogo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      await reopened.close();
    },
  );

  testWidgets('Detalhes online e offline, seis barras e posição do catálogo', (
    tester,
  ) async {
    final database = HeroDatabase(filename: 'catalog_validation.db');
    final api = DetailsApi();
    final repository = HeroRepository(api: api, database: database);
    final provider = HeroProvider(repository);
    await provider.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: AgentsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(position, greaterThan(0));

    for (final offline in [false, true]) {
      final currentPosition = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      api.offline = offline;
      final card = find.byType(HeroCard).hitTestable().first;
      final hero = tester.widget<HeroCard>(card).hero;
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Detalhes do Agente'), findsOneWidget);
      expect(provider.selectedHero?.id, hero.id);
      expect(provider.detailsError, isNull);
      expect(
        provider.selectedHero!.toJson(),
        (await database.getById(hero.id))!.toJson(),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stat-intelligence')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(PrimerProgressBar), findsNWidgets(6));
      for (final key in [
        'intelligence',
        'strength',
        'speed',
        'durability',
        'power',
        'combat',
      ]) {
        expect(find.byKey(ValueKey('stat-$key')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await reviewCapture(
        tester,
        offline ? 'details_offline' : 'details_online',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AgentDetailsScreen), findsNothing);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(currentPosition, 0.1),
      );
      // Escolhe outro personagem para conferir que não aparece o agente anterior.
      if (!offline) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }
    expect(api.requests, 2);
    await provider.loadDetails(-1);
    expect(provider.selectedHero, isNull);
    expect(provider.detailsError, isNotNull);
    expect(provider.loadingDetails, isFalse);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    await database.close();
  });
}
