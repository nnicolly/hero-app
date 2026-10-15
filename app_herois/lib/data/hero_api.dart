import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hero.dart';

class HeroApi {
  // Celular físico com adb reverse tcp:3000 tcp:3000.
  static const endpoint = String.fromEnvironment(
    'HEROES_API_URL',
    defaultValue: 'http://127.0.0.1:3000/heroes',
  );

  Future<List<Hero>> fetchAll() async {
    // Sem _limit: o cache recebe o catálogo inteiro, não apenas uma página.
    final json = await _getJson(Uri.parse(endpoint)) as List;
    final heroes = json
        .map((item) => Hero.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    if (heroes.isEmpty ||
        heroes.map((hero) => hero.id).toSet().length != heroes.length) {
      throw const FormatException('Catálogo vazio ou com IDs duplicados.');
    }
    return heroes;
  }

  Future<Hero> fetchById(int id) async {
    final uri = Uri.parse(endpoint);
    final json = await _getJson(uri.replace(path: '${uri.path}/$id'));
    final hero = Hero.fromJson(json as Map<String, dynamic>);
    if (hero.id != id) throw const FormatException('ID do agente inválido.');
    return hero;
  }

  Future<dynamic> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('A API não respondeu com sucesso.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
