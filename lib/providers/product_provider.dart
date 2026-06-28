// lib/providers/product_provider.dart

import 'package:flutter/foundation.dart';
import 'load_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  String _error = '';
  int? _selectedCatId;
  String _query = '';
  String _sortMode = 'none'; // 'none' | 'name' | 'price'

  LoadState get state => _state;
  bool get isLoading => _state == LoadState.loading;
  String get error => _error;
  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  int? get selectedCategoryId => _selectedCatId;
  String get sortMode => _sortMode;

  void setSort(String mode) {
    _sortMode = mode;
    notifyListeners();
  }

  List<ProductModel> get filtered {
    final list = _products.where((p) {
      // FIX: _categoryNameById now does a safe String comparison
      final catMatch = _selectedCatId == null ||
          p.category == _categoryNameById(_selectedCatId);
      final qMatch = _query.isEmpty ||
          p.name.toLowerCase().contains(_query.toLowerCase()) ||
          p.options.any((o) =>
              o.productCode.toLowerCase().contains(_query.toLowerCase()));
      return catMatch && qMatch;
    }).toList();

    switch (_sortMode) {
      case 'name':
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'price':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
    }
    return list;
  }

  // FIX: CategoryModel.id is a String — compare by converting int? to string
  String? _categoryNameById(int? id) {
    if (id == null) return null;
    final idStr = id.toString();
    for (final c in _categories) {
      if (c.id == idStr) return c.name;
    }
    return null;
  }

  Future<void> loadAll() async {
    _setState(LoadState.loading);
    final results = await Future.wait([
      ApiService.getCategories(),
      ApiService.getProducts(page: 0, size: 100),
    ]);
    _categories = ApiService.extractList(results[0])
        .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _products = ApiService.extractList(results[1])
        .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  Future<void> loadProducts() async {
    _setState(LoadState.loading);
    final r = await ApiService.getProducts(
        query: _query, page: 0, categoryId: _selectedCatId, size: 100);
    _products = ApiService.extractList(r)
        .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  void setCategory(int? id) {
    _selectedCatId = id;
    loadProducts();
  }

  void setQuery(String q) {
    _query = q;
    loadProducts();
  }

  // After any mutation, do a full unfiltered reload so the new item always
  // appears regardless of active search/category filter.
  Future<void> _refresh() async {
    final all = await ApiService.getProducts(page: 0, size: 100);
    _products = ApiService.extractList(all)
        .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  // ── Product CRUD ──────────────────────────────────────────────────────────
  Future<bool> createProduct(Map<String, String> fields,
      {dynamic image}) async {
    final res = await ApiService.createProduct(fields, image: image);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  Future<bool> updateProduct(String id, Map<String, String> fields,
      {dynamic image}) async {
    final res = await ApiService.updateProduct(id, fields, image: image);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  Future<bool> deleteProduct(String id) async {
    final res = await ApiService.deleteProduct(id);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  // ── Option CRUD ───────────────────────────────────────────────────────────
  Future<bool> createOption(Map<String, String> fields,
      {dynamic image}) async {
    final res = await ApiService.createOption(fields, image: image);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  Future<bool> updateOption(String id, Map<String, String> fields,
      {dynamic image}) async {
    final res = await ApiService.updateOption(id, fields, image: image);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  Future<bool> deleteOption(String id) async {
    final res = await ApiService.deleteOption(id);
    if (ApiService.isSuccess(res)) { await _refresh(); return true; }
    return false;
  }

  void _setState(LoadState s) {
    _state = s;
    notifyListeners();
  }
}
