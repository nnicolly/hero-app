import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/squad_provider.dart';
import '../widgets/squad_card.dart';
import 'daily_contract_screen.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});
  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SquadProvider>().loadMembers();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meu Esquadrão')),
    body: SafeArea(
      child: Consumer<SquadProvider>(
        builder: (context, provider, child) {
          if (provider.loadingMembers) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.membersError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.membersError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: provider.loadMembers,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (provider.members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Seu esquadrão está vazio. Recrute um agente no Contrato Diário.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyContractScreen(),
                        ),
                      ),
                      child: const Text('Abrir Contrato Diário'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${provider.members.length}/15 agentes no esquadrão.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: provider.members.length,
                      itemBuilder: (_, index) =>
                          SquadCard(hero: provider.members[index]),
                    ),
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
