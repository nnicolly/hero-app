import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/hero.dart' as model;
import '../screens/agent_details_screen.dart';

class HeroCard extends StatelessWidget {
  final model.Hero hero;
  const HeroCard({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AgentDetailsScreen(heroId: hero.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: hero.thumbnail,
                  width: 76,
                  height: 104,
                  fit: BoxFit.cover,
                  placeholder: (_, url) => const SizedBox(
                    width: 76,
                    height: 104,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, url, error) => const SizedBox(
                    width: 76,
                    height: 104,
                    child: Icon(Icons.person_outline, size: 40),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('Raça: ${hero.appearance['race'] ?? 'Não informada'}'),
                    const SizedBox(height: 6),
                    Text(
                      'Força: ${hero.powerstats['strength'] ?? '—'}  •  '
                      'Inteligência: ${hero.powerstats['intelligence'] ?? '—'}',
                    ),
                    Text(
                      'Velocidade: ${hero.powerstats['speed'] ?? '—'}  •  '
                      'Combate: ${hero.powerstats['combat'] ?? '—'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
