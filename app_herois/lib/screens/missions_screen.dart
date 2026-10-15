import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mission_provider.dart';
import 'mission_battle_screen.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});
  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MissionProvider>().loadMembers();
    });
  }

  Future<void> _start() async {
    final provider = context.read<MissionProvider>();
    if (!await provider.startMission() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MissionBattleScreen()),
    );
    if (mounted) await provider.loadMembers();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Missões')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Consumer<MissionProvider>(
            builder: (context, mission, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.flag_outlined, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Desafio de Crise',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Enfrente de 3 a 5 rounds. Cada agente pode participar '
                          'de uma única rodada por missão.',
                        ),
                        const SizedBox(height: 12),
                        if (mission.loading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Text(
                            '${mission.members.length} agentes no esquadrão.',
                          ),
                          if (mission.members.length < 5) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Recrute pelo menos 5 agentes no Contrato Diário '
                              'para iniciar uma missão.',
                            ),
                          ],
                        ],
                        if (mission.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(mission.error!),
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          key: const ValueKey('start-mission'),
                          onPressed: mission.canStart ? _start : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar Missão'),
                        ),
                        TextButton(
                          onPressed: mission.loading
                              ? null
                              : mission.loadMembers,
                          child: const Text('Atualizar esquadrão'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
