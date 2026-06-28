// lib/providers/customer_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class CustomerProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<CustomerModel> _customers = [];

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  List<CustomerModel> get customers => _customers;

  Future<void> load({String? query}) async {
    _setState(LoadState.loading);
    final res = await ApiService.getCustomers(query: query, page: 0, size: 100);
    _customers = ApiService.extractList(res)
        .map((e) => CustomerModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<bool> create(Map<String, dynamic> body) async {
    final res = await ApiService.createCustomer(body);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  // FIX: update() never existed, so there was no way to edit a customer
  // even though the API supports PUT /customers/{id}. Added to match the
  // same create/update/delete pattern used by every other provider.
  Future<bool> update(String id, Map<String, dynamic> body) async {
    final res = await ApiService.updateCustomer(id, body);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  Future<bool> delete(String id) async {
    final res = await ApiService.deleteCustomer(id);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}
