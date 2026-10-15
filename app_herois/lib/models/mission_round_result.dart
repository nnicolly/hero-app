import 'hero.dart';

enum CombatOutcome { victory, defeat, draw }

enum MissionOutcome { success, failure, neutral }

/// Resultado em memória; não altera o catálogo nem os membros do esquadrão.
class MissionRoundResult {
  final int round;
  final Hero agent;
  final Hero enemy;
  final String attribute;
  final int agentValue;
  final int enemyValue;
  final CombatOutcome outcome;

  const MissionRoundResult({
    required this.round,
    required this.agent,
    required this.enemy,
    required this.attribute,
    required this.agentValue,
    required this.enemyValue,
    required this.outcome,
  });

  String get label => switch (outcome) {
    CombatOutcome.victory => 'Vitória',
    CombatOutcome.defeat => 'Derrota',
    CombatOutcome.draw => 'Empate',
  };
}
