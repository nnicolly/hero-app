import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/hero.dart' as model;
import 'hero_powerstats.dart';

/// Conteúdo compartilhado por Detalhes do Agente e Detalhes do Meu Agente.
class HeroDetailsContent extends StatelessWidget {
  final model.Hero hero;
  final Widget? action;
  const HeroDetailsContent({super.key, required this.hero, this.action});

  static const labels = {
    'fullName': 'Nome completo',
    'alterEgos': 'Alter egos',
    'aliases': 'Apelidos',
    'placeOfBirth': 'Local de nascimento',
    'firstAppearance': 'Primeira aparição',
    'publisher': 'Editora',
    'alignment': 'Alinhamento',
    'gender': 'Gênero',
    'race': 'Raça',
    'height': 'Altura',
    'weight': 'Peso',
    'eyeColor': 'Cor dos olhos',
    'hairColor': 'Cor do cabelo',
    'occupation': 'Ocupação',
    'base': 'Base',
    'groupAffiliation': 'Afiliações',
    'relatives': 'Parentes',
  };

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(hero.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: hero.largeImage,
              height: 300,
              fit: BoxFit.contain,
              placeholder: (_, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, url, error) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 48),
                    SizedBox(height: 8),
                    Text('Imagem indisponível'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _section(context, 'Identificação', {
            'ID': hero.id,
            'Slug': hero.slug,
          }),
          _statsSection(context, hero),
          if (action != null) ...[action!, const SizedBox(height: 16)],
          _section(context, 'Biografia', hero.biography),
          _section(context, 'Aparência', hero.appearance),
          _section(context, 'Trabalho', hero.work),
          _section(context, 'Conexões', hero.connections),
          _section(context, 'Imagens disponíveis', hero.images),
          if (hero.extraFields.isNotEmpty)
            _section(context, 'Outras informações', hero.extraFields),
        ],
      ),
    ),
  );

  Widget _statsSection(BuildContext context, model.Hero hero) =>
      _card(context, 'Atributos', [
        HeroPowerstats(hero: hero),
        for (final entry in hero.powerstats.entries.where(
          (entry) => !HeroPowerstats.stats.containsKey(entry.key),
        ))
          Text('${entry.key}: ${_text(entry.value)}'),
      ]);

  Widget _section(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
  ) => _card(
    context,
    title,
    data.isEmpty
        ? [const Text('Não informado')]
        : [
            for (final entry in data.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${labels[entry.key] ?? entry.key}: ${_text(entry.value)}',
                ),
              ),
          ],
  );

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  String _text(dynamic value) {
    if (value == null || value.toString().trim().isEmpty || value == '-') {
      return 'Não informado';
    }
    if (value is List) {
      return value.isEmpty ? 'Não informado' : value.map(_text).join(' / ');
    }
    if (value is Map) {
      return value.isEmpty
          ? 'Não informado'
          : value.entries
                .map(
                  (entry) =>
                      '${labels[entry.key] ?? entry.key}: ${_text(entry.value)}',
                )
                .join('; ');
    }
    return value.toString();
  }
}
