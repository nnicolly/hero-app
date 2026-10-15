import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hero_provider.dart';
import '../widgets/hero_details_content.dart';

class AgentDetailsScreen extends StatefulWidget {
  final int heroId;
  const AgentDetailsScreen({super.key, required this.heroId});

  @override
  State<AgentDetailsScreen> createState() => _AgentDetailsScreenState();
}

class _AgentDetailsScreenState extends State<AgentDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Aguarda a construção da rota antes de notificar o Consumer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HeroProvider>().loadDetails(widget.heroId);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes do Agente')),
    body: SafeArea(
      child: Consumer<HeroProvider>(
        builder: (context, provider, child) {
          if (provider.loadingDetails ||
              (provider.detailsError == null &&
                  provider.selectedHero?.id != widget.heroId)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.detailsError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 40),
                    const SizedBox(height: 12),
                    Text(provider.detailsError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => provider.loadDetails(widget.heroId),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          return HeroDetailsContent(hero: provider.selectedHero!);
        },
      ),
    ),
  );
}
