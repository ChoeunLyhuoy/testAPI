// lib/providers/dashboard_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class DashboardProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  DashboardModel _data = DashboardModel.empty();

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  DashboardModel get data => _data;

  Future<void> load() async {
    _setState(LoadState.loading);
    final res = await ApiService.getDashboard();
    final map = ApiService.extractData(res);
    _data = map != null ? DashboardModel.fromMap(map) : DashboardModel.empty();
    _setState(LoadState.success);
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}
