import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/hero.dart' as model;
import '../screens/squad_agent_details_screen.dart';
import 'hero_powerstats.dart';

class SquadCard extends StatelessWidget {
  final model.Hero hero;
  const SquadCard({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final strongest = hero.strongestPowerstat;
    return Card(
      key: ValueKey('squad-${hero.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SquadAgentDetailsScreen(heroId: hero.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                    const SizedBox(height: 8),
                    Text(
                      strongest == null
                          ? 'Destaque: Não informado'
                          : 'Destaque: ${HeroPowerstats.stats[strongest.key]} (${strongest.value})',
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
