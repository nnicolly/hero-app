import 'package:flutter/material.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';

import '../models/hero.dart' as model;

/// Mesmas seis barras nas telas de detalhes e contrato diário.
class HeroPowerstats extends StatelessWidget {
  final model.Hero hero;
  const HeroPowerstats({super.key, required this.hero});

  static const stats = {
    'intelligence': 'Inteligência',
    'strength': 'Força',
    'speed': 'Velocidade',
    'durability': 'Resistência',
    'power': 'Poder',
    'combat': 'Combate',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final stat in stats.entries) ...[
        Text(
          '${stat.value} (${stat.key}): ${_value(hero.powerstats[stat.key])}',
        ),
        const SizedBox(height: 6),
        PrimerProgressBar(
          key: ValueKey('stat-${stat.key}'),
          maxTotalValue: _maximum(hero.powerstats[stat.key]),
          showLegend: false,
          barStyle: const SegmentedBarStyle(padding: EdgeInsets.zero, size: 12),
          segments: [
            Segment(
              value: (int.tryParse('${hero.powerstats[stat.key]}') ?? 0).clamp(
                0,
                _maximum(hero.powerstats[stat.key]),
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    ],
  );

  String _value(dynamic value) =>
      value == null || value.toString().trim().isEmpty || value == '-'
      ? 'Não informado'
      : value.toString();

  int _maximum(dynamic value) {
    final parsed = int.tryParse('$value') ?? 0;
    return parsed > 100 ? parsed : 100;
  }
}
