// lib/providers/payment_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class PaymentProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<PaymentModel> _payments = [];

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  List<PaymentModel> get payments => _payments;

  Future<void> load() async {
    _setState(LoadState.loading);
    final res = await ApiService.getPayments();
    _payments = ApiService.extractList(res)
        .map((e) => PaymentModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<bool> create(Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.createPayment(fields, image: image);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  Future<bool> update(String id, Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.updatePayment(id, fields, image: image);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  Future<bool> delete(String id) async {
    final res = await ApiService.deletePayment(id);
    if (ApiService.isSuccess(res)) { await load(); return true; }
    return false;
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}
