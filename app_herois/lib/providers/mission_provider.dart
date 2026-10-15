import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/hero.dart';
import '../models/mission_round_result.dart';
import '../repositories/hero_repository.dart';
import '../repositories/squad_repository.dart';

class MissionProvider extends ChangeNotifier {
  static const attributes = [
    'intelligence',
    'strength',
    'speed',
    'durability',
    'power',
    'combat',
  ];
  final HeroRepository _heroes;
  final SquadRepository _squad;
  final Random _random;
  final ValueChanged<Hero>? onMemberUpdated;
  List<Hero> members = [];
  List<Hero> _enemies = [];
  final Set<int> _usedAgentIds = {};
  final List<MissionRoundResult> _results = [];
  int totalRounds = 0;
  int currentRound = 0;
  int victories = 0;
  int defeats = 0;
  int draws = 0;
  Hero? enemy;
  Hero? selectedAgent;
  String? attribute;
  MissionRoundResult? lastResult;
  bool loading = false;
  bool completed = false;
  bool finalizing = false;
  bool finalized = false;
  bool feedbackShown = false;
  Hero? rewardedAgent;
  String? rewardAttribute;
  String? rewardError;
  Hero? _rewardCandidate;
  String? error;
  bool _disposed = false;

  MissionProvider(
    this._heroes,
    this._squad, {
    Random? random,
    this.onMemberUpdated,
  }) : _random = random ?? Random();

  List<MissionRoundResult> get results => List.unmodifiable(_results);
  List<Hero> get victoriousAgents => _results
      .where((result) => result.outcome == CombatOutcome.victory)
      .map((result) => result.agent)
      .toList();
  bool get canStart => !loading && members.length >= 5;
  bool get canConfirm =>
      !loading &&
      !completed &&
      currentRound > 0 &&
      selectedAgent != null &&
      lastResult == null;
  bool isUsed(int id) => _usedAgentIds.contains(id);

  MissionOutcome? get outcome => !completed
      ? null
      : victories * 2 > totalRounds
      ? MissionOutcome.success
      : defeats * 2 > totalRounds
      ? MissionOutcome.failure
      : MissionOutcome.neutral;

  String get finalLabel => switch (outcome) {
    MissionOutcome.success => 'Missão Cumprida!',
    MissionOutcome.failure => 'Operação Fracassada!',
    _ => 'Missão sem maioria',
  };

  void _reset() {
    totalRounds = currentRound = victories = defeats = draws = 0;
    enemy = selectedAgent = null;
    attribute = null;
    lastResult = null;
    completed = false;
    finalized = feedbackShown = false;
    rewardedAgent = _rewardCandidate = null;
    rewardAttribute = rewardError = null;
    error = null;
    _usedAgentIds.clear();
    _results.clear();
    _enemies = [];
  }

