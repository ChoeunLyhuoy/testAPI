// lib/providers/purchase_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class PurchaseProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<PurchaseModel> _purchases = [];

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  List<PurchaseModel> get purchases => _purchases;

  Future<void> load({String? query}) async {
    _setState(LoadState.loading);
    final res = await ApiService.getPurchases(query: query, page: 0, size: 100);
    _purchases = ApiService.extractList(res)
        .map((e) => PurchaseModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<bool> create(Map<String, dynamic> body) async {
    final res = await ApiService.createPurchase(body);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  // ADDED: GET /purchases (list) doesn't include `items` — only GET
  // /purchases/{id} (detail) does. The purchase list screen calls this the
  // first time a card is expanded, then merges the result back into
  // `_purchases` so re-expanding doesn't need to re-fetch.
  //
  // Requires the new `ApiService.getPurchase(id)` method (added below in
  // api_service.dart) — there was previously no way to hit
  // GET /api/v1/purchases/{id} at all.
  Future<PurchaseModel?> fetchDetail(String id) async {
    final res = await ApiService.getPurchase(id);
    if (!ApiService.isSuccess(res)) return null;

    final data = ApiService.extractData(res);
    if (data == null) return null;

    final detail = PurchaseModel.fromMap(data);

    final idx = _purchases.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _purchases[idx] = detail;
      notifyListeners();
    }
    return detail;
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}