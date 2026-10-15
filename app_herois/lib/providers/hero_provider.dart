import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../models/hero.dart';
import '../repositories/hero_repository.dart';

class HeroProvider extends ChangeNotifier {
  final HeroRepository _repository;
  static const pageSize = 20;
  final pagingController = PagingController<int, Hero>(firstPageKey: 0);
  bool loading = true;
  int total = 0;
  String? error;
  String message = 'Carregando catálogo…';
  bool _disposed = false;
  int _generation = 0;
  final Set<int> _pendingPages = {};
  bool _syncing = false;
  Hero? selectedHero;
  bool loadingDetails = false;
  String? detailsError;
  int _detailsRequest = 0;

  HeroProvider(this._repository) {
    pagingController.addPageRequestListener(loadPage);
  }

  Future<void> loadDetails(int id) async {
    if (_disposed) return;
    final request = ++_detailsRequest;
    selectedHero = null;
    detailsError = null;
    loadingDetails = true;
    notifyListeners();
    try {
      final hero = await _repository.getById(id);
      // Uma consulta antiga não deve substituir o personagem aberto depois.
      if (_disposed || request != _detailsRequest) return;
      selectedHero = hero;
    } catch (_) {
      if (_disposed || request != _detailsRequest) return;
      detailsError =
          'Não foi possível carregar este agente. Verifique a conexão '
          'ou sincronize o catálogo e tente novamente.';
    }
    if (_disposed || request != _detailsRequest) return;
    loadingDetails = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed || _syncing) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      total = await _repository.countCachedHeroes();
      if (_disposed) return;
      if (total == 0) {
        await synchronize();
        return;
      }
      message = 'Catálogo salvo no dispositivo. Atualize quando quiser.';
    } catch (_) {
      error = 'Não foi possível abrir o catálogo local. Tente novamente.';
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
  }

  Future<void> synchronize() async {
    if (_disposed || _syncing) return;
    _syncing = true;
    loading = true;
    error = null;
    message = 'Sincronizando o catálogo completo…';
    _generation++;
    notifyListeners();
    try {
      final count = await _repository.synchronize();
      if (_disposed) return;
      total = count;
      message = 'Catálogo atualizado e disponível offline.';
    } catch (_) {
      if (_disposed) return;
      if (total > 0) {
        message = 'Não foi possível atualizar. Exibindo o catálogo salvo.';
      } else {
        error =
            'Não foi possível acessar a API e ainda não há catálogo salvo. '
            'Verifique o servidor e a conexão USB e tente novamente.';
      }
    }
    if (_disposed) return;
    _pendingPages.clear();
    pagingController.refresh();
    loading = false;
    _syncing = false;
    notifyListeners();
  }

  Future<void> loadPage(int offset) async {
    if (_disposed || loading || _pendingPages.contains(offset)) return;
    final generation = _generation;
    _pendingPages.add(offset);
    try {
      final heroes = await _repository.getPage(limit: pageSize, offset: offset);
      if (_disposed || generation != _generation) return;
      final nextOffset = offset + heroes.length;
      if (heroes.length < pageSize || nextOffset >= total) {
        pagingController.appendLastPage(heroes);
      } else {
        pagingController.appendPage(heroes, nextOffset);
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      pagingController.error =
          'Não foi possível ler esta página. Tente novamente.';
    } finally {
      if (!_disposed && generation == _generation) {
        _pendingPages.remove(offset);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pagingController.dispose();
    super.dispose();
  }
}
