// lib/providers/supplier_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class SupplierProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<SupplierModel> _suppliers = [];

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  List<SupplierModel> get suppliers => _suppliers;

  Future<void> load({String? query}) async {
    _setState(LoadState.loading);
    final res = await ApiService.getSuppliers(query: query);
    _suppliers = ApiService.extractList(res)
        .map((e) => SupplierModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<bool> create(Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.createSupplier(fields, image: image);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  Future<bool> update(String id, Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.updateSupplier(id, fields, image: image);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  Future<bool> delete(String id) async {
    final res = await ApiService.deleteSupplier(id);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}
