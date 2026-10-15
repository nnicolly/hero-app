import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../models/hero.dart' as model;
import '../providers/hero_provider.dart';
import '../widgets/hero_card.dart';
import 'daily_contract_screen.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HeroProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agentes'),
            actions: [
              IconButton(
                tooltip: 'Contrato Diário',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DailyContractScreen(),
                  ),
                ),
                icon: const Icon(Icons.event_available),
              ),
              IconButton(
                tooltip: 'Atualizar catálogo',
                onPressed: provider.loading
                    ? null
                    : () => context.read<HeroProvider>().synchronize(),
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: provider.loading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(provider.message),
                        ],
                      )
                    : provider.error != null
                    ? _error(provider.error!, provider.initialize)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${provider.total} agentes no catálogo',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(provider.message),
                              ],
                            ),
                          ),
                          Expanded(
                            child: PagedListView<int, model.Hero>(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                              pagingController: provider.pagingController,
                              builderDelegate:
                                  PagedChildBuilderDelegate<model.Hero>(
                                    itemBuilder: (context, hero, index) =>
                                        HeroCard(hero: hero),
                                    firstPageErrorIndicatorBuilder: (_) =>
                                        _error(
                                          provider.pagingController.error
                                              .toString(),
                                          provider
                                              .pagingController
                                              .retryLastFailedRequest,
                                        ),
                                    newPageErrorIndicatorBuilder: (_) => _error(
                                      provider.pagingController.error
                                          .toString(),
                                      provider
                                          .pagingController
                                          .retryLastFailedRequest,
                                    ),
                                    noItemsFoundIndicatorBuilder: (_) =>
                                        const Center(
                                          child: Text(
                                            'Nenhum agente encontrado.',
                                          ),
                                        ),
                                    noMoreItemsIndicatorBuilder: (_) =>
                                        const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'Você chegou ao fim do catálogo.',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                  ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _error(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Tentar novamente')),
        ],
      ),
    ),
  );
}
