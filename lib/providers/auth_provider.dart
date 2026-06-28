// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum AuthState { idle, loading, success, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.idle;
  String _errorMessage = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isLoading => _state == AuthState.loading;
  bool get isLoggedIn => ApiService.isLoggedIn;

  Future<bool> login(String email, String password) async {
    _setState(AuthState.loading);
    final res = await ApiService.login(email, password);
    if (res == null || res['error'] != null) {
      _errorMessage = res?['error'] ?? 'Connection failed';
      _setState(AuthState.error);
      return false;
    }
    if (res['status'] == 200 || res['data'] != null) {
      _setState(AuthState.success);
      return true;
    }
    _errorMessage = res['message']?.toString() ?? 'Invalid credentials';
    _setState(AuthState.error);
    return false;
  }

  void logout() {
    ApiService.logout();
    _state = AuthState.idle;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    _state = AuthState.idle;
    notifyListeners();
  }

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }
}
