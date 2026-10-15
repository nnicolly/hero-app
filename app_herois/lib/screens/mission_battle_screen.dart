import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../providers/mission_provider.dart';
import '../widgets/hero_powerstats.dart';
import '../models/mission_round_result.dart';

class MissionBattleScreen extends StatefulWidget {
  const MissionBattleScreen({super.key});

  @override
  State<MissionBattleScreen> createState() => _MissionBattleScreenState();
}

class _MissionBattleScreenState extends State<MissionBattleScreen> {
  final _scrollController = ScrollController();
  bool _finalDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<MissionProvider>().completed) {
        _finishMission();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirm(BuildContext context) async {
    final mission = context.read<MissionProvider>();
    final result = mission.confirmAgent();
    if (result == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rodada ${result.round}: ${result.label}'),
        content: Text(
          '${HeroPowerstats.stats[result.attribute]} (${result.attribute})\n\n'
          '${result.agent.name}: ${result.agentValue}\n'
          '${result.enemy.name}: ${result.enemyValue}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    if (context.mounted) {
      mission.advanceRound();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      if (mission.completed) await _finishMission();
    }
  }

  Future<void> _finishMission() async {
    final mission = context.read<MissionProvider>();
    if (await mission.finalizeMission() && mounted) await _showFinalFeedback();
  }

  Future<void> _showFinalFeedback({bool reopen = false}) async {
    final mission = context.read<MissionProvider>();
    if (_finalDialogOpen ||
        !mission.finalized ||
        (!reopen && mission.feedbackShown)) {
      return;
    }
    _finalDialogOpen = true;
    mission.markFeedbackShown();
    final type = switch (mission.outcome) {
      MissionOutcome.success => DialogType.success,
      MissionOutcome.failure => DialogType.error,
      _ => DialogType.info,
    };
    final defeatedRounds = mission.results
        .where((result) => result.outcome == CombatOutcome.defeat)
        .toList();
    await AwesomeDialog(
      context: context,
      dialogType: type,
      headerAnimationLoop: false,
      dismissOnTouchOutside: false,
      btnOkText: 'Continuar',
      btnOkOnPress: () {},
      body: ConstrainedBox(
        key: const ValueKey('mission-final-feedback'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mission.finalLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _score(mission),
              const SizedBox(height: 16),
              if (mission.rewardedAgent != null) ...[
                _feedbackImage(mission.rewardedAgent!.largeImage),
                const SizedBox(height: 12),
                Text(mission.rewardedAgent!.name, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_rewardDescription(mission), textAlign: TextAlign.center),
              ] else if (mission.outcome == MissionOutcome.failure &&
                  defeatedRounds.isNotEmpty) ...[
                _feedbackImage(defeatedRounds.last.enemy.largeImage),
                const SizedBox(height: 12),
                Text(
                  'Inimigo de uma rodada perdida: ${defeatedRounds.last.enemy.name}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text('Nenhuma recompensa concedida.'),
              ] else ...[
                const Icon(Icons.balance, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Não houve maioria absoluta de vitórias nem de derrotas. '
                  'Nenhuma recompensa concedida.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    ).show();
    _finalDialogOpen = false;
  }

  Widget _feedbackImage(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: CachedNetworkImage(
      key: const ValueKey('mission-feedback-image'),
      imageUrl: url,
      width: 140,
      height: 160,
      fit: BoxFit.cover,
      placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, _, _) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 40),
            Text('Imagem indisponível', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  String _rewardDescription(MissionProvider mission) {
    final attribute = mission.rewardAttribute!;
    final value = int.parse('${mission.rewardedAgent!.powerstats[attribute]}');
    return '${HeroPowerstats.stats[attribute]} ($attribute): ${value - 1} → $value (+1 permanente)';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Desafio de Crise')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Consumer<MissionProvider>(
            builder: (context, mission, _) {
              if (mission.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (mission.completed) {
                return PopScope(
                  canPop: !mission.finalizing,
                  child: _summary(context, mission),
                );
              }
              final enemy = mission.enemy;
              if (enemy == null) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(mission.error ?? 'Nenhuma missão em andamento.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: mission.startMission,
                      child: const Text('Tentar novamente'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voltar para Missões'),
                    ),
                  ],
                );
              }
              return ListView(
                key: const ValueKey('battle-list'),
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Rodada ${mission.currentRound} de ${mission.totalRounds}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _score(mission),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Inimigo da rodada'),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: enemy.largeImage,
                              width: 150,
                              height: 170,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            enemy.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Atributo dominante: ${HeroPowerstats.stats[mission.attribute]} '
                            '(${mission.attribute})',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecione um agente disponível. Os agentes com nome '
                    'riscado já participaram desta missão.',
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    key: const ValueKey('mission-squad-grid'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent:
                          100 + 48 * MediaQuery.textScalerOf(context).scale(1),
                    ),
                    itemCount: mission.members.length,
                    itemBuilder: (context, index) {
                      final agent = mission.members[index];
                      final used = mission.isUsed(agent.id);
                      final selected = mission.selectedAgent?.id == agent.id;
                      final colors = Theme.of(context).colorScheme;
                      return Semantics(
                        label: '${agent.name}${used ? ', indisponível' : ''}',
                        selected: selected,
                        child: Opacity(
                          opacity: used ? 0.45 : 1,
                          child: Card(
                            key: ValueKey('mission-agent-${agent.id}'),
                            margin: EdgeInsets.zero,
                            color: selected
                                ? colors.primaryContainer
                                : colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: used || mission.lastResult != null
                                  ? null
                                  : () => mission.selectAgent(agent.id),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: agent.thumbnail,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => const Center(
                                          child: Icon(Icons.person_outline),
                                        ),
                                        errorWidget: (_, _, _) => const Center(
                                          child: Icon(Icons.person_outline),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          agent.name,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            decoration: used
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
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
                    },
                  ),
                  if (mission.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(mission.error!),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const ValueKey('confirm-agent'),
                    onPressed: mission.canConfirm
                        ? () => _confirm(context)
                        : null,
                    child: const Text('Confirmar escalação'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _score(MissionProvider mission) => Text(
    'Vitórias: ${mission.victories} • Derrotas: ${mission.defeats} • Empates: ${mission.draws}',
    key: const ValueKey('mission-score'),
  );

  Widget _summary(BuildContext context, MissionProvider mission) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Missão encerrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('${mission.totalRounds} rounds concluídos.'),
              const SizedBox(height: 12),
              _score(mission),
              const SizedBox(height: 12),
              Text(mission.finalLabel),
              if (mission.finalizing) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
                const Text('Salvando recompensa…', textAlign: TextAlign.center),
              ],
              if (mission.rewardedAgent != null) ...[
                const SizedBox(height: 12),
                Text('Agente premiado: ${mission.rewardedAgent!.name}'),
                Text(_rewardDescription(mission)),
              ],
              if (mission.rewardError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(mission.rewardError!),
                ),
                ElevatedButton(
                  onPressed: mission.finalizing ? null : _finishMission,
                  child: const Text('Salvar recompensa novamente'),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: mission.finalized
                    ? () => _showFinalFeedback(reopen: true)
                    : null,
                child: const Text('Ver resultado'),
              ),
              ElevatedButton(
                onPressed: mission.finalized && !mission.finalizing
                    ? mission.startMission
                    : null,
                child: const Text('Nova Missão'),
              ),
              TextButton(
                onPressed: mission.finalizing
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Voltar para Missões'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
