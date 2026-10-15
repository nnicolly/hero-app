import 'package:app_herois/data/hero_api.dart';
import 'package:app_herois/data/hero_database.dart';
import 'package:app_herois/models/hero.dart' as model;
import 'package:app_herois/repositories/squad_repository.dart';
import 'package:app_herois/widgets/hero_details_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/review_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Transações revertem catálogo inválido e preservam evolução concorrente',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Verificando integridade…')),
        ),
      );
      const filename = 'review_integrity.db';
      final path = join(await getDatabasesPath(), filename);
      await deleteDatabase(path);
      final database = HeroDatabase(filename: filename);
      addTearDown(() async {
        await database.close();
        await deleteDatabase(path);
      });
      final catalog = await HeroApi().fetchAll();
      await database.saveCatalog(catalog);
      final before = (await database.getPage(
        limit: 563,
        offset: 0,
      )).map((hero) => hero.toJson()).toList();
      await expectLater(
        database.saveCatalog([catalog.first, catalog.first]),
        throwsA(isA<DatabaseException>()),
      );
      expect(await database.count(), 563);
      expect(
        (await database.getPage(
          limit: 563,
          offset: 0,
        )).map((hero) => hero.toJson()).toList(),
        before,
      );
      final squad = SquadRepository(database);
      await squad.recruit(catalog.first);
      final incomplete = model.Hero.fromJson({
        ...catalog[1].toJson(),
        'powerstats': {...catalog[1].powerstats, 'strength': null},
      });
      await squad.recruit(incomplete);
      final membersBefore = (await squad.getMembers())
          .map((hero) => hero.toJson())
          .toList();
      await expectLater(
        squad.improveAttribute(incomplete.id, 'strength'),
        throwsStateError,
      );
      expect(
        (await squad.getMembers()).map((hero) => hero.toJson()).toList(),
        membersBefore,
      );
      await Future.wait([
        squad.improveAttribute(catalog.first.id, 'strength'),
        squad.improveAttribute(catalog.first.id, 'strength'),
      ]);
      final members = await squad.getMembers();
      final evolved = members.firstWhere((hero) => hero.id == catalog.first.id);
      final expected = {
        ...catalog.first.toJson(),
        'powerstats': {
          ...catalog.first.powerstats,
          'strength': (catalog.first.powerstats['strength'] as int) + 2,
        },
      };
      expect(evolved.toJson(), expected);
      expect(
        members.firstWhere((hero) => hero.id == incomplete.id).toJson(),
        incomplete.toJson(),
      );
      expect(
        (await database.getPage(
          limit: 563,
          offset: 0,
        )).map((hero) => hero.toJson()).toList(),
        before,
      );
    },
  );

  testWidgets(
    'Imagem inacessível e dados ausentes têm substituição legível com fonte ampliada',
    (tester) async {
      final hero = model.Hero.fromJson({
        'id': 9000,
        'name': 'Agente sem imagem',
        'images': {'lg': 'http://127.0.0.1:1/review-missing.jpg'},
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Agente')),
            body: HeroDetailsContent(hero: hero),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Imagem indisponível'), findsOneWidget);
      await reviewCapture(tester, 'missing_image');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stat-intelligence')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(PrimerProgressBar), findsNWidgets(6));
      expect(find.text('Força (strength): Não informado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
