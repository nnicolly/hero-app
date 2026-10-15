import 'dart:convert';
import 'dart:io';

import 'package:app_herois/models/hero.dart';
import 'package:app_herois/providers/hero_provider.dart';
import 'package:app_herois/repositories/hero_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository extends HeroRepository {
  final List<Hero> catalog;
  bool unavailable = false;
  int cachedCount;
  MemoryRepository(this.catalog, {this.cachedCount = 0});

  @override
  Future<int> countCachedHeroes() async => cachedCount;

  @override
  Future<int> synchronize() async {
    if (unavailable) throw const SocketException('offline');
    return cachedCount = catalog.length;
  }

  @override
  Future<List<Hero>> getPage({required int limit, required int offset}) async =>
      catalog.skip(offset).take(limit).toList();
}

void main() {
  final original =
      (jsonDecode(File('../backend/db.json').readAsStringSync())
              as Map<String, dynamic>)['heroes']
          as List;
  final catalog = original
      .map((json) => Hero.fromJson(json as Map<String, dynamic>))
      .toList();

  test('Todos os campos dos 563 personagens sobrevivem à serialização', () {
    expect(catalog.length, 563);
    for (var i = 0; i < original.length; i++) {
      expect(jsonDecode(jsonEncode(catalog[i].toJson())), original[i]);
    }
  });

  test('Paginação chega aos 563 IDs únicos e termina na página de 3', () async {
    final provider = HeroProvider(MemoryRepository(catalog));
    addTearDown(provider.dispose);
    await provider.initialize();
    do {
      await provider.loadPage(provider.pagingController.nextPageKey!);
    } while (provider.pagingController.nextPageKey != null);
    final loaded = provider.pagingController.itemList!;
    expect(loaded.length, 563);
    expect(loaded.map((hero) => hero.id).toSet().length, 563);
    expect(loaded.map((hero) => hero.id), catalog.map((hero) => hero.id));
  });

  test('Cache abre offline e permanece após atualização malsucedida', () async {
    final repository = MemoryRepository(catalog, cachedCount: 563)
      ..unavailable = true;
    final provider = HeroProvider(repository);
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.error, isNull);
    await provider.synchronize();
    await provider.loadPage(0);
    expect(provider.total, 563);
    expect(provider.pagingController.itemList!.length, 20);
    expect(provider.error, isNull);
    expect(provider.message, contains('catálogo salvo'));
  });

  test('Sem API e cache, informa erro e permite nova tentativa', () async {
    final repository = MemoryRepository(catalog)..unavailable = true;
    final provider = HeroProvider(repository);
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.error, isNotNull);
    repository.unavailable = false;
    await provider.initialize();
    expect(provider.error, isNull);
    expect(provider.total, 563);
  });
}
