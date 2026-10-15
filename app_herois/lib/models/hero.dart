/// Os mapas preservam as estruturas aninhadas sem classes desnecessárias.
class Hero {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> powerstats;
  final Map<String, dynamic> appearance;
  final Map<String, dynamic> biography;
  final Map<String, dynamic> work;
  final Map<String, dynamic> connections;
  final Map<String, dynamic> images;
  final Map<String, dynamic> extraFields;

  const Hero({
    required this.id,
    required this.name,
    required this.slug,
    required this.powerstats,
    required this.appearance,
    required this.biography,
    required this.work,
    required this.connections,
    required this.images,
    this.extraFields = const {},
  });

  factory Hero.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json);
    for (final key in [
      'id',
      'name',
      'slug',
      'powerstats',
      'appearance',
      'biography',
      'work',
      'connections',
      'images',
    ]) {
      extra.remove(key);
    }
    return Hero(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String? ?? 'Agente sem nome',
      slug: json['slug'] as String? ?? '',
      powerstats: Map<String, dynamic>.from(json['powerstats'] as Map? ?? {}),
      appearance: Map<String, dynamic>.from(json['appearance'] as Map? ?? {}),
      biography: Map<String, dynamic>.from(json['biography'] as Map? ?? {}),
      work: Map<String, dynamic>.from(json['work'] as Map? ?? {}),
      connections: Map<String, dynamic>.from(json['connections'] as Map? ?? {}),
      images: Map<String, dynamic>.from(json['images'] as Map? ?? {}),
      extraFields: extra,
    );
  }

  Map<String, dynamic> toJson() => {
    ...extraFields,
    'id': id,
    'name': name,
    'slug': slug,
    'powerstats': powerstats,
    'appearance': appearance,
    'biography': biography,
    'work': work,
    'connections': connections,
    'images': images,
  };

  String get thumbnail => (images['sm'] ?? images['xs'] ?? '').toString();

  MapEntry<String, int>? get strongestPowerstat {
    MapEntry<String, int>? strongest;
    for (final key in [
      'intelligence',
      'strength',
      'speed',
      'durability',
      'power',
      'combat',
    ]) {
      final value = int.tryParse('${powerstats[key]}');
      if (value != null && (strongest == null || value > strongest.value)) {
        strongest = MapEntry(key, value);
      }
    }
    return strongest;
  }

  String get largeImage =>
      (images['lg'] ?? images['md'] ?? images['sm'] ?? '').toString();
}
