import 'package:flutter/foundation.dart';

import '../data/hero_database.dart';
import '../models/hero.dart';
import '../repositories/hero_repository.dart';
import '../repositories/squad_repository.dart';

class SquadProvider extends ChangeNotifier {
  final SquadRepository _squadRepository;
  final HeroRepository _heroRepository;
  List<Hero> members = [];
  Hero? dailyHero;
  bool loading = false;
  bool recruiting = false;
  bool loadingMembers = false;
  bool dismissing = false;
  String? membersError;
  String? dismissalError;
  String? error;
  bool _disposed = false;
  int _membersRevision = 0;

  SquadProvider(this._squadRepository, this._heroRepository);

  bool get alreadyRecruited =>
      dailyHero != null && members.any((hero) => hero.id == dailyHero!.id);
  bool get isFull => members.length >= SquadContract.maxMembers;
  bool get canRecruit =>
      !loading &&
      !recruiting &&
      !dismissing &&
      dailyHero != null &&
      !alreadyRecruited &&
      !isFull;

  Future<void> loadDailyContract() async {
    if (_disposed || loading || recruiting || dismissing) return;
    final revision = _membersRevision;
    loading = true;
    error = null;
    dailyHero = null;
    notifyListeners();
    try {
      final hero = await _heroRepository.getDailyHero();
      final savedMembers = await _squadRepository.getMembers();
      if (_disposed) return;
      dailyHero = hero;
      if (revision == _membersRevision) members = savedMembers;
      if (hero == null) {
        error =
            'O agente do dia não está disponível no catálogo local. '
            'Abra Agentes e sincronize o catálogo para tentar novamente.';
      }
    } catch (_) {
      if (_disposed) return;
      error = 'Não foi possível abrir o contrato diário. Tente novamente.';
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
  }

  Future<String> recruitDailyHero() async {
    final hero = dailyHero;
    if (_disposed || loading || recruiting || dismissing || hero == null) {
      return 'Aguarde o carregamento do contrato diário.';
    }
    recruiting = true;
    notifyListeners();
    String message;
    try {
      final result = await _squadRepository.recruit(hero);
      final savedMembers = await _squadRepository.getMembers();
      if (_disposed) return 'Operação concluída.';
      _membersRevision++;
      members = savedMembers;
      membersError = null;
      message = switch (result) {
        RecruitmentResult.recruited =>
          '${hero.name} foi recrutado para o Esquadrão!',
        RecruitmentResult.alreadyRecruited => 'Este agente já foi recrutado.',
        RecruitmentResult.full => 'O esquadrão atingiu o limite de 15 agentes.',
      };
    } catch (_) {
      message = 'Não foi possível concluir o recrutamento. Tente novamente.';
    }
    if (_disposed) return message;
    recruiting = false;
    notifyListeners();
    return message;
  }

  Future<void> loadMembers() async {
    if (_disposed || loadingMembers || recruiting || dismissing) return;
    final revision = _membersRevision;
    loadingMembers = true;
    membersError = null;
    notifyListeners();
    try {
      final savedMembers = await _squadRepository.getMembers();
      if (_disposed) return;
      // Uma leitura iniciada antes de uma alteração não pode desfazê-la na interface.
      if (revision == _membersRevision) members = savedMembers;
    } catch (_) {
      if (_disposed) return;
      membersError = 'Não foi possível abrir o esquadrão. Tente novamente.';
    }
    if (_disposed) return;
    loadingMembers = false;
    notifyListeners();
  }

  Future<bool> dismissMember(int heroId) async {
    if (_disposed || dismissing || recruiting || loadingMembers) return false;
    dismissing = true;
    dismissalError = null;
    notifyListeners();
    var success = false;
    try {
      await _squadRepository.dismissMember(heroId);
      if (_disposed) return false;
      _membersRevision++;
      members = members.where((hero) => hero.id != heroId).toList();
      membersError = null;
      success = true;
    } catch (_) {
      if (_disposed) return false;
      dismissalError = 'Não foi possível dispensar o agente. Tente novamente.';
    }
    if (_disposed) return false;
    dismissing = false;
    notifyListeners();
    return success;
  }

  void updateMember(Hero updated) {
    if (_disposed) return;
    _membersRevision++;
    members = members
        .map((hero) => hero.id == updated.id ? updated : hero)
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