  Future<void> loadMembers() async {
    if (_disposed || loading || finalizing) return;
    _reset();
    loading = true;
    notifyListeners();
    try {
      final saved = await _squad.getMembers();
      if (_disposed) return;
      members = saved;
    } catch (_) {
      if (_disposed) return;
      members = [];
      error = 'Não foi possível carregar o esquadrão. Tente novamente.';
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
  }

  Future<bool> startMission() async {
    if (_disposed ||
        loading ||
        finalizing ||
        (currentRound > 0 && !completed)) {
      return false;
    }
    _reset();
    loading = true;
    notifyListeners();
    try {
      final saved = await _squad.getMembers();
      final count = await _heroes.countCachedHeroes();
      final catalog = await _heroes.getPage(limit: count, offset: 0);
      if (_disposed) return false;
      members = saved;
      if (members.length < 5) {
        error = 'Recrute pelo menos 5 agentes para iniciar uma missão.';
      } else {
        final squadIds = members.map((hero) => hero.id).toSet();
        // Exclui o esquadrão antes do sorteio para garantir um inimigo válido.
        // Esta lista temporária vem do mesmo catálogo SQLite, sem outra base.
        _enemies = catalog
            .where((hero) => !squadIds.contains(hero.id))
            .toList();
        if (_enemies.isEmpty) {
          error =
              'Nenhum inimigo disponível no catálogo local. '
              'Abra Agentes e sincronize o catálogo.';
        } else {
          totalRounds = 3 + _random.nextInt(3);
          currentRound = 1;
          _drawRound();
        }
      }
    } catch (_) {
      if (_disposed) return false;
      error = 'Não foi possível iniciar a missão com os dados locais. Tente novamente.';
    }
    if (_disposed) return false;
    loading = false;
    notifyListeners();
    return currentRound > 0;
  }

  void _drawRound() {
    enemy = _enemies[_random.nextInt(_enemies.length)];
    attribute = attributes[_random.nextInt(attributes.length)];
    selectedAgent = null;
    lastResult = null;
    error = null;
  }

  void selectAgent(int id) {
    if (_disposed ||
        loading ||
        completed ||
        currentRound == 0 ||
        lastResult != null ||
        isUsed(id)) {
      return;
    }
    for (final member in members) {
      if (member.id == id) {
        selectedAgent = member;
        error = null;
        notifyListeners();
        return;
      }
    }
  }

  MissionRoundResult? confirmAgent() {
    if (_disposed || !canConfirm || isUsed(selectedAgent!.id)) return null;
    final agent = selectedAgent!;
    final opponent = enemy!;
    final key = attribute!;
    final agentValue = int.tryParse('${agent.powerstats[key]}');
    final enemyValue = int.tryParse('${opponent.powerstats[key]}');
    if (agentValue == null || enemyValue == null) {
      error =
          'O atributo desta disputa não está informado. '
          'Escolha outro agente ou volte para iniciar uma nova missão.';
      notifyListeners();
      return null;
    }
    final outcome = agentValue > enemyValue
        ? CombatOutcome.victory
        : agentValue < enemyValue
        ? CombatOutcome.defeat
        : CombatOutcome.draw;
    final result = MissionRoundResult(
      round: currentRound,
      agent: agent,
      enemy: opponent,
      attribute: key,
      agentValue: agentValue,
      enemyValue: enemyValue,
      outcome: outcome,
    );
    // O resultado bloqueia imediatamente outros toques até a próxima rodada.
    lastResult = result;
    _results.add(result);
    _usedAgentIds.add(agent.id);
    switch (outcome) {
      case CombatOutcome.victory:
        victories++;
      case CombatOutcome.defeat:
        defeats++;
      case CombatOutcome.draw:
        draws++;
    }
    notifyListeners();
    return result;
  }

  void advanceRound() {
    if (_disposed || completed || lastResult == null) return;
    if (currentRound == totalRounds) {
      completed = true;
      selectedAgent = null;
      enemy = null;
      attribute = null;
    } else {
      currentRound++;
      _drawRound();
    }
    notifyListeners();
  }

  Future<bool> finalizeMission() async {
    if (_disposed || !completed || finalizing) return false;
    if (finalized) return true;
    if (outcome != MissionOutcome.success) {
      finalized = true;
      notifyListeners();
      return true;
    }
    finalizing = true;
    rewardError = null;
    notifyListeners();
    try {
      // Mantém o mesmo sorteio quando uma gravação falha e é tentada novamente.
      final winners = victoriousAgents;
      _rewardCandidate ??= winners[_random.nextInt(winners.length)];
      rewardAttribute ??= attributes[_random.nextInt(attributes.length)];
      final updated = await _squad.improveAttribute(
        _rewardCandidate!.id,
        rewardAttribute!,
      );
      // Registra o sucesso antes de atualizar a interface: novas chamadas não somam outro +1.
      rewardedAgent = updated;
      finalized = true;
      if (!_disposed) {
        members = members
            .map((hero) => hero.id == updated.id ? updated : hero)
            .toList();
        onMemberUpdated?.call(updated);
      }
    } catch (_) {
      rewardError =
          'Não foi possível salvar a recompensa. Tente novamente '
          'para concluir a missão.';
    }
    finalizing = false;
    if (!_disposed) notifyListeners();
    return finalized;
  }

  void markFeedbackShown() {
    if (_disposed || !finalized || feedbackShown) return;
    feedbackShown = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
