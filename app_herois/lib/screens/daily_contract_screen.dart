import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/squad_provider.dart';
import '../widgets/hero_powerstats.dart';

class DailyContractScreen extends StatefulWidget {
  const DailyContractScreen({super.key});
  @override
  State<DailyContractScreen> createState() => _DailyContractScreenState();
}

class _DailyContractScreenState extends State<DailyContractScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SquadProvider>().loadDailyContract();
    });
  }

  Future<void> _recruit() async {
    final message = await context.read<SquadProvider>().recruitDailyHero();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contrato Diário')),
    body: SafeArea(
      child: Consumer<SquadProvider>(
        builder: (context, provider, child) {
          if (provider.loading ||
              (provider.dailyHero == null && provider.error == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_search, size: 40),
                    const SizedBox(height: 12),
                    Text(provider.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: provider.loadDailyContract,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final hero = provider.dailyHero!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    hero.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HeroPowerstats(hero: hero),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: provider.canRecruit ? _recruit : null,
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      provider.recruiting
                          ? 'Recrutando…'
                          : 'Recrutar para o Esquadrão',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.alreadyRecruited
                        ? 'Este agente já foi recrutado.'
                        : provider.isFull
                        ? 'O esquadrão atingiu o limite de 15 agentes.'
                        : '${provider.members.length}/15 agentes no esquadrão.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
