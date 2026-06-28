// lib/providers/promotion_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class PromotionProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<PromotionModel> _promotions = [];
  String _error = '';

  LoadState            get state      => _state;
  bool                 get isLoading  => _state == LoadState.loading;
  String               get error      => _error;
  List<PromotionModel> get promotions => _promotions;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load({String? query}) async {
    _setState(LoadState.loading);
    final res  = await ApiService.getPromotions(query: query, size: 100);
    final list = ApiService.extractList(res);
    _promotions = list
        .map((e) => PromotionModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<bool> create(Map<String, dynamic> body) async {
    final res = await ApiService.createPromotion(body);
    if (!ApiService.isSuccess(res)) return false;
    await load();
    return true;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<bool> update(String id, Map<String, dynamic> body) async {
    final res = await ApiService.updatePromotion(id, body);
    if (!ApiService.isSuccess(res)) return false;
    await load();
    return true;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<bool> delete(String id) async {
    final res = await ApiService.deletePromotion(id);
    if (!ApiService.isSuccess(res)) return false;
    _promotions.removeWhere((p) => p.id == id);
    notifyListeners();
    return true;
  }

  // ── Add Products to Promotion ─────────────────────────────────────────────

  /// Calls POST /promotions/{id}/products with [{productCode, quantity}]
  Future<bool> addProducts(
    String promotionId,
    List<Map<String, dynamic>> products,
  ) async {
    final res = await ApiService.addProductsToPromotion(promotionId, products);
    if (!ApiService.isSuccess(res)) return false;
    await load();
    return true;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _setState(LoadState s) {
    _state = s;
    notifyListeners();
  }
}
