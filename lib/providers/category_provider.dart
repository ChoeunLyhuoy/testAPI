// lib/providers/category_provider.dart

import 'package:flutter/foundation.dart';
import 'load_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<CategoryModel> _categories = [];
  String get error => _error;
  String _error = '';

  // FIX: query was a transient parameter to load(), never stored. After a
  // search was active and the user created/updated/deleted a category,
  // create()/update()/delete() all called `await load()` with NO query —
  // silently dropping the active search/filter and showing the full list
  // instead of refreshing what the user was actually looking at. Now the
  // last-used query is remembered, and load() without an explicit argument
  // re-uses it, so a mutation refreshes the *same filtered view* the user
  // was on, not a reset to "show everything."
  String _query = '';

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  List<CategoryModel> get categories => _categories;

  Future<void> load({String? query}) async {
    if (query != null) _query = query;
    _setState(LoadState.loading);
    final res = await ApiService.getCategories(query: _query);
    _categories = ApiService.extractList(res)
        .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<bool> create(Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.createCategory(fields, image: image);
    if (ApiService.isSuccess(res)) {
      // FIX: was `await load()` — now refreshes using the remembered
      // query instead of silently clearing any active search.
      await load();
      return true;
    }
    return false;
  }

  Future<bool> update(String id, Map<String, String> fields, {dynamic image}) async {
    final res = await ApiService.updateCategory(id, fields, image: image);
    if (ApiService.isSuccess(res)) {
      await load();
      return true;
    }
    return false;
  }

  Future<bool> delete(String id) async {
    final res = await ApiService.deleteCategory(id);
    if (ApiService.isSuccess(res)) {
      await load();
      return true;
    }
    return false;
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}