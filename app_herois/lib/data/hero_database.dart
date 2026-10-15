import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/hero.dart';

abstract class HeroContract {
  static const table = 'heroes';
  static const id = 'id';
  static const name = 'name';
  static const json = 'complete_json';
}

abstract class SquadContract {
  static const table = 'squad_members';
  static const heroId = 'hero_id';
  static const json = 'complete_json';
  static const maxMembers = 15;
}

enum RecruitmentResult { recruited, alreadyRecruited, full }

class HeroDatabase {
  Database? _database;
  final String filename;

  HeroDatabase({this.filename = 'heroes.db'});

  Future<Database> get database async {
    _database ??= await openDatabase(
      join(await getDatabasesPath(), filename),
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE ${HeroContract.table} ('
          '${HeroContract.id} INTEGER PRIMARY KEY, '
          '${HeroContract.name} TEXT NOT NULL, '
          '${HeroContract.json} TEXT NOT NULL)',
        );
        await _createSquadTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSquadTable(db);
        }
      },
    );
    return _database!;
  }

  Future<void> _createSquadTable(Database db) => db.execute(
    'CREATE TABLE ${SquadContract.table} ('
    '${SquadContract.heroId} INTEGER PRIMARY KEY, '
    '${SquadContract.json} TEXT NOT NULL)',
  );

  Future<List<Hero>> getSquadMembers() async {
    final db = await database;
    final rows = await db.query(
      SquadContract.table,
      orderBy: '${SquadContract.heroId} ASC',
    );
    return rows
        .map(
          (row) => Hero.fromJson(
            jsonDecode(row[SquadContract.json] as String)
                as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<RecruitmentResult> recruit(Hero hero) async {
    final db = await database;
    // Verificação e inserção juntas impedem ultrapassar 15 mesmo com cliques concorrentes.
    return db.transaction((transaction) async {
      final existing = await transaction.query(
        SquadContract.table,
        columns: [SquadContract.heroId],
        where: '${SquadContract.heroId} = ?',
        whereArgs: [hero.id],
        limit: 1,
      );
      if (existing.isNotEmpty) return RecruitmentResult.alreadyRecruited;
      final members = await transaction.query(
        SquadContract.table,
        columns: [SquadContract.heroId],
      );
      if (members.length >= SquadContract.maxMembers) {
        return RecruitmentResult.full;
      }
      // O JSON do membro fica separado do catálogo para a progressão futura.
      await transaction.insert(SquadContract.table, {
        SquadContract.heroId: hero.id,
        SquadContract.json: jsonEncode(hero.toJson()),
      });
      return RecruitmentResult.recruited;
    });
  }

  Future<int> dismissMember(int heroId) async {
    final db = await database;
    return db.delete(
      SquadContract.table,
      where: '${SquadContract.heroId} = ?',
      whereArgs: [heroId],
    );
  }

  Future<Hero> improveMemberAttribute(int heroId, String attribute) async {
    if (!const [
      'intelligence',
      'strength',
      'speed',
      'durability',
      'power',
      'combat',
    ].contains(attribute)) {
      throw ArgumentError('Atributo inválido.');
    }
    final db = await database;
    // Lê o membro atual e soma +1 na mesma transação, preservando seu JSON.
    return db.transaction((transaction) async {
      final rows = await transaction.query(
        SquadContract.table,
        where: '${SquadContract.heroId} = ?',
        whereArgs: [heroId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('O agente não está mais no esquadrão.');
      }
      final json = jsonDecode(
        rows.single[SquadContract.json] as String,
      ) as Map<String, dynamic>;
      final stats = Map<String, dynamic>.from(json['powerstats'] as Map? ?? {});
      final value = int.tryParse('${stats[attribute]}');
      if (value == null) throw StateError('O atributo não está informado.');
      stats[attribute] = value + 1;
      json['powerstats'] = stats;
      final changed = await transaction.update(
        SquadContract.table,
        {SquadContract.json: jsonEncode(json)},
        where: '${SquadContract.heroId} = ?',
        whereArgs: [heroId],
      );
      if (changed != 1) {
        throw StateError('Não foi possível atualizar o agente.');
      }
      return Hero.fromJson(json);
    });
  }

  Map<String, Object?> _toRow(Hero hero) => {
    HeroContract.id: hero.id,
    HeroContract.name: hero.name,
    HeroContract.json: jsonEncode(hero.toJson()),
  };

  Future<void> saveCatalog(List<Hero> heroes) async {
    final db = await database;
    // A transação mantém o cache anterior se qualquer gravação falhar.
    await db.transaction((transaction) async {
      await transaction.delete(HeroContract.table);
      for (final hero in heroes) {
        await transaction.insert(HeroContract.table, _toRow(hero));
      }
    });
  }

  Future<int> count() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${HeroContract.table}'),
        ) ??
        0;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Hero?> getById(int id) async {
    final db = await database;
    final rows = await db.query(
      HeroContract.table,
      where: '${HeroContract.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Hero.fromJson(
      jsonDecode(rows.first[HeroContract.json] as String)
          as Map<String, dynamic>,
    );
  }

  Future<List<Hero>> getPage({required int limit, required int offset}) async {
    final db = await database;
    final rows = await db.query(
      HeroContract.table,
      orderBy: '${HeroContract.id} ASC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (row) => Hero.fromJson(
            jsonDecode(row[HeroContract.json] as String)
                as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
